# AI Agent 模块文档

## 概述

Link2Ur 平台 AI 客服助手 — 用户通过自然语言查询任务、了解平台功能。Phase 1 为只读 MVP，零写操作风险。

## 架构

```
用户消息
  │
  ▼
┌─────────────────────────────────┐
│ 1. 路由层 (ai_agent_routes.py)  │  认证 → 限流(RPM) → 每日预算检查
└──────────────┬──────────────────┘
               ▼
┌─────────────────────────────────┐
│ 2. 意图分类 (本地，零 token)      │  正则离题检测 → FAQ关键词 → 平台关键词
└──────────────┬──────────────────┘
               │
    ┌──────────┼──────────┬──────────────┐
    ▼          ▼          ▼              ▼
  离题        FAQ      任务/资料       未知
  拒绝     本地回答    Haiku+工具    Haiku判断
 (0 tok)   (0 tok)    (低消耗)     → 可能升级 Sonnet
```

## 环境变量

### 必须配置

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic API 密钥（默认 provider 的 key） |

### 模型配置（小模型）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `AI_MODEL_SMALL` | `claude-haiku-4-5-20251001` | 小模型名称 |
| `AI_MODEL_SMALL_PROVIDER` | `anthropic` | `anthropic` 或 `openai_compatible` |
| `AI_MODEL_SMALL_API_KEY` | 空（复用 `ANTHROPIC_API_KEY`） | 小模型独立 API Key |
| `AI_MODEL_SMALL_BASE_URL` | 空 | OpenAI 兼容 API 的 Base URL |

### 模型配置（大模型）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `AI_MODEL_LARGE` | `claude-sonnet-4-5-20250929` | 大模型名称 |
| `AI_MODEL_LARGE_PROVIDER` | `anthropic` | `anthropic` 或 `openai_compatible` |
| `AI_MODEL_LARGE_API_KEY` | 空（复用 `ANTHROPIC_API_KEY`） | 大模型独立 API Key |
| `AI_MODEL_LARGE_BASE_URL` | 空 | OpenAI 兼容 API 的 Base URL |

### 限制与预算

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `AI_MAX_OUTPUT_TOKENS` | `1024` | 单次回复 token 上限 |
| `AI_MAX_HISTORY_TURNS` | `10` | 对话历史保留轮数 |
| `AI_RATE_LIMIT_RPM` | `10` | 每用户每分钟请求数 |
| `AI_DAILY_REQUEST_LIMIT` | `100` | 每用户每天请求数 |
| `AI_DAILY_TOKEN_BUDGET` | `50000` | 每用户每天 token 上限 |
| `AI_FAQ_CACHE_TTL` | `3600` | FAQ 缓存秒数 |

## 换模型示例

### 小模型换成智谱 GLM-4-Flash

```env
AI_MODEL_SMALL_PROVIDER=openai_compatible
AI_MODEL_SMALL_API_KEY=your-zhipu-api-key
AI_MODEL_SMALL_BASE_URL=https://open.bigmodel.cn/api/paas/v4
AI_MODEL_SMALL=glm-4-flash
```

### 小模型换成 DeepSeek

```env
AI_MODEL_SMALL_PROVIDER=openai_compatible
AI_MODEL_SMALL_API_KEY=your-deepseek-key
AI_MODEL_SMALL_BASE_URL=https://api.deepseek.com/v1
AI_MODEL_SMALL=deepseek-chat
```

### 大模型换成 GPT-4o

```env
AI_MODEL_LARGE_PROVIDER=openai_compatible
AI_MODEL_LARGE_API_KEY=sk-xxx
AI_MODEL_LARGE_BASE_URL=https://api.openai.com/v1
AI_MODEL_LARGE=gpt-4o
```

### 全部用 Anthropic（默认）

```env
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
# 其他保持默认即可
```

## 成本控制策略

### 1. 三层拦截（大部分请求零 LLM 消耗）

| 层级 | 触发条件 | LLM 消耗 | 示例 |
|------|---------|---------|------|
| 离题拒绝 | 正则匹配离题模式 | **0** | "写首诗"、"天气怎样"、"帮我编程" |
| FAQ 本地回答 | 关键词命中 FAQ | **0** | "怎么发布任务"、"费用多少" |
| FAQ 缓存 | 相同问题重复问 | **0** | 同上，命中缓存 |
| 小模型调用 | 任务/资料查询 | 低 | "我的任务状态"、"搜索翻译任务" |
| 大模型调用 | 多工具复杂推理 | 高 | 极少（自动升级） |

### 2. 回复长度控制

- `AI_MAX_OUTPUT_TOKENS=1024`（硬限制）
- System prompt 指令："每次回复控制在 3-5 句话以内"

### 3. 历史裁剪

- 只保留最近 10 轮对话（`AI_MAX_HISTORY_TURNS=10`）
- 超出的历史不加载，节省 input token

### 4. 每日预算

- 每用户每天 100 次请求 + 50000 token
- 超出后返回友好提示，不调用 LLM

### 5. 模型路由

- 默认用 Haiku（$0.80/MTok input）
- 只有第一轮触发 ≥2 个工具调用时才升级 Sonnet（$3/MTok input）
- 实际大部分请求不需要工具调用，直接 Haiku 处理

## 文件清单

### 后端文件

| 文件 | 职责 |
|------|------|
| `app/config.py` | AI 环境变量配置（14 个变量） |
| `app/models.py` | `AIConversation` + `AIMessage` 数据库表 |
| `app/services/ai_llm_client.py` | LLM 多 provider 客户端（Anthropic + OpenAI 兼容） |
| `app/services/ai_tools.py` | 5 个只读工具定义（JSON Schema） |
| `app/services/ai_tool_executor.py` | 工具安全执行器 + FAQ 数据 |
| `app/services/ai_agent.py` | Agent 调度器（意图分类 + 工具循环 + 预算控制） |
| `app/ai_agent_routes.py` | 5 个 API 端点（SSE 流式） |
| `app/ai_schemas.py` | Pydantic 请求/响应模型 |

### Flutter 文件

| 文件 | 职责 |
|------|------|
| `lib/data/models/ai_chat.dart` | 数据模型 |
| `lib/data/services/ai_chat_service.dart` | SSE 客户端 |
| `lib/features/ai_chat/bloc/ai_chat_bloc.dart` | BLoC 状态管理 |
| `lib/features/ai_chat/views/ai_chat_view.dart` | 聊天页面 |
| `lib/features/ai_chat/views/ai_chat_list_view.dart` | 对话列表页 |
| `lib/features/ai_chat/widgets/ai_message_bubble.dart` | 消息气泡 |
| `lib/features/ai_chat/widgets/tool_call_card.dart` | 工具调用指示器 |

### 修改的文件

| 文件 | 改动 |
|------|------|
| `backend/requirements.txt` | +anthropic, +sse-starlette, +tiktoken |
| `backend/app/main.py` | 注册 AI agent 路由 |
| `link2ur/lib/data/services/api_service.dart` | 暴露 `dio` getter |
| `link2ur/lib/core/constants/api_endpoints.dart` | +3 AI 端点 |
| `link2ur/lib/core/router/app_router.dart` | +3 AI 路由 |
| `link2ur/lib/app.dart` | 注册 AIChatService |
| `link2ur/lib/features/message/views/message_view.dart` | 消息 Tab 添加 AI 入口 |

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/ai/conversations` | 创建新对话 |
| GET | `/api/ai/conversations` | 对话列表 |
| GET | `/api/ai/conversations/{id}` | 对话详情（含消息历史） |
| POST | `/api/ai/conversations/{id}/messages` | 发送消息（SSE 流式响应） |
| DELETE | `/api/ai/conversations/{id}` | 归档对话 |

### SSE 事件格式

```
event: token
data: {"content": "你好，你的任务状态如下："}

event: tool_call
data: {"tool": "query_my_tasks", "input": {"status": "all"}}

event: tool_result
data: {"tool": "query_my_tasks", "result": {"tasks": [...], "total": 3}}

event: done
data: {"input_tokens": 200, "output_tokens": 150}
```

## 部署步骤

1. 在 Railway 设置环境变量 `ANTHROPIC_API_KEY`
2. 部署后端 — 启动时 `Base.metadata.create_all(checkfirst=True)` 会自动创建 `ai_conversations` 和 `ai_messages` 表（无需手动迁移）
3. Flutter 端无需额外配置，重新构建即可

## Phase 2+ 规划

### Phase 2 — 写操作 + 确认流程
- 新增工具：创建任务、接单、修改资料
- 所有写操作返回 `requires_confirmation: true`
- 前端显示确认卡片，用户点击确认后才执行
- 新增 `confirm_action` 端点

### Phase 3 — RAG 知识库
- pgvector 向量数据库（复用 PostgreSQL）
- 平台文档/帮助中心内容嵌入
- 用户问题 → 语义搜索 → 注入上下文 → LLM 回答
- 替代当前的静态 FAQ 字典

### Phase 4 — 智能推荐
- 任务匹配推荐（根据用户技能/历史）
- 任务拆解/合并建议
- 价格建议（基于历史数据）

### Phase 5 — 自动化工作流
- AI 执行员：定时检查任务状态、自动提醒
- 多步骤工作流（发布→匹配→通知）
- Webhook 触发的 AI 动作

## 当前限制

1. **FAQ 数据静态** — 写在代码里，需要改代码才能更新
2. **预算追踪基于内存** — 重启后重置，生产环境应迁移到 Redis
3. **意图分类基于关键词** — 可能误判，复杂场景需要 LLM 辅助
4. **无对话摘要** — 超出历史轮数的内容直接丢弃，不做摘要压缩
5. **工具调用最多 3 轮** — 超过则截断
6. **无 streaming** — 当前用非流式调用 + 逐块推送模拟，大模型响应慢时用户需等待较久
