# 任务聊天发送视频与 PDF 设计文档

- **日期**: 2026-05-15
- **范围**: Flutter 客户端 + FastAPI 后端
- **关键改动文件清单**: 见"组件与文件"一节
- **决策**: 采用 Approach A（最大化复用现有 PrivateFileSystem 与 `message_attachments` 表）

---

## 1. 背景

Link2Ur 是技能互助/任务交易平台,刻意不做通用私聊;用户间所有沟通必须绑定 task / service / flea_market_item,通过"咨询通道"承载。当前任务聊天(`features/chat/`)只支持文字 + 图片(图片库 + 拍照),不支持发送视频或文件。

业务诉求:让委托方能在咨询中给接单方发送**短视频说明现场情况**或**PDF 报价单 / 需求文档**。

本设计在保持"反滥用受限通道"产品定位的前提下,扩展任务聊天的媒体能力。

## 2. 需求范围与上限

| 维度 | 决策 |
|---|---|
| 范围 | 视频 + PDF(两者同期实现) |
| 视频最长时长 | ≤ 30 秒 |
| 视频最大体积 | ≤ 30 MB |
| 视频处理 | 前端轻度压缩(1080p@~2Mbps)+ 前端抽首帧 JPEG 作为缩略图,二者作为 2 个 attachment 同包上传 |
| 文件类型 | 仅 PDF(扩展名 + MIME + magic byte 三重校验) |
| PDF 最大体积 | ≤ 20 MB |
| 生命周期 | 跟随任务/商品/服务清理(复用现有 `image_cleanup` / `cleanup_tasks` 逻辑) |
| 播放行为 | 点击缩略图直接进全屏播放器,不做移动数据二次确认 |
| 撤回 | 不支持(与现有图片一致) |
| 限流 | 复用现有 `@rate_limit("upload_file")` |
| 本地保存 | 图片和视频在全屏查看页右上角加 **三点更多按钮**,点击弹菜单含"保存到相册";PDF 点击即下载并系统打开(本来就是下载行为,不需要额外保存入口) |

## 3. 决策依据

- `message_attachments` 表(`backend/app/models.py:970-989`)的 `attachment_type` 字段注释明确为"image/file/video 等",**schema 层无需迁移**
- `PrivateFileSystem` 与 `/api/upload/file` 端点已经为"任务完成证据"功能存在,鉴权/清理逻辑齐备
- 前端 `chat_bloc.dart:512-525` 发送图片已经走 attachments 数组结构,新增类型只需扩展现有路径
- Approach A 比 B/C 低成本,且未来真需要隔离时切口清晰(YAGNI)

## 4. 架构概览

```
┌──── Flutter Client ────────────────────────┐    ┌──── Backend (FastAPI) ──────────────────┐
│                                            │    │                                          │
│ TaskChatActionMenu                         │    │ POST /api/upload/file?usage=chat_media   │
│  ├─ 照片  (image_picker.pickMedia)         │    │  ├─ rate_limit("upload_file")            │
│  │   └─ 图片→既有路径                      │    │  ├─ chat 专用校验:                       │
│  │   └─ 视频→压缩→抽帧→并行上传 ─────────▶│    │  │   - 视频 ≤30MB + magic byte           │
│  ├─ 拍照  (既有,只拍照片)                  │    │  │   - PDF ≤20MB + magic byte            │
│  ├─ 文件  (file_picker, PDF only)  ────────▶    │  └─ PrivateFileSystem                    │
│  ├─ 任务详情 / 地址 (既有)                 │    │      ↓ private_files/tasks/{task_id}/chat/
│                                            │    │      ↓ blob_id + 签名 URL                │
│ ChatBloc                                   │    │                                          │
│  ├─ ChatSendVideo (新)                     │    │ POST /api/messages/task-chat (既有)      │
│  ├─ ChatSendFile  (新)        ────────────▶│    │  ├─ message_type='video' or 'file'       │
│                                            │    │  ├─ attachments=[{type,blob_id,meta},...]│
│ MessageGroupBubble                         │    │  └─ DB: messages + message_attachments   │
│  ├─ image bubble (既有)                    │    │                                          │
│  ├─ video bubble (新) → VideoPlayerView    │    │ WebSocket 推送(扩展 routers.py:554-606  │
│  └─ file bubble (新)  → 下载/系统打开 ◀────│    │  的 attachment-only-image 解析逻辑)      │
└────────────────────────────────────────────┘    └──────────────────────────────────────────┘
```

### 发送视频流程

1. 用户在工具栏点"照片"→ `image_picker.pickMedia` 弹出系统图库,允许 image 或 video
2. 选中视频 → 前端读取时长元数据 → 若 >30s 则 SnackBar `chat_video_too_long`,中止
3. `video_compress.compressVideo()` 压到 1080p@~2Mbps,显示压缩进度
4. 若压缩后仍 >30MB → SnackBar `chat_video_too_large`,中止
5. `video_thumbnail.thumbnailData()` 抽首帧 JPEG(540×?, ≤80KB)
6. **并行 2 次** `POST /api/upload/file?usage=chat_media`:
   - 视频文件 → blob_id_v + meta `{duration, width, height, size, original_filename}`
   - 缩略图 JPEG → blob_id_t + meta `{role:'thumbnail', width, height}`
7. 调 `POST /api/messages/task-chat`(既有),body:
   ```json
   {
     "task_id": 123,
     "content": "[视频]",
     "message_type": "video",
     "attachments": [
       {"attachment_type":"video","blob_id":"<blob_id_v>","meta":{"duration":28,"width":1080,"height":1920,"size":8500000,"original_filename":"IMG_1234.MOV"}},
       {"attachment_type":"image","blob_id":"<blob_id_t>","meta":{"role":"thumbnail","width":540,"height":960}}
     ]
   }
   ```
8. 后端落库 + WebSocket 推给对方
9. 接收端 MessageGroupBubble 按 `message_type=='video'` 渲染视频气泡(找 `meta.role=='thumbnail'` 的 attachment 当封面)

### 发送 PDF 流程

1. 工具栏点"文件"→ `file_picker.pickFiles(type:FileType.custom, allowedExtensions:['pdf'])`
2. 前端校验 size ≤20MB
3. `POST /api/upload/file?usage=chat_media` → blob_id_f
4. `POST /api/messages/task-chat` body 含 `attachments=[{attachment_type:'file', blob_id, meta:{original_filename, content_type, size}}]`,content = `[文件:filename.pdf]`,message_type=`'file'`
5. 接收端按 `message_type=='file'` 渲染文件气泡;点击 → push `PdfPreviewView` → 后台下载到 app 临时目录 → 用 `flutter_pdfview` 嵌入预览;预览页右上角三点 `PopupMenuButton`,菜单含「用其他应用打开」(`open_filex`) 和「分享 / 保存」(`share_plus` 调系统分享面板,iOS 含"存储到文件"项,Android 含"保存到设备")

## 5. 组件与文件

### Flutter 端

| 文件 | 类型 | 职责 |
|---|---|---|
| `lib/features/chat/widgets/task_chat_action_menu.dart` | 改 | "图片"label 改"照片";`onImagePicker` 回调内部用 `pickMedia`,UI 不变;新增 `onFilePicker` 入口按钮(PDF) |
| `lib/features/chat/widgets/video_message_bubble.dart` | 新 | 渲染缩略图 + 时长徽章 + 中央播放按钮覆盖层;点击 push 全屏播放页 |
| `lib/features/chat/widgets/file_message_bubble.dart` | 新 | PDF 图标 + 文件名 + 大小标签;点击 push `PdfPreviewView` |
| `lib/features/chat/views/pdf_preview_view.dart` | 新 | app 内嵌 PDF 预览(`flutter_pdfview`);下载到临时目录后渲染;右上角三点 `PopupMenuButton` → 「用其他应用打开」+「分享 / 保存」 |
| `lib/features/chat/views/video_player_view.dart` | 新 | 全屏 chewie 播放器;签名 URL 从 attachment 解析;右上角三点 `PopupMenuButton` → 含「保存到相册」项 |
| `lib/core/widgets/full_screen_image_view.dart` | 改 | `FullScreenImageView` 加可选参数 `allowSaveToAlbum`(默认 false,保持其他调用方不变);任务聊天调用方传 true 时右上角渲染三点 `PopupMenuButton` → 含"保存到相册"项。后续要加"转发""举报"等动作时再重构为通用 actions 列表(YAGNI) |
| `lib/core/utils/media_saver.dart` | 新 | 封装相册保存逻辑(图片 + 视频统一入口),处理 iOS / Android 权限请求与错误反馈 |
| `lib/features/chat/widgets/message_group_bubble.dart` | 改 | 按 `message.messageType` 分发到 image / video / file bubble |
| `lib/features/chat/bloc/chat_bloc.dart` | 改 | 新事件 `ChatSendVideo` / `ChatSendFile`;复用 SendImage 的 optimistic update + retry 模式 |
| `lib/data/repositories/message_repository.dart` | 改 | 新方法 `uploadChatVideo(bytes, filename) → blob_id`,`uploadChatFile(bytes, filename) → blob_id` |
| `lib/data/models/message.dart` | 改 | 解析 `attachments` 列表(若现有 Message 模型尚未支持非 image 类型) |
| `lib/l10n/app_zh.arb` / `app_en.arb` / `app_zh_Hant.arb` | 改 | 加 `chatPhotoLabel`、`chatVideoLabel`、`chatFileLabel`、`chatVideoMessage`、`chatFileMessage(filename)`、各错误码翻译 |
| `pubspec.yaml` | 改 | 加 `video_compress`、`video_thumbnail`、`video_player`、`chewie`、`file_picker`、`open_filex`、`gal`(图片/视频保存到相册)、`flutter_pdfview`(PDF 嵌入预览)、`share_plus`(系统分享面板,做"保存"和"用其他应用打开"的后端) |
| `ios/Runner/Info.plist` | 改 | 加 `NSPhotoLibraryAddUsageDescription`(写相册权限说明文案,三语) |
| `android/app/src/main/AndroidManifest.xml` | 改 | 加 `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28) + `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (SDK 33+);`gal` 包通常会自动声明,需核查 |

### Backend 端

| 文件 | 类型 | 改动 |
|---|---|---|
| `backend/app/upload_routes.py` 或现有 `/api/upload/file` 路由所在文件 | 改 | 加 `?usage=chat_media` query 参数;走 chat 专用校验(视频 30MB + magic byte;PDF 20MB + magic byte);落 `private_files/tasks/{task_id}/chat/` 子目录 |
| `backend/app/routers.py:554-606` 现有 attachment 解析逻辑 | 改 | 识别 `attachment_type IN ('image','video','file')`;序列化时透传 meta 字段 |
| `backend/app/services/file_validators.py` 或 `backend/app/file_utils.py` | 新 或 改 | 封装 `validate_chat_video(content)` + `validate_chat_pdf(content)`(扩展名 + MIME + magic byte + size) |
| `backend/app/schemas.py` 中 `MessageAttachmentOut` / `MessageOut` | 核查 | 确认 `attachment_type` 为 free string,`meta` 字段已透传(若未透传需扩展) |
| `backend/app/image_cleanup.py` / `backend/app/cleanup_tasks.py` | 改 | 任务清理时把 `private_files/tasks/{task_id}/chat/` 子目录一并清掉 |
| 数据库 schema | **不变** | `message_attachments` 表 schema 已支持 |

## 6. 关键不变量

- `messages.content` 永远非空:按 `messageType` 填 `[图片]` / `[视频]` / `[文件:filename.pdf]`,前端渲染时按 `messageType` 走 l10n key,后端 placeholder 仅作 fallback
- `message_attachments` CheckConstraint `(url XOR blob_id)` 不变,本次新增类型全部走 `blob_id`(私密)
- **视频消息必有 2 条 attachment**:1 条 `type='video'` + 1 条 `type='image' + meta.role='thumbnail'`
- 前端缩略图缺失时 fallback 纯黑底 + 中央播放图标(不阻断播放)
- 文件消息有 1 条 attachment:`type='file' + meta={original_filename, content_type, size}`

## 7. 错误处理

错误码进入 `lib/core/utils/error_localizer.dart` 映射,三语 ARB 同步:

| 错误码 | 触发 | UI |
|---|---|---|
| `chat_video_too_long` | 客户端校验时长 >30s | SnackBar 红色,不上传 |
| `chat_video_too_large` | 压缩后仍 >30MB | SnackBar |
| `chat_video_compress_failed` | video_compress 返回 null | SnackBar |
| `chat_video_thumbnail_failed` | 抽帧失败 | **不阻断**,上传纯视频 + 前端 fallback |
| `chat_file_type_not_allowed` | 非 PDF | SnackBar |
| `chat_file_too_large` | PDF >20MB | SnackBar |
| `chat_upload_network_offline` | NetworkMonitor 离线 | SnackBar |
| `chat_upload_failed` | 网络/超时 | SnackBar + optimistic 消息回滚 |
| `chat_video_play_failed` | 播放器初始化失败 | 全屏页错误 + 重试按钮 |
| `chat_file_download_failed` | PDF 下载失败 | SnackBar |
| `chat_pdf_preview_failed` | flutter_pdfview 初始化或渲染失败 | 预览页错误占位 + "用其他应用打开"按钮 + 重试 |
| `chat_save_permission_denied` | 用户拒绝相册写入权限 | SnackBar + "去设置"按钮(跳系统设置) |
| `chat_save_failed` | 写相册失败(磁盘满 / 文件损坏) | SnackBar |
| `chat_save_success` | 保存成功 | SnackBar 绿色 + 文案"已保存到相册" |

### Optimistic Update(对齐现有 SendImage)

1. 用户点发送 → 立即插入 pending 消息(占位 + spinner)
2. 上传 attachment(s) → 拿 blob_id(视频两个并行;进度条 = video_compress 进度 + Dio onSendProgress 加权)
3. 拿 blob_id 后调 send-message API → 拿真实 message
4. 用真实 message 替换 pending 占位(按 pendingId 匹配)
5. 任一步失败 → 移除 pending + emit errorMessage

**取消上传**:pending 消息上加"取消"按钮,绑定 Dio CancelToken。

## 7.5 本地保存(图片 / 视频)

### 交互

- **图片**:消息气泡点击 → 现有 `FullScreenImageView`(`photo_view` 全屏 lightbox);本次给它加可选参数 `allowSaveToAlbum`,任务聊天的调用方传 `true`,右上角渲染三点 `PopupMenuButton`,菜单含"保存到相册"。点击 → 调用 `MediaSaver.saveImage(url)` → 弹 SnackBar(成功/失败)。
- **视频**:点击缩略图 → push 新增的 `VideoPlayerView`(chewie);右上角三点 `PopupMenuButton`,菜单含"保存到相册"。点击 → 先把视频流落到 app 临时目录 → `MediaSaver.saveVideo(localPath)` → SnackBar。
- **PDF**:点击消息气泡 → push `PdfPreviewView` → 后台下载到 app 临时目录 → `flutter_pdfview` 嵌入预览(不离开 app)。预览页右上角三点 `PopupMenuButton`,菜单含:
  - **「用其他应用打开」** → `open_filex`,调起系统 PDF app(Books / Files / Drive / WPS 等)
  - **「分享 / 保存」** → `share_plus.shareXFiles([XFile(localPath)])`,弹系统分享面板;iOS 含"存储到文件"、Android 含"保存到设备 / Drive / 邮件"等,用户自选目的地

### MediaSaver 实现要点

- 用 `gal` 包(现代 Flutter 相册写入,iOS Photos 框架 + Android MediaStore,无需 SAF 流程)
- iOS:首次调用前 `gal.hasAccess(toAlbum: true)` → 没权限调 `requestAccess`;若被拒,UI 显示"去设置"按钮(`AppSettings.openAppSettings`)
- Android:`gal` 内部按 SDK 版本自动选择写入路径,无需手动判断
- 视频先下载到 `getTemporaryDirectory()` 再交给 `gal.putVideo(path)`(`gal` 接收本地路径不接收 URL)
- 图片可以直接 `gal.putImageBytes(bytes)` 或先下载再 `putImage`

### 安全与隐私

- 任务聊天的视频/图片走 `/api/private-file/{blob_id}?token=...` 签名访问,**下载也走同一路径**,token 仅会话双方持有
- 保存到相册后变成用户本地资产,平台无法控制其传播——这是平台一贯的尺度(图片已经能截屏,无本质差异),不视为新风险

## 8. 安全边界

- **服务端校验是唯一关卡**:客户端的大小/时长/类型校验只是 UX,后端独立校验,不信任 client meta
- **PDF magic byte**:必须以 `%PDF-`(`0x25 0x50 0x44 0x46 0x2D`)开头
- **视频 magic byte**:接受 mp4(`ftyp` box)/ mov;不接受其他容器格式
- **访问鉴权**:视频/PDF URL 走现有 `/api/private-file/{blob_id}` 签名 token 机制(同 PrivateImageSystem 模式),token 短时有效,只有会话双方能拿到
- **客户端缓存**:缩略图走 image 通道但需短期失效(避免 token 过期 → 显示但点开 404)
- **目录隔离**:`private_files/tasks/{task_id}/chat/` 子目录便于审计与未来分流(虽然底层 PrivateFileSystem 不变)

## 8.5 存储后端(本 spec 范围外)

本 spec 的视频/PDF 仍走现有 `PrivateFileSystem`(Railway Volume 本地磁盘),不改存储后端。

**已识别的后续优化方向**:迁移到 Cloudflare R2(0 出站带宽 + $0.015/GB-月存储,相比 Railway Volume $0.25/GB-月 + $0.10/GB 出站,粗算 ~20× 成本优势)。R2 是横向架构决策,影响所有附件场景(任务聊天 / 任务完成证据 / 服务图片等),需要独立 spec 处理:storage backend 抽象、presigned URL vs 后端代理选型、迁移灰度策略、孤儿清理、监控。

**这意味着**:本 spec 的目录结构 `private_files/tasks/{task_id}/chat/` 是物理路径,R2 迁移后会变成 object key。`PrivateFileSystem.storage.upload(content, path)` 抽象层已经存在,迁移时只需替换 storage 实现,业务层不感知。

## 9. 不做的事(YAGNI)

- ❌ 撤回 / 删除消息(与现有图片一致)
- ❌ 媒体消息内 caption 文本(后续单独发文字消息)
- ❌ 拍照按钮支持录像(只拍照片;要拍视频走系统相机再选)
- ❌ 后端转码 / 水印 / AI 内容审核
- ❌ 移动数据下二次确认(默认直接进全屏)
- ❌ 视频/PDF 单独限流桶(复用 upload_file)
- ❌ 单独 chat-media 上传端点(沿用 /api/upload/file)

## 10. 测试策略

| 层级 | 范围 | 工具 |
|---|---|---|
| Flutter BLoC | `ChatSendVideo` / `ChatSendFile` 的成功 / 失败 / 取消 / 离线路径 | `bloc_test` + `mocktail`,mock MessageRepository |
| Flutter Widget | VideoMessageBubble / FileMessageBubble 各状态渲染 | flutter_test(golden 可选) |
| Flutter MediaSaver | 权限通过 / 权限拒绝 / 保存失败 3 种路径 | flutter_test + mock gal |
| Backend unit | `validate_chat_video` / `validate_chat_pdf` 边界(最大尺寸、错 magic byte、错后缀、空文件) | pytest |
| Backend route | `/api/upload/file?usage=chat_media` 各 reject 路径 + 成功 + rate_limit | pytest + FastAPI TestClient |
| Backend integration | 发视频消息 → DB 落两条 attachment → fetch 消息 → 序列化包含 meta.role='thumbnail' | pytest |
| 手动 QA(必做) | linktest:iOS + Android 真机各跑发视频 / PDF / 超限 / 网络断 / 取消 | 手动 |

## 11. 上线步骤

1. 后端先合并 + 部署到 linktest:
   - `/api/upload/file?usage=chat_media` 新增 + 校验函数
   - `routers.py` attachment 解析扩展
   - cleanup 路径扩展
2. 前端 Flutter 改动合并(后端兼容向后,旧 client 不受影响)
3. linktest 真机 QA 通过 → 推 prod
4. 监控 prod 存储增长(`/api/v2/storage/categories`)与 rate_limit 命中率

## 12. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 视频压缩在低端 Android 慢 / OOM | video_compress 默认 isolate;在 UI 上明确"压缩中"状态;超时(60s)后中止 + 给出"换视频"提示 |
| 缩略图抽帧失败但视频上传成功 | 不阻断,客户端 fallback 纯黑播放图标 |
| 用户误传非 PDF(改扩展名) | magic byte 服务端拦截 |
| 存储成本上涨过快 | 跟随任务清理 + 监控 dashboard;若超预期可加单文件大小/单用户视频频率收紧 |
| 视频播放 codec 兼容性(HEVC) | video_compress 默认输出 H.264 baseline,跨平台兼容 |
| iOS 首次拒绝相册权限后无法弹二次系统弹窗 | UI 显示"去设置"按钮直接跳系统 App 设置页(`AppSettings.openAppSettings`) |
| Android 13+ 权限分裂(READ_MEDIA_IMAGES vs READ_MEDIA_VIDEO) | `gal` 包内部按 SDK 自动处理;manifest 同时声明两个 |
| flutter_pdfview 在大 PDF (>10MB) 或加密 PDF 上渲染慢 / 失败 | 加 loading 状态;失败时显示错误 + "用其他应用打开"按钮兜底;PDF 上限 20MB 在合理范围内 |
| 包体积上涨(`flutter_pdfview` ~5MB + `share_plus` ~0.5MB) | 单次扩容可接受;后续若加更多媒体类型再评估是否做 dynamic feature module |

