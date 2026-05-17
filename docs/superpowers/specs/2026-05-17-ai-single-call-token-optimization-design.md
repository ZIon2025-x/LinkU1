# AI 单次消耗根因优化 Spec

**状态**：设计完成，待实施

**日期**：2026-05-17

**作者**：Claude + Ryan（brainstorm 协作）

**关联**：解除阻塞 `2026-05-17-ai-task-draft-onboarding-design.md`

---

## 1. 背景与痛点

### 1.1 现状
- 配置（`backend/app/config.py:361-368`）：
  - `AI_DAILY_TOKEN_BUDGET = 50000`（每用户每天 50K tokens）
  - `AI_DAILY_REQUEST_LIMIT = 100`
  - `AI_RATE_LIMIT_RPM = 10`

### 1.2 用户痛点
用户反馈：**普通 AI chat 几次（3-5 次）就用完 50K daily budget**，被提示"今日 AI 使用额度已用完"。

按估算单次 chat 应该 2-5K tokens，几次用完意味着实际单次消耗 **10K-16K tokens**，远高于预期。

### 1.3 为什么不直接加大 budget
单次消耗 10K-16K 是结构性问题。简单把 budget 50K → 100K 只是把"3 次卡"变成"6 次卡"，治标。且 AI 任务起草 spec（已 brainstorm 完成，commit `8703438ae`）的单次消耗比普通 chat 更重（注入模板 few-shot + 多轮 tool 调用），如果根因不修，上线后用户体验更差。

### 1.4 根因诊断（按严重程度排）

| # | 根因 | 位置 | 影响 |
|---|------|------|------|
| **1** | 🔴 Cached input tokens 被算进 daily budget | `ai_agent.py:1342` | cache 命中 80% 仍按 100% 扣 budget |
| **2** | 🔴 Anthropic 路径没启 prompt caching | `ai_llm_client.py:78-91` (AnthropicProvider.chat) | Claude Sonnet 4.5 全价 input |
| **3** | 🟡 history 20 轮无压缩每次全量重发 | `ai_agent.py:1622-1663` (`_load_history`) | 长会话 input 线性膨胀 |
| 4 | tools schema 即使按 intent 筛了还几千 tokens | `ai_tool_registry.get_tools_for_intent` | 中等影响 |
| 5 | tool 循环每轮重算累积 input | `ai_agent.py:1272-1342` | 影响小 |

**本 spec 范围**：根因 1+2+3。根因 4+5 留作未来优化点。

---

## 2. 范围

### 2.1 MVP 内
1. 改 budget 记账，cached tokens 不计入
2. 启用 Anthropic prompt caching（system + tools 都缓存）
3. History compaction 分三层

### 2.2 MVP 外
- 不改 GLM 路径的 `extra_body` / OpenAI compatible provider 任何逻辑
- 不重做 budget 数字（50K 保持，看效果再说）
- 不加 admin metric 面板（用 log 看就够）
- 不优化根因 4（tools 进一步剪裁）和 5（tool_result 回灌压缩）
- 不改 `AIMessage` 表 schema

---

## 3. 架构总览

```
┌──────────────────────────────────────────────────────────────┐
│ 改动 1: Budget 记账修正 (核心 1 行)                            │
│   ai_agent.py:1342                                            │
│   effective = input_tokens - cached_input_tokens              │
│   ctx.total_input_tokens += effective                         │
│   ctx.total_raw_input_tokens += input_tokens   (新增,日志用)  │
│   ctx.total_cached_input_tokens += cached_input_tokens (新增) │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ 改动 2: Anthropic Prompt Cache 启用                            │
│   ai_llm_client.py AnthropicProvider.chat / chat_stream        │
│   - system 改为 list[{type:text, text, cache_control:eph.}]    │
│   - tools 末尾一项加 cache_control:ephemeral                   │
│   - 异常自动回退到 raw str + 重试一次                          │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ 改动 3: History Compaction (分层)                              │
│   ai_agent.py 新 _load_history_compacted (替换 _load_history)  │
│   - Layer A (最近 4 轮):  原样保留                              │
│   - Layer B (5-12 轮):    tool_result 替换占位符                │
│   - Layer C (13-20 轮):   GLM 摘要为 1-2 句, Redis 24h 缓存    │
│   - 摘要失败 → 直接丢 Layer C                                  │
│   - Layer C ack 文案: "I've reviewed the earlier conversation."│
└──────────────────────────────────────────────────────────────┘
```

### 互不依赖原则

| 改动 | 风险 | Feature Flag |
|------|------|--------------|
| 1. Budget 记账 | 极低 | 无（直接生效） |
| 2. Anthropic cache | 中 | `AI_ANTHROPIC_CACHE_ENABLED`，默认 **true** |
| 3. History 压缩 | 中 | `AI_HISTORY_COMPACTION_ENABLED`，默认 **false**（保守） |

三个改动互不依赖，可分别灰度。

---

## 4. 改动 1：Budget 记账修正

### 4.1 代码
**位置**：`backend/app/services/ai_agent.py:1342`

```python
# Before
ctx.total_input_tokens += response.usage.input_tokens

# After
effective_input = max(0, response.usage.input_tokens - response.usage.cached_input_tokens)
ctx.total_input_tokens += effective_input
ctx.total_raw_input_tokens += response.usage.input_tokens
ctx.total_cached_input_tokens += response.usage.cached_input_tokens
```

### 4.2 PipelineContext 字段新增
`_PipelineContext` 类（约 `ai_agent.py:1044-1070`）新增：
- `total_raw_input_tokens: int = 0`
- `total_cached_input_tokens: int = 0`

### 4.3 防御性下限
`max(0, ...)` 保证 provider 上报 cached > input 时不会负溢出。

### 4.4 AIMessage 表
`save_assistant_message` 仍保存 raw `input_tokens`（用于历史对账 / trace），不改 schema。

---

## 5. 改动 2：Anthropic Prompt Cache 启用

### 5.1 代码
**位置**：`backend/app/services/ai_llm_client.py` `AnthropicProvider.chat` / `chat_stream`

```python
async def chat(self, model, messages, system, tools, max_tokens):
    cache_enabled = Config.AI_ANTHROPIC_CACHE_ENABLED
    
    kwargs: dict[str, Any] = {
        "model": model,
        "max_tokens": max_tokens,
        "messages": messages,
    }
    
    if cache_enabled and system:
        kwargs["system"] = [{
            "type": "text", "text": system,
            "cache_control": {"type": "ephemeral"},
        }]
    elif system:
        kwargs["system"] = system  # 老 raw str
    
    if cache_enabled and tools:
        # 复制末尾 tool 加 cache_control
        tools_marked = tools[:-1] + [{**tools[-1], "cache_control": {"type": "ephemeral"}}]
        kwargs["tools"] = tools_marked
    elif tools:
        kwargs["tools"] = tools
    
    try:
        resp = await self._client.messages.create(**kwargs)
    except anthropic.BadRequestError as e:
        if cache_enabled and "cache_control" in str(e):
            logger.warning("Anthropic cache_control rejected, falling back: %r", e)
            # 回退到 raw 调用
            kwargs["system"] = system
            kwargs["tools"] = tools
            resp = await self._client.messages.create(**kwargs)
        else:
            raise
    
    # ...rest unchanged
```

`chat_stream` 同款改造。

### 5.2 配置
`backend/app/config.py` 新增：
```python
AI_ANTHROPIC_CACHE_ENABLED = os.getenv("AI_ANTHROPIC_CACHE_ENABLED", "true").lower() == "true"
```

### 5.3 Cache breakpoint 预算
Anthropic 上限 4 个：
- System: 1 个
- Tools: 1 个
- 余 2 个：暂留给未来扩展（messages 内 cache，如长 system 段分块）

### 5.4 GLM 路径不动
`OpenAICompatibleProvider` 完全不动。GLM 隐式自动 cache。

---

## 6. 改动 3：History Compaction

### 6.1 代码

**位置**：`backend/app/services/ai_agent.py` 新增 `_load_history_compacted`（保留原 `_load_history` 作为 disabled flag 路径）

```python
async def _load_history_compacted(db, conversation_id):
    """分层压缩 history.
    - Layer A (最近 4 轮 = 8 条 message): 原样
    - Layer B (5-12 轮): tool_result 替换占位符
    - Layer C (13-20 轮): LLM 摘要 + 缓存
    """
    max_turns = Config.AI_MAX_HISTORY_TURNS  # 20
    rows = await _fetch_history_rows(db, conversation_id, max_turns * 2)
    total = len(rows)
    
    # 短会话(≤ 4 轮): 完全跳过 compaction
    if total <= 8:
        return _build_raw_messages(rows)
    
    layer_a = rows[max(0, total - 8):]
    layer_b = rows[max(0, total - 24):max(0, total - 8)]
    layer_c = rows[:max(0, total - 24)]
    
    messages = []
    
    # Layer C: 摘要(失败→直接丢)
    if layer_c:
        summary = await _summarize_history_cached(layer_c, conversation_id)
        if summary:
            messages.append({
                "role": "user",
                "content": f"[Earlier conversation summary]: {summary}",
            })
            messages.append({
                "role": "assistant",
                "content": "I've reviewed the earlier conversation.",
            })
    
    # Layer B: tool_result 占位符化
    for msg in layer_b:
        if msg.role == "assistant" and msg.tool_calls:
            # tool_use 块保留(让 AI 知道之前调过什么 tool)
            content_blocks = []
            if msg.content:
                content_blocks.append({"type": "text", "text": msg.content})
            try:
                tool_calls = json.loads(msg.tool_calls)
                for tc in tool_calls:
                    content_blocks.append({
                        "type": "tool_use", "id": tc["id"],
                        "name": tc["name"], "input": tc["input"],
                    })
            except (json.JSONDecodeError, KeyError):
                pass
            messages.append({"role": "assistant", "content": content_blocks})
            
            if msg.tool_results:
                try:
                    tool_results = json.loads(msg.tool_results)
                    result_blocks = [{
                        "type": "tool_result", "tool_use_id": tr["tool_use_id"],
                        "content": f"[Tool returned data, omitted]",
                    } for tr in tool_results]
                    messages.append({"role": "user", "content": result_blocks})
                except (json.JSONDecodeError, KeyError):
                    pass
        else:
            messages.append({"role": msg.role, "content": msg.content})
    
    # Layer A: 原样(沿用现有完整逻辑)
    messages.extend(_build_raw_messages(layer_a))
    
    return messages


async def _summarize_history_cached(rows, conversation_id):
    """生成 Layer C 摘要,带 Redis 缓存."""
    # 缓存 key = conversation_id + hash(参与摘要的 message ids)
    msg_ids = ",".join(str(m.id) for m in rows)
    key_hash = hashlib.md5(msg_ids.encode()).hexdigest()[:16]
    cache_key = f"ai:hist_sum:{conversation_id}:{key_hash}"
    
    r = _get_redis()
    if r:
        try:
            cached = r.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass
    
    # 拼摘要 prompt
    rows_text = "\n".join(f"{m.role}: {m.content[:300]}" for m in rows if m.content)
    summary_prompt = (
        "Summarize the following conversation in 1-2 sentences. "
        "Preserve: user's key intent, unfinished requests, important context entities (names, IDs, dates).\n\n"
        f"{rows_text}"
    )
    
    try:
        llm = get_llm_client()
        resp = await llm.chat(
            messages=[{"role": "user", "content": summary_prompt}],
            system=(
                "You are a conversation summarizer. Be concise and information-dense. "
                "Respond in the same language as the conversation."
            ),
            tools=None,
            model_tier="small",
            max_tokens=200,
        )
        summary = "".join(
            b.text for b in resp.content
            if getattr(b, "type", None) == "text"
        ).strip()
        
        if not summary:
            return None  # 空摘要视为失败
        
        if r:
            try:
                r.setex(cache_key, 86400, summary)
            except Exception:
                pass
        return summary
    except Exception as e:
        logger.warning("History summary failed for conv %s: %r", conversation_id, e)
        return None
```

### 6.2 调用方切换

`ai_agent.py:1240` 改：
```python
if Config.AI_HISTORY_COMPACTION_ENABLED:
    history = await _load_history_compacted(ctx.db, ctx.conversation_id)
else:
    history = await _load_history(ctx.db, ctx.conversation_id)
```

### 6.3 配置
`backend/app/config.py` 新增：
```python
AI_HISTORY_COMPACTION_ENABLED = os.getenv("AI_HISTORY_COMPACTION_ENABLED", "false").lower() == "true"
```

### 6.4 失败 fallback
GLM 摘要调用失败 / 超时 / 返回空 → 返回 `None` → 调用方跳过 Layer C 拼接（**直接丢掉最老 8 轮**），Layer A + B 正常工作。

### 6.5 节省估算

| 层 | 原大小（粗估） | 压缩后 | 省 |
|----|--------------|--------|------|
| Layer C (8 轮 ~5K tokens) | 5000 | ~200 | 95% |
| Layer B (8 轮 ~5K tokens) | 5000 | ~1500 | 70% |
| Layer A (4 轮 ~2.5K tokens) | 2500 | 2500 | 0% |
| **20 轮合计** | **12500** | **~4200** | **~66%** |

---

## 7. 错误处理 / 兼容性

| 场景 | 处理 |
|------|------|
| cached_input_tokens=0 (GLM 未命中/Anthropic 未开 cache) | effective = input - 0 = input,等于现状 |
| cached > input (provider 上报异常) | `max(0, ...)` 保护 |
| Anthropic API 报 cache_control 字段错误 | try/except → 回退 raw 重试一次 → 日志告警 |
| GLM 路径 | 完全不动 |
| GLM 摘要超时/失败 | 跳过 Layer C,直接丢老消息,日志 warning |
| 摘要返回空字符串 | 视为失败,走 fallback |
| Redis 不可用 | 摘要走内存缓存(同 `_StateBackend` 模式) |
| 短会话 (≤ 4 轮) | 跳过 compaction,完全等于现状 |
| AIMessage 表 schema | 不动,input_tokens 保存 raw 值 |

### 兼容性
- Budget 修正瞬间生效。用户即将用满的当前 day 不会"突然多出额度",因为 budget 按天滚动
- 现有 `AI cache hit: ...` 日志保留并扩展(加 effective 字段)

---

## 8. 灰度策略

| 改动 | env flag | 默认 | 灰度方式 |
|------|---------|------|---------|
| 1. Budget 记账 | 无 | 直接生效 | linktest 跑一天观察 cache 命中率 + budget 累计速率 → push prod |
| 2. Anthropic cache | `AI_ANTHROPIC_CACHE_ENABLED` | **true** | linktest 验证 cache hit 日志在 Claude 路径出现 → prod 默认 true,紧急回滚改 false |
| 3. History compaction | `AI_HISTORY_COMPACTION_ENABLED` | **false** | linktest `=true` 跑 3-5 天,人工 review 5-10 个真实长会话摘要质量 → prod 改 true |

### 监控点（部署后看）

1. `AI cache hit: cached=X / input=Y` 日志在 Claude 路径出现（改动 2 生效信号）
2. `_state.record_usage` 累计减少（改动 1+2 联合）
3. `_summarize_history_cached` 调用频率 / 失败率（改动 3 健康度）
4. **用户被 daily budget 拒次数下降**（最终业务指标）

---

## 9. 测试策略

### 9.1 后端单测

| 测试 | 内容 |
|------|------|
| `test_budget_cached_token_excluded` | mock LLMResponse 含 cached=300, input=1000 → record_usage 收到 700+output |
| `test_budget_cached_overflow_safe` | cached=2000, input=1000 → effective ≥ 0 |
| `test_anthropic_provider_system_cache_block` | mock anthropic → assert kwargs["system"] 是 list[{cache_control,...}] |
| `test_anthropic_provider_tools_cache_marker` | tools list 最后一项含 cache_control |
| `test_anthropic_provider_cache_fallback_on_error` | mock 第一次 raise BadRequestError 含 'cache_control' → 自动回退 str + 重试成功 |
| `test_anthropic_provider_glm_path_unchanged` | OpenAICompatibleProvider.chat 完全等于现状 |
| `test_load_history_compacted_short_session` | 3 轮 → 跳过 compaction,等于原 `_load_history` |
| `test_load_history_compacted_layer_b` | 12 轮 → Layer A 保留最近 4,Layer B 替换 tool_result |
| `test_load_history_compacted_layer_c_summary` | 20 轮 → mock 摘要 → 输出含 `[Earlier conversation summary]: ...` + ack |
| `test_summary_cache_hit` | 同 conv + 同 message ids → 第二次不打 GLM |
| `test_summary_failure_drops_layer_c` | GLM 摘要 raise → Layer C 完全丢,Layer A+B 正常 |
| `test_summary_empty_string_treated_as_failure` | 摘要返回 "" → fallback |
| `test_feature_flag_compaction_disabled` | flag=false → 走原 _load_history 完全不变 |

### 9.2 集成测试

| 测试 | 内容 |
|------|------|
| `test_full_agent_with_cache_enabled` | mock Anthropic 含 cache_read → 跑完整 agent → budget 只计 effective |
| `test_full_agent_long_conversation` | 20 轮 AIMessage fixture → 跑 agent → input token 显著低于不开 compaction |

### 9.3 Linktest 灰度（手动）

1. 部署 → 看 `AI cache hit` 日志在 Claude 路径出现
2. 跑长会话(20+ 轮),log 中看摘要内容质量
3. 不同 conversation 累计 daily token,看速度
4. 临时写错 GLM key 触发摘要失败 → fallback 生效

### 9.4 不做
- E2E（无框架）
- 性能 benchmark（cache hit 更快；摘要 < 1s）
- 负载测试

---

## 10. 分阶段上线

1. **Phase 1**：改动 1（budget 记账）+ ctx 字段 + 单测 → linktest → prod
2. **Phase 2**：改动 2（Anthropic cache）+ flag + 单测 → linktest 验证 cache 日志 → prod 默认 true
3. **Phase 3**：改动 3（history compaction）+ flag + 单测 → linktest flag=true 跑 3-5 天 + 人工 review → prod 改 true
4. **Phase 4**（解除阻塞）：判断是否需要附录 quota 调整；如不需要，回到 AI 任务起草 spec 开始实施

每个 phase 是独立 PR，可分批合入。

---

## 11. 风险与未决问题

- **Anthropic cache TTL**: ephemeral 是 5 分钟 sliding window。如果用户 chat 间隔 > 5 分钟,cache 会过期重新写入。可接受,因为下一次会话之初付一次"cache write 成本"(1.25x input price),但后续命中省 90%
- **摘要质量未知**: 第一次实施时必须人工 review 5-10 个真实长会话摘要,避免摘要丢失关键上下文导致 AI 回答跑题
- **GLM cache 行为**: 文档说"自动隐式 cache",但 cached_tokens 是否在 usage 里真实上报需要在 linktest 验证(`OpenAICompatibleProvider:337-345` 已读 `prompt_tokens_details.cached_tokens`,若 GLM 不上报这字段就为 0,改动 1 在 GLM 路径就退化为现状)
- **`_PipelineContext` 加 2 个字段**: 不破坏向后兼容,但 ctx 序列化(如有)需要确认
- **摘要的多语言**: 当前摘要 prompt 是英文,但用户对话可能是中文。GLM 处理中→英摘要可能丢细节。需在 prompt 中加 "respond in the same language as the conversation"
