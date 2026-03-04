# 帖子通用文件上传 — 开发文档

**日期**：2026-02-26  
**状态**：待实现  
**约束**：帖子只能选择「图片」或「文件」之一，不能同时上传图片和文件，避免内容混在一起难以维护与展示。

---

## 1. 背景与目标

- **现状**：帖子仅支持上传图片（最多 5 张），通过 `/api/v2/upload/image?category=forum_post` 上传，发帖时传入 `images` 列表。
- **目标**：支持帖子通用文件上传（如 PDF），便于分享文档、资料等；同时保持界面简洁，**不允许同一帖子既上传图片又上传文件**。
- **规则**：
  - **二选一**：发帖/编辑时，用户要么只添加图片，要么只添加文件，不能两者同时添加。
  - 若用户已添加图片后再点「添加文件」，应清空已选图片并进入「文件模式」；反之亦然。

---

## 2. 后端改动

### 2.1 数据库

- **表**：`forum_posts`
- **新增列**（建议迁移文件名：`xxx_forum_post_attachments.sql`）：

| 列名 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `attachments` | JSON/JSONB | NULL | 附件列表。格式：`[{"url":"...","name":"xxx.pdf","type":"pdf","size":12345}]`。`type` 可为 `pdf` 等，便于前端展示图标。 |

- 现有 `images` 列保持不变；帖子要么有 `images` 非空，要么有 `attachments` 非空，二者互斥由业务层校验。

### 2.2 存储与上传接口

- **存储路径**：建议与图片分离，例如 `public/files/forum_posts/`（或沿用现有存储的等价路径，如 R2 的 `public/files/forum_posts`）。
- **新接口**：`POST /api/v2/upload/file`（或 `POST /api/v2/upload/file?category=forum_post`）。
  - **参数**：`file: UploadFile`，`category=forum_post`（若用 category 区分）。
  - **校验**：
    - 允许的 MIME/扩展名：例如 `application/pdf`、`.pdf`；可按需扩展（如 `.doc`, `.docx`），需在文档中明确列出。
    - 单文件大小上限：建议 10MB。
    - 不做图片魔数校验，不做缩略图。
  - **响应**：与现有图片上传一致，至少返回 `{ "url": "...", "filename": "..." }`；可选返回 `size`、`type` 供前端展示。
- **临时目录**：与图片一致，未发帖前先传到 `temp_{user_id}`，发帖时再 `move_from_temp` 到 `{post_id}`，避免垃圾文件堆积。

若后端已有「通用文件上传」逻辑（如任务/客服聊天用的 `upload_file`），可复用存储与鉴权，仅新增 `category=forum_post` 及公开访问路径；否则在 `upload_routes.py` 中新增一条 file 上传路由，并调用存储后端写入 `public/files/forum_posts/...`。

### 2.3 发帖/更新帖子接口

- **创建帖子** `POST /api/forum/posts`（或当前实际路径）  
  - Body 新增可选字段：`attachments: Optional[List[Dict]]`，例如 `[{"url":"...","name":"a.pdf","type":"pdf"}]`。
  - **业务校验**：
    - 若 `images` 非空且 `attachments` 非空 → 返回 400，错误码如 `IMAGES_AND_ATTACHMENTS_MUTUAL_EXCLUSIVE`，提示「请只选择上传图片或上传文件，不能同时使用」。
    - 若 `attachments` 非空：校验每条为合法 URL、数量上限（建议 ≤5）、`type` 在白名单内。
  - 写库时：仅当 `attachments` 有值时写入 `forum_posts.attachments`；有 `images` 时 `attachments` 置为 NULL 或空数组（由实现统一约定）。

- **更新帖子** `PUT /api/forum/posts/{post_id}`  
  - 同样支持 `attachments`，且与 `images` 互斥：若请求中同时带两者且都非空 → 400。
  - 若从「图片帖」改为「文件帖」：请求只带 `attachments` 不带 `images`（或显式传 `images=[]`），后端更新为 `images` 空、`attachments` 有值；反之亦然。

### 2.4 Schema 与模型

- **Pydantic**（如 `ForumPostCreate` / `ForumPostUpdate`）：
  - 新增 `attachments: Optional[List[AttachmentItem]] = None`。
  - `AttachmentItem` 建议包含：`url: str`，`name: Optional[str]`，`type: Optional[str]`（如 `pdf`）。
  - 在 schema 或路由层增加 validator：若 `images` 与 `attachments` 均非空则报错。

- **ORM 模型**（如 `ForumPost`）：
  - 新增 `attachments = Column(JSON, nullable=True)`，与 2.1 一致。

- **列表/详情响应**：
  - 在帖子出参中增加 `attachments` 字段（与 `images` 并列），方便前端展示「附件列表」。

---

## 3. Flutter 改动

### 3.1 数据层

- **模型**（`lib/data/models/forum.dart`）：
  - 定义 `ForumPostAttachment`（如 `url`, `name`, `type`）。
  - `ForumPost` 增加 `List<ForumPostAttachment> attachments`（或 `List<Map>` 由 fromJson 解析）。
  - `CreatePostRequest` 增加 `attachments`，并在 `toJson` 中序列化；保持与后端「二选一」的约定，由 UI 保证不同时传 `images` 和 `attachments`。

- **Repository**（`ForumRepository`）：
  - 新增 `uploadPostFile(String filePath)`（或 `uploadPostFile(XFile file)`），请求 `POST /api/v2/upload/file?category=forum_post`，返回 `url`（及可选 `name`/`type`）。
  - `createPost` / `updatePost` 的请求体中在支持 `images` 的基础上增加 `attachments` 字段。

- **API 常量**（`api_endpoints.dart`）：
  - 新增 file 上传端点，例如 `uploadFileV2 = '/api/v2/upload/file'`（若与后端一致）。

### 3.2 发帖/编辑页 UI

- **互斥逻辑**：
  - 当前为「图片模式」：只显示「添加图片」，已选图片列表；不显示「添加文件」或置灰。
  - 当前为「文件模式」：只显示「添加文件」，已选文件列表；不显示「添加图片」或置灰。
  - 切换方式示例：  
    - 用户已选图片后点击「添加文件」→ 清空已选图片，进入文件模式，允许选文件。  
    - 用户已选文件后点击「添加图片」→ 清空已选文件，进入图片模式，允许选图片。
  - 若产品希望默认是「图片模式」，则进入页面时未选择任何内容时显示图片入口；一旦用户选了文件，即切换到文件模式并清空图片。

- **文件选择**：
  - 使用 `file_picker`（或平台文件选择）限制类型为 PDF（及后端允许的其它类型）；单文件大小校验（≤10MB）；数量上限与后端一致（如 5）。
  - 上传顺序：先选文件 → 逐个或批量调用 `uploadPostFile` → 将返回的 URL 与 name/type 加入本地列表，提交时作为 `attachments` 传给 create/update。

- **展示**：
  - 已选文件列表展示文件名、类型图标（如 PDF）、大小（若有）、删除按钮；与已选图片列表在 UI 上互斥显示。

### 3.3 帖子详情页

- 若 `post.attachments` 非空：展示「附件」区域，列表项为链接（打开 URL，可用 `url_launcher` 或 in_app_browser）；显示文件名、类型、可选大小。
- 若 `post.images` 非空：按现有逻辑展示图片，不展示附件区域；二者不会同时存在。

### 3.4 文案与错误码

- 文案需与产品统一，例如：「只能上传图片或文件其中一种」「请只选择上传图片或上传文件，不能同时使用」。
- 后端 400 错误码可在 Flutter 中映射为提示文案。

---

## 4. iOS 对齐（参考实现）

- 业务逻辑与 Flutter 一致：发帖/编辑时「图片与文件二选一」；创建/更新请求同时支持 `images` 与 `attachments`，且后端校验互斥。
- 发帖页：增加文件选择（如 PDF），上传到同一 `POST /api/v2/upload/file?category=forum_post`，将返回的 URL 填入 `attachments`。
- 帖子详情：若有 `attachments` 则展示附件列表并支持打开链接。

---

## 5. 安全与限制

- **类型白名单**：仅允许后端声明的类型（如 PDF）；禁止可执行文件等。
- **大小与数量**：单文件 ≤10MB，每帖附件数 ≤5（可与产品再定）。
- **鉴权**：file 上传接口与 image 一致，需登录；发帖/更新帖需验证作者或管理员权限。
- **存储**：文件存于公开只读路径，不执行、不解析为 HTML，仅提供下载/预览链接。

---

## 6. 测试要点

- 发帖时只传 `images` → 成功，`attachments` 为空。
- 发帖时只传 `attachments` → 成功，`images` 为空。
- 发帖时同时传 `images` 与 `attachments` 且都非空 → 400。
- 更新帖子时从「仅图片」改为「仅附件」→ 成功；反之中间态与结果均符合互斥。
- 文件类型/大小超限 → 上传或提交时报错。
- 帖子详情/列表接口返回的 `attachments` 与 `images` 符合互斥与预期格式。

---

## 7. 实现顺序建议

1. 后端：迁移增加 `attachments` 列；Schema 与 create/update 校验（含互斥）；file 上传接口与存储路径。
2. Flutter：模型与 Repository 支持 `attachments` 与 `uploadPostFile`；发帖/编辑页「二选一」UI 与文件选择；帖子详情展示附件。
3. iOS：按同一接口与规则实现发帖/编辑/详情。
4. 联调与回归：图片帖、文件帖、互斥校验与错误提示。

---

## 8. 参考代码位置（当前实现）

| 模块 | 路径/说明 |
|------|-----------|
| 发帖创建（Flutter） | `link2ur/lib/features/forum/views/create_post_view.dart`：图片选择与 `uploadPostImage` |
| 发帖编辑（Flutter） | `link2ur/lib/features/forum/views/edit_post_view.dart` |
| 论坛仓库（Flutter） | `link2ur/lib/data/repositories/forum_repository.dart`：`uploadPostImage`、`createPost` |
| 帖子模型（Flutter） | `link2ur/lib/data/models/forum.dart`：`ForumPost`、`CreatePostRequest` |
| 创建帖子（后端） | `backend/app/forum_routes.py`：`create_post`、`move_from_temp` 处理 images |
| 上传接口（后端） | `backend/app/upload_routes.py`：`/api/v2/upload/image`；需新增 file |
| 上传服务（后端） | `backend/app/services/image_upload_service.py`：仅图片；file 可新服务或同模块扩展 |
| Schema（后端） | `backend/app/schemas.py`：`ForumPostCreate`、`ForumPostUpdate` |
| 帖子表（后端） | `backend/app/models.py`：`ForumPost` |

以上为帖子通用文件上传的完整开发文档，核心约束为：**上传文件与上传图片二选一，不可同时使用**。
