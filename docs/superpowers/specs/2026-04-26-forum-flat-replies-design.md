# 论坛回复扁平化（删除 3 层嵌套限制）设计

**日期**: 2026-04-26
**作者**: Claude + Ryan
**状态**: Design — 待 user review
**关联工作**: `docs/superpowers/specs/2026-04-26-forum-routes-split-design.md`（forum_routes.py 拆分；本设计在拆分**之前**或**之后**实施都可，建议拆分先行——见 §9）

---

## 1. 背景与动机

线上日志反复出现：

```
HTTP异常: 403 - 详情: 回复层级最多三层
POST /api/forum/posts/99/replies -> 403
```

后端 `forum_replies` 表有 DB 级 CheckConstraint `reply_level BETWEEN 1 AND 3`（`models.py:2572`）+ 应用层校验（`forum_routes.py:4896`）。当用户尝试回复一个 `reply_level=3` 的回复时返回 403。

调查发现两个客户端的 UI 形态**与后端约束不一致**：

| 客户端 | 现状 | 与后端约束的关系 |
|---|---|---|
| Flutter（`forum_post_detail_view.dart`，1752 行） | 所有回复**完全平铺**渲染（`SliverList.separated` 单层 list，统一 42px 缩进），通过 `parentReplyId` 从同列表查 parent 渲染"@xxx" | 后端的层级限制对 Flutter UI 没有任何视觉意义 |
| Web（`ForumPostDetail.tsx`，1501 行） | 递归 `renderReply(level+1)` 真树形渲染，按 level 缩进 | 后端约束"挡住" L4，但 UI 自身的视觉嵌套也已经在 L3 难以阅读 |

iOS 原生已退役（见 CLAUDE.md），不参与决策。

**结论**：后端的 3 层硬约束是 Flutter UI 设计的一个意外副作用，Web 一端的真树形 UI 也未必是产品想要的方向。直接对齐到 Flutter 既有的扁平形态是最低风险的解。

## 2. 目标 / 非目标

### 目标

1. 删除回复层级硬约束，用户可以回复任何回复（包括"回复别人的回复的回复"）
2. 后端、Flutter、Web 三层达成一致的扁平回复模型 + "@xxx" 引用语义
3. Web 增加 "@xxx" 可点击跳转 + 短暂高亮（与 Flutter 体验对齐；Flutter 也补做这个交互——目前没做）
4. 改动量最小：只删不加，不引入新数据库列、不引入新 API 端点

### 非目标

- **不**实现小红书式 bucket 聚簇 UI（"L1 + 平铺 sub-thread + 查看全部 N 条"）。该方向更优但成本 700-1100 行 + 2-4 天集中开发，已与用户确认采用更轻量的扁平化方案；如未来论坛单帖 P95 回复数超过 50，再升级到 bucket 模型
- **不**引入 `thread_root_id` 字段或重新定义 `parent_reply_id` 语义。`parent_reply_id` 在新世界里就继续是"我在 @ 谁"的 FK，与"我的对话上下文是哪条 L1"不再绑定（也没有 L1 这个概念了）
- **不**改通知逻辑——继续通知"帖子作者 + parent_reply 作者（即 @-target）"
- **不**触碰 admin 后台的回复审核视图（admin 看的是平铺审核流，无嵌套渲染）

## 3. 设计概览

### 3.1 数据模型

`forum_replies` 表保留所有现有字段，但有两处删除：

| 字段 / 约束 | 处理 |
|---|---|
| `reply_level Integer` | **删除** |
| `CheckConstraint("reply_level BETWEEN 1 AND 3")` | **删除** |
| `parent_reply_id`（FK 自引用，CASCADE） | **保留**，语义不变（"我在 @ 谁"） |
| `parent_reply` relationship | **保留** |
| 其他字段 | **保留** |

`parent_reply_id` 的 `ON DELETE CASCADE` 不修改。原因：
- 99% 的删除走软删（`is_deleted=true`），FK 不触发
- 硬删只发生在 admin 后台或 cleanup task；硬删一条回复时连带删掉所有 @ 它的回复在扁平模型下行为可能略反直觉，但保留现状避免一次额外的 FK 改写
- 如果未来发现这个行为困扰用户（"我 @ 了 X，X 删了号，我的内容也被删了"），再单独发一个 migration 改成 `SET NULL`

### 3.2 回复创建逻辑

`forum_routes.py` 现有 `POST /api/forum/posts/{post_id}/replies` 端点（line 4855-5030）的简化：

```python
# 删除以下整段（原 4877-4903）：
reply_level = 1
if reply.parent_reply_id:
    parent_result = ...
    parent_reply = ...
    if parent_reply.reply_level >= 3:
        raise HTTPException(403, "回复层级最多三层", ...REPLY_LEVEL_LIMIT)
    reply_level = parent_reply.reply_level + 1

# 替换为以下（保留 parent 存在性 + 同帖校验）：
if reply.parent_reply_id:
    parent_result = await db.execute(
        select(models.ForumReply).where(models.ForumReply.id == reply.parent_reply_id)
    )
    parent_reply = parent_result.scalar_one_or_none()
    if not parent_reply:
        raise HTTPException(404, "父回复不存在")
    if parent_reply.post_id != post_id:
        raise HTTPException(400, "父回复不属于该帖子")
```

`db_reply` 创建时不再传 `reply_level`。

### 3.3 API 响应

`schemas.py:3987` 的 `ForumReplyOut` 改动：

```python
class ForumReplyOut(BaseModel):
    id: int
    content: str
    author: UserInfo
    parent_reply_id: Optional[int] = None
    parent_reply_author: Optional[UserInfo] = None  # 保留：前端"@xxx"渲染依据
    # reply_level: int                              ← 删除
    like_count: int
    is_liked: Optional[bool] = False
    created_at: datetime.datetime
    updated_at: datetime.datetime
    # replies: List["ForumReplyOut"] = []           ← 删除（嵌套字段不再有意义）
```

`ForumReplyListResponse` 不变（外层平铺已经是这个形态）。

### 3.4 回复列表排序

按 `created_at ASC` 排序（最早的在最上面），与现有行为保持一致。**不改排序逻辑。**

## 4. 客户端改造

### 4.1 Flutter

**`data/models/forum.dart`**：

- 删除 `replyLevel` 字段（line 547、561、582、604 共 4 处）
- 删除 `isSubReply` 计算 getter（line 568，已经没人用应当一并清理；如有 caller 改成判断 `parentReplyId != null`）

**`features/forum/views/forum_post_detail_view.dart`**：

- 现有"回复 @xxx"渲染（在 `_ReplyCard` 内部，需要定位到具体行）改造为可点击 widget：
  - `GestureDetector` 包住"回复 @xxx" 文字
  - `onTap`: 通过 `widget.replyKeys[reply.parentReplyId]?.currentContext` 拿到目标 widget context
  - 调 `Scrollable.ensureVisible(targetContext, duration: 300ms, alignment: 0.3)` 平滑滚动
  - 用 `AnimationController` 触发目标 `_ReplyCard` 的 200ms 背景色脉冲（淡黄色 → 透明），通过 `replyKeys` 持有的状态触发
- `replyKeys: Map<int, GlobalKey>` 已存在（line 546），不用新建

**实施细节**：高亮脉冲可以通过 `_ReplyCard` 内部维护一个 `ValueNotifier<bool> highlight`，通过 `forum_post_detail_view` 顶层的一个 `Map<int, ValueNotifier<bool>>` 在跳转时翻一下；或者用更简单的 `Stream<int>` 广播被高亮的 reply id，每个 `_ReplyCard` 监听并用 `AnimatedContainer` 切色。后者更简洁，倾向后者。

### 4.2 Web

**`frontend/src/api.ts`**：
- `ForumReply`/`ForumReplyOut` 类型删除 `reply_level` 字段
- 删除 `replies?: ForumReply[]` 嵌套字段

**`frontend/src/pages/ForumPostDetail.tsx`**：

变更点 1（line 987-991，递归→单层）：

```tsx
// 删除：
{reply.replies && reply.replies.length > 0 && (
  <div className={styles.nestedReplies}>
    {reply.replies.map((nestedReply) => renderReply(nestedReply, level + 1))}
  </div>
)}

// 删除外层调用的 level 参数（line 1339）：
{replies.map((reply) => renderReply(reply))}  // 不再传 level
```

变更点 2（"@xxx" 可点击）：

- 给每个 reply 容器加 `id={`reply-${reply.id}`}`
- 在 reply header 渲染处加 "@xxx" 元素：
  ```tsx
  {reply.parent_reply_author && (
    <span
      className={styles.replyMention}
      onClick={() => {
        const target = document.getElementById(`reply-${reply.parent_reply_id}`);
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'center' });
          target.classList.add(styles.highlightPulse);
          setTimeout(() => target.classList.remove(styles.highlightPulse), 800);
        } else {
          // parent 不在已加载列表 — toast 提示
          message.info(t('forum.replyTargetNotLoaded'));
        }
      }}
    >
      @{reply.parent_reply_author.name}
    </span>
  )}
  ```
- 加 `.highlightPulse` CSS：`background-color` 200ms 淡入淡出
- `styles.nestedReplies` 缩进样式可以删（确认无其他地方引用后）

变更点 3（`level` 参数清理）：
- `renderReply(reply: ForumReply, level: number = 0)` 移除 level 参数
- 函数体内引用 `level` 的地方全部清理

### 4.3 Admin

不动。审核视图本来就是平铺。

## 5. 边界与降级行为

| 场景 | 行为 |
|---|---|
| Parent reply 在当前已加载列表 | 平滑滚动 + 200ms 高亮 |
| Parent reply 已 soft-deleted（`is_deleted=true`） | 后端返回 `parent_reply_author=null` 或带"已删除"占位；前端渲染 `@[已删除]` 灰色不可点 |
| Parent reply 因内容过滤隐藏（`is_visible=false`） | 同 soft-deleted |
| Parent reply 在更早分页（未加载） | toast 提示"请加载更多以查看原回复"，不主动加载（避免分页跳跃） |
| Parent reply 作者改名 | 显示当前 name（DB join 查的是当前值，已是该行为） |
| 用户尝试回复一条已删除的回复 | 后端校验"父回复不存在"返回 404；前端在删除后应禁用回复按钮 |
| `parent_reply_id` 指向跨帖回复 | 后端校验 `parent_reply.post_id != post_id` 返回 400（已有） |

## 6. 数据库迁移

新增 `backend/migrations/219_drop_forum_reply_level.sql`：

```sql
-- 删除 reply_level 硬限制 — 论坛回复改为扁平化模型
-- 关联设计文档: docs/superpowers/specs/2026-04-26-forum-flat-replies-design.md

BEGIN;

-- 1) 删除 CheckConstraint
ALTER TABLE forum_replies DROP CONSTRAINT IF EXISTS check_reply_level;

-- 2) 删除 reply_level 列
ALTER TABLE forum_replies DROP COLUMN IF EXISTS reply_level;

COMMIT;
```

无需 backfill（删列即可，无数据丢失：`reply_level` 只是渲染辅助，删了之后所有回复仍按 `parent_reply_id` 存在，只是不再有"层级"概念）。

回滚预案（如需）：

```sql
ALTER TABLE forum_replies ADD COLUMN reply_level Integer DEFAULT 1;
-- 递归 CTE 重新计算 level（从 parent_reply_id 链向上数）
WITH RECURSIVE reply_depth AS (
    SELECT id, 1 AS level FROM forum_replies WHERE parent_reply_id IS NULL
    UNION ALL
    SELECT r.id, rd.level + 1
    FROM forum_replies r
    JOIN reply_depth rd ON r.parent_reply_id = rd.id
)
UPDATE forum_replies SET reply_level = LEAST(rd.level, 3) FROM reply_depth rd WHERE forum_replies.id = rd.id;
ALTER TABLE forum_replies ADD CONSTRAINT check_reply_level CHECK (reply_level BETWEEN 1 AND 3);
```

（仅供参考；线上回滚一般不需要这一步，业务上保留扁平化即可。）

## 7. 部署顺序（按 `feedback_migration_before_deploy` 经验）

1. **linktest 跑 migration 219** — 验证 DROP CONSTRAINT + DROP COLUMN 成功，无关联表 trigger 报错
2. **linktest 部署后端代码** — 写入逻辑不再传 `reply_level`，schema 不再返回该字段
3. **linktest smoke** — 创建一条回复回复（包括 parent 是 L2 的情况，原本会 403），验证 200
4. **prod 跑 migration 219**（手动，非自动跟随代码部署）
5. **prod push 后端代码**
6. **push Flutter 代码**（已删除 `replyLevel` 字段读取，向后兼容旧后端响应中可能残留的字段——`json['reply_level'] as int? ?? 0` 已经 graceful，但发版后立即生效新形态）
7. **push Web 代码**

## 8. 测试清单

### 后端
- [ ] 用 secure_auth user 创建帖子的"L1 回复"（`parent_reply_id=null`）→ 200
- [ ] 创建"L2 回复"（`parent_reply_id` 指向 L1）→ 200
- [ ] 创建"L3 回复"（`parent_reply_id` 指向 L2，原本 403）→ **现在应 200**
- [ ] 创建"L4 回复"（`parent_reply_id` 指向 L3，原本 403）→ **现在应 200**
- [ ] 创建无限深度的链 → 200（无层级限制）
- [ ] `parent_reply_id` 指向不存在的 reply → 404
- [ ] `parent_reply_id` 指向跨帖 reply → 400
- [ ] 列表端点返回的 `ForumReplyOut` 不含 `reply_level` 字段
- [ ] 通知收发：A 回复 B（任意深度）→ B + 帖子作者收到通知
- [ ] DB 校验：`SELECT column_name FROM information_schema.columns WHERE table_name='forum_replies' AND column_name='reply_level'` 返回空
- [ ] DB 校验：`SELECT conname FROM pg_constraint WHERE conname='check_reply_level'` 返回空

### Flutter
- [ ] 旧帖子加载（数据中含 reply_level=3 的回复）正常渲染
- [ ] 发新回复回复任何回复，都成功
- [ ] 点击 "@xxx" → 平滑滚动到目标 + 高亮 200ms
- [ ] Parent 已删除 → "@[已删除]" 不可点
- [ ] Parent 不在当前加载范围 → 现状不实现跨页跳转（如需，后续单独迭代）

### Web
- [ ] 旧帖子加载正常（不再使用 `reply.replies` 嵌套字段）
- [ ] 平铺渲染，无嵌套缩进
- [ ] 点击 "@xxx" → `scrollIntoView` + `highlightPulse` 类生效
- [ ] Parent 不在 DOM → toast 提示
- [ ] 类型检查通过（`tsc --noEmit`）

## 9. 与 forum_routes.py 拆分（同日另一份 spec）的关系

`docs/superpowers/specs/2026-04-26-forum-routes-split-design.md` 计划把 `forum_routes.py` 拆成 7 个 `forum_*_routes.py`。本设计的后端改动落点（`forum_routes.py:4855-5030` 创建回复端点 + `:4730` 列表端点 + 通知逻辑）在拆分后会迁到 `forum_replies_routes.py`（按拆分 spec §3 的域划分）。

**两种实施顺序：**

- **先拆分再扁平化（推荐）**：拆分是行为零变更的纯结构 PR，merge 后扁平化的改动只在 `forum_replies_routes.py` 一个文件里，diff 清晰。
- **先扁平化再拆分**：扁平化改动落在 `forum_routes.py` 当前位置，拆分时把这部分顺势带过去。可以但 diff 跨两个 PR 有时序耦合。

**推荐先拆分。**

## 10. 工作量估算

| 部分 | 行数（净变化） | 时间 |
|---|---|---|
| Migration 219 | +20 | 5 分钟 |
| `models.py` | -2 | 2 分钟 |
| `schemas.py` | -2 | 2 分钟 |
| `forum_routes.py` 创建端点 | -15 | 10 分钟 |
| `routes/forum_my_routes.py` | -1 | 1 分钟 |
| Flutter `forum.dart` | -4 | 5 分钟 |
| Flutter view "@xxx" 跳转 | +30 | 30 分钟 |
| Web `api.ts` types | -3 | 3 分钟 |
| Web `ForumPostDetail.tsx` | +25 / -10 | 30 分钟 |
| 联调 + 测试 | — | 30 分钟 |
| **总计** | **~ 净 +40 行** | **~ 2 小时** |

属于"半天内做完"的小改动。

## 11. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| Migration 在 prod 跑时锁表过久 | `forum_replies` 表大时 DROP COLUMN 可能持锁 | DROP COLUMN 在 PostgreSQL 是 metadata-only 操作（不重写表），快速完成；如线上表大于 1M 行可在低峰期跑 |
| Flutter 老版本 app 收到不含 `reply_level` 的响应 | `replyLevel` 字段读取 `json['reply_level'] as int? ?? 0` 已 graceful，无 crash | 现有兜底足够；不需要发版强制升级 |
| Web 用户在跳转时看到列表抖动 | `scrollIntoView` 平滑滚动可能突兀 | 用 `block: 'center'` + `behavior: 'smooth'` 平滑过渡 |
| 评论数显著增长后扁平列表过长 | 单帖几百条回复时阅读体验下降 | 当前分页机制（page_size）继续生效；如未来真触发瓶颈再升级到 bucket 模型（β 方案） |

## 12. 后续可能的演进

如果未来论坛单帖 P95 回复数超过 50，或产品决策需要"小红书式聚簇"，按以下顺序演进：

1. 加 `thread_root_id` 列 + 递归 backfill（设计中 B2 方案）
2. 修改列表 API 返回 "L1 + 每个 L1 取最新 3 条 L2 + 总数"
3. 新增 bucket 端点 `GET /api/forum/replies/{l1_id}/bucket`
4. Flutter / Web 重写 reply 渲染区，加 bucket 展开 UI

那次升级的工作量预估为 700-1100 行 + 2-4 天（详见本次 brainstorm 历史）。本次扁平化方案不阻塞那个演进，只是推迟它。

## 13. 向后兼容性

### 13.1 旧 Flutter app（已安装版本）

**完全无影响，且修复了一个隐性 bug。**

三个证据支撑：

1. **`reply_level` 字段在 Flutter 视图里实际不参与渲染决策**。视觉差异（头像 28px vs 32px、字号 13 vs 14）由 `isSubReply = parentReplyId != null` 驱动（`forum.dart:568`），与层级无关。`reply_level` 字段在 model 里存在但没有 caller。
2. **`ForumReply.fromJson` 不读取 `replies` 嵌套字段**（`forum.dart:590-613`），model 类也没有该字段。后端从响应中移除 `replies` 子数组对 Flutter 是透明操作。
3. **`forum_repository.dart:266` 的 `_flattenReplyTree` 是幂等的**——它递归遍历 `children` 把树形拍平为一维数组。当输入已经是扁平时，递归不触发，返回相同的扁平列表。

**用户感知到的唯一变化**：以前回复深度回复（撞 L3 上限）会失败，现在成功。属于无声修复。

**结论**：不需要强制升级 app，不需要发版本说明。

### 13.2 旧 Web（浏览器缓存中的旧 JS）

**Vercel + Cloudflare 缓存窗口期（5-15 分钟）内会出现视觉降级，但不是 broken 状态，且不丢内容。**

降级表现：
- `reply.replies` 在新后端响应中始终为空 → 递归 `renderReply(level+1)` 不触发 → 所有回复同层级平铺渲染
- 旧 Web 没有 `parent_reply_author` 渲染逻辑（grep 验证：0 引用） → 看不到"@xxx"前缀
- 视觉效果：从"嵌套对话树"变成"一长串无缩进平铺评论"

未受影响的功能：
- 发回复、点赞、举报、删除等所有 onClick 行为不依赖嵌套结构，全部正常
- 评论内容、作者、时间戳完整呈现

接受方案 A：**不做缓解，承受 5-15 分钟视觉降级窗口**。原因：
- 不丢内容、不丢功能，仅信息架构呈现方式变化
- 缓解方案（双写、双轨渲染、Web 先于后端部署）的工程复杂度高于"接受短暂降级"的成本
- 论坛不是核心交易路径，5-15 分钟非破坏性降级业务影响极小

### 13.3 部署时序约束

由 §13.1 / §13.2 推出的安全部署顺序：

1. linktest 跑 migration → linktest 后端代码 → linktest smoke
2. prod 跑 migration → prod 后端代码（此刻起，旧 Web 进入降级窗口）
3. prod 推 Web 代码（缓存命中的用户陆续在 5-15 分钟内拿到新 JS，降级结束）
4. prod 推 Flutter 代码（无降级窗口，纯升级）

Flutter / Web 推送顺序无关紧要——Flutter 老版本与新后端兼容，Web 老版本进入降级但不破坏。

### 13.4 admin / iOS native

- Admin 后台审核视图本来就是平铺，无嵌套依赖，零影响。
- iOS 原生 app 已退役（CLAUDE.md），不参与。
