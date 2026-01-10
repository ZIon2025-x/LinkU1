# iOS 推送通知实现方案

## 概述
✅ **已完成** - 实现完整的 iOS 推送通知功能，包括设备 token 注册、推送通知发送、以及各种通知场景的集成。

## 实现状态

### 1. 数据库模型 ✅ 已完成
- ✅ 创建 `device_tokens` 表（迁移文件：045_add_device_tokens_table.sql）
- ✅ 在 `models.py` 中添加 `DeviceToken` 模型

### 2. 后端 API 端点 ✅ 已完成
- ✅ `/api/users/device-token` POST - 注册/更新设备 token
- ✅ `/api/users/device-token` DELETE - 注销设备 token

### 3. 推送通知服务 ✅ 已完成
- ✅ 创建 `push_notification_service.py`
- ✅ 集成 Apple Push Notification Service (APNs)
- ✅ 实现发送推送通知的函数
- ✅ 支持批量推送和多设备推送

### 4. 通知场景集成 ✅ 已完成
- ✅ 任务申请通知（`task_notifications.py`）
- ✅ 任务申请被接受通知（`task_notifications.py`）
- ✅ 任务申请被拒绝通知（`task_chat_routes.py`）
- ✅ 任务完成通知（`task_notifications.py`）
- ✅ 任务确认完成通知（`task_notifications.py`）
- ✅ 论坛帖子回复通知（`forum_routes.py`）
- ✅ 论坛评论回复通知（`forum_routes.py`）
- ✅ 申请留言回复通知（`task_chat_routes.py`）
- ✅ 私信通知（`main.py` WebSocket）

### 5. iOS 端完善 ✅ 已完成
- ✅ 请求推送通知权限（`link2urApp.swift`）
- ✅ 处理推送通知点击（`ContentView.swift`）
- ✅ 前台/后台通知处理（`AppDelegate`）
- ✅ 设备 token 自动注册（`link2urApp.swift` + `APIService.swift`）

### 6. 依赖和配置 ✅ 已完成
- ✅ 添加 `apns2>=0.7.0,<1.0.0` 到 `requirements.txt`
- ✅ 添加 APNs 环境变量配置到 `production.env.template`

## 技术细节

### APNs 配置
需要：
1. Apple Developer 账号
2. APNs 证书或密钥
3. 配置环境变量：
   - `APNS_KEY_ID` - APNs Key ID
   - `APNS_TEAM_ID` - Apple Team ID
   - `APNS_BUNDLE_ID` - App Bundle ID
   - `APNS_KEY_FILE` - APNs 密钥文件路径

### 推送通知格式
```json
{
  "aps": {
    "alert": {
      "title": "通知标题",
      "body": "通知内容"
    },
    "badge": 1,
    "sound": "default",
    "category": "TASK_NOTIFICATION"
  },
  "type": "task_application",
  "task_id": 123,
  "user_id": "14786828"
}
```

## 注意事项
1. 设备 token 需要定期更新
2. 处理 token 失效的情况
3. 支持多设备推送
4. 通知去重和合并
5. 隐私和权限管理
