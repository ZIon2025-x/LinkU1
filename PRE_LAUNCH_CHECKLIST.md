# 应用上线前检查清单

**最后更新**: 2025年1月27日

本文档列出了应用上线前需要完成的所有关键任务。

---

## 🔴 高优先级（上线前必须完成）

### 1. iOS App Store 提交准备

#### 1.1 开发者账号和证书
- [ ] **Apple Developer Program 会员资格** ($99/年)
  - 注册地址: https://developer.apple.com/programs/
  - 需要提供: 身份证明、支付信息、D-U-N-S 编号（组织账号）
  
- [ ] **开发团队配置**
  - [ ] 在 Xcode 中配置开发团队
  - [ ] 确认 Bundle Identifier: `com.link2ur.ios`
  - [ ] 配置自动签名或手动证书管理
  
- [ ] **证书和配置文件**
  - [ ] 生产环境证书（Distribution Certificate）
  - [ ] App Store 分发配置文件（Provisioning Profile）
  - [ ] 推送通知证书（APNs）
  - [ ] Apple Pay 证书（已配置：`merchant.com.link2ur`）

#### 1.2 App Store Connect 配置
- [ ] **创建 App 记录**
  - [ ] 登录 App Store Connect
  - [ ] 创建新 App
  - [ ] 填写基本信息（名称、Bundle ID、SKU）
  
- [ ] **应用信息**
  - [ ] 应用名称（最多 30 个字符）
  - [ ] 副标题（最多 30 个字符，可选）
  - [ ] 类别：商务、社交网络、生活
  - [ ] 内容版权：© 2025 Link²Ur
  - [ ] 年龄分级：完成内容问卷
  
- [ ] **应用材料**
  - [ ] 应用图标（1024 x 1024 像素）
  - [ ] 截图（至少 3 张，不同设备尺寸）
  - [ ] 应用描述（简短和完整描述）
  - [ ] **关键词（最多 100 个字符）** ⚠️ **重要：必须包含 "link2ur"**
    - 推荐：`link2ur,link to you,link2u,学生,任务,服务,跳蚤市场,论坛,社区,本地服务,兼职,二手,交易`
    - 详见：`ios/APP_STORE_SEARCH_OPTIMIZATION.md`
  
- [ ] **隐私信息**
  - [ ] 填写数据收集类型
  - [ ] 填写数据使用目的
  - [ ] 填写数据共享情况
  - [ ] 填写追踪设置（否）
  - [ ] 提供隐私政策 URL: https://www.link2ur.com/privacy

#### 1.3 Xcode 配置检查
- [ ] **Info.plist 配置**
  - [ ] 应用名称：Link²Ur
  - [ ] 权限描述（相机、位置等）
  - [ ] 支持的最低 iOS 版本：iOS 16.0
  - [ ] 支持的设备方向
  
- [ ] **Entitlements 配置**
  - [ ] Apple Pay（merchant.com.link2ur）✅
  - [ ] Push Notifications（如需要）
  - [ ] Associated Domains（如需要）
  
- [ ] **环境变量配置**
  - [ ] 确认生产环境 API 地址
  - [ ] 确认 WebSocket 地址
  - [ ] 确认 Stripe 密钥（生产环境）
  - [ ] 移除所有测试/调试代码

#### 1.4 代码清理
- [ ] 移除所有 `print()` 调试语句
- [ ] 移除所有 `NSLog()` 调试语句
- [ ] 移除所有测试数据
- [ ] 移除或标记所有 TODO/FIXME 注释
- [ ] 确认所有错误处理已实现
- [ ] 确认所有网络请求都有错误处理

---

### 2. 生产环境配置检查

#### 2.1 后端环境变量
参考 `backend/production.env.template`，确认以下配置：

- [ ] **基础配置**
  - [ ] `ENVIRONMENT=production`
  - [ ] `DEBUG=false`
  - [ ] `BASE_URL`（生产环境 URL）
  - [ ] `FRONTEND_URL`（前端 URL）
  
- [ ] **数据库配置**
  - [ ] `DATABASE_URL`（生产数据库）
  - [ ] `REDIS_URL`（生产 Redis）
  - [ ] `USE_REDIS=true`
  
- [ ] **安全配置**
  - [ ] `SECRET_KEY`（强随机密钥）
  - [ ] `COOKIE_SECURE=true`
  - [ ] `COOKIE_HTTPONLY=true`
  - [ ] `COOKIE_SAMESITE=strict`
  
- [ ] **Stripe 配置**
  - [ ] `STRIPE_SECRET_KEY`（生产密钥 `sk_live_...`）
  - [ ] `STRIPE_PUBLISHABLE_KEY`（生产密钥 `pk_live_...`）
  - [ ] `STRIPE_WEBHOOK_SECRET`（生产 Webhook 密钥）
  
- [ ] **邮件配置**
  - [ ] `SENDGRID_API_KEY`（或 SMTP 配置）
  - [ ] `USE_SENDGRID=true`
  - [ ] `EMAIL_FROM`（发件人邮箱）
  
- [ ] **iOS 推送通知（APNs）**
  - [ ] `APNS_KEY_ID`（10位字符）
  - [ ] `APNS_TEAM_ID`（Apple Team ID）
  - [ ] `APNS_BUNDLE_ID=com.link2ur.app`
  - [ ] `APNS_KEY_CONTENT`（Base64 编码的 .p8 文件内容）
  - [ ] `APNS_USE_SANDBOX=false`（生产环境）
  
- [ ] **翻译服务**
  - [ ] `GOOGLE_CLOUD_TRANSLATE_API_KEY`（或服务账号配置）
  - [ ] `TRANSLATION_SERVICES=google_cloud,google,mymemory`

#### 2.2 前端环境变量
- [ ] **API 配置**
  - [ ] `REACT_APP_API_URL`（生产 API 地址）
  - [ ] `REACT_APP_WS_URL`（生产 WebSocket 地址）
  
- [ ] **Stripe 配置**
  - [ ] `REACT_APP_STRIPE_PUBLISHABLE_KEY`（生产密钥 `pk_live_...`）

#### 2.3 iOS 配置
- [ ] **API 地址**
  - [ ] 确认 `Configuration.swift` 中生产环境 API 地址正确
  - [ ] 确认 WebSocket 地址正确
  
- [ ] **Stripe 配置**
  - [ ] 确认生产环境 Stripe Publishable Key
  - [ ] 确认 Apple Pay Merchant ID: `merchant.com.link2ur`

---

### 3. 安全审计最终确认

#### 3.1 支付安全
根据 `PAYMENT_BYPASS_SECURITY_AUDIT.md`，所有关键漏洞已修复 ✅：
- [x] `/tasks/{task_id}/approve` 端点 - 已添加支付验证
- [x] `/tasks/{task_id}/confirm_completion` - 已加强状态检查
- [x] `/tasks/{task_id}/complete` - 已添加支付验证
- [x] `accept_application` - 已保护
- [x] `direct_purchase_item` - 已修复
- [x] `accept_purchase_request` - 已修复
- [x] `respond_negotiation` - 已修复
- [x] `approve_service_application` - 已修复

**需要验证**：
- [ ] 在生产环境测试所有支付流程
- [ ] 验证无法绕过支付验证
- [ ] 验证 Webhook 正确处理支付事件

#### 3.2 数据安全
- [ ] 所有网络请求使用 HTTPS
- [ ] 敏感数据存储在 Keychain（iOS）
- [ ] 实现适当的身份验证
- [ ] 实现数据加密

#### 3.3 权限请求
- [ ] 位置权限（可选，有说明）
- [ ] 相机权限（有说明）
- [ ] 通知权限（有说明）
- [ ] 确保所有权限请求都有说明

---

### 4. 完整功能测试

#### 4.1 核心功能测试
- [ ] **用户认证**
  - [ ] 用户注册
  - [ ] 邮箱验证
  - [ ] 用户登录
  - [ ] 密码重置
  - [ ] 学生身份验证
  
- [ ] **任务功能**
  - [ ] 发布任务
  - [ ] 浏览任务
  - [ ] 接受任务申请
  - [ ] 批准申请（创建支付）
  - [ ] 支付任务
  - [ ] 完成任务
  - [ ] 确认完成
  - [ ] 任务取消
  
- [ ] **支付功能**
  - [ ] Stripe 支付
  - [ ] 积分支付
  - [ ] 混合支付
  - [ ] 优惠券使用
  - [ ] Apple Pay（iOS）
  - [ ] 支付成功/失败处理
  
- [ ] **跳蚤市场**
  - [ ] 发布商品
  - [ ] 浏览商品
  - [ ] 购买商品
  - [ ] 议价功能
  
- [ ] **论坛功能**
  - [ ] 发帖
  - [ ] 回帖
  - [ ] 点赞
  - [ ] 收藏
  
- [ ] **消息系统**
  - [ ] 发送消息
  - [ ] 接收消息
  - [ ] 实时消息推送
  - [ ] 图片消息
  
- [ ] **个人中心**
  - [ ] 查看个人资料
  - [ ] 编辑个人资料
  - [ ] 查看任务历史
  - [ ] 查看钱包
  - [ ] 查看积分
  - [ ] 设置偏好

#### 4.2 边界情况测试
- [ ] 网络断开时的处理
- [ ] 服务器错误时的处理
- [ ] 无效输入的处理
- [ ] 内存不足时的处理
- [ ] 应用后台恢复
- [ ] 支付超时处理
- [ ] 支付取消处理

#### 4.3 多语言测试
- [ ] 英语界面
- [ ] 中文界面
- [ ] 语言切换功能
- [ ] 翻译准确性

#### 4.4 设备兼容性测试
- [ ] iPhone（不同尺寸）
- [ ] iPad（如支持）
- [ ] 不同 iOS 版本（iOS 16.0+）
- [ ] Web 浏览器（Chrome、Safari、Firefox）

---

### 5. 性能测试

- [ ] **响应时间**
  - [ ] API 响应时间 < 500ms（平均）
  - [ ] 页面加载时间 < 3s
  - [ ] 图片加载优化
  
- [ ] **并发测试**
  - [ ] 支持 100+ 并发用户
  - [ ] 数据库连接池配置正确
  - [ ] Redis 缓存正常工作
  
- [ ] **资源使用**
  - [ ] 内存使用合理
  - [ ] CPU 使用合理
  - [ ] 电池使用合理（iOS）

---

### 6. 监控和日志配置

#### 6.1 日志系统
- [ ] 生产环境日志级别设置为 `INFO`
- [ ] 错误日志正确记录
- [ ] 敏感信息不记录到日志
- [ ] 日志轮转配置正确

#### 6.2 监控系统
- [ ] 服务器监控（CPU、内存、磁盘）
- [ ] 数据库监控
- [ ] Redis 监控
- [ ] API 响应时间监控
- [ ] 错误率监控
- [ ] 支付成功率监控

#### 6.3 告警配置
- [ ] 服务器宕机告警
- [ ] 数据库连接失败告警
- [ ] 高错误率告警
- [ ] 支付失败率告警

---

## 🟡 中优先级（建议上线前完成）

### 7. TestFlight 测试

- [ ] **上传构建版本**
  - [ ] 在 Xcode 中构建 Archive
  - [ ] 上传到 App Store Connect
  - [ ] 处理构建版本
  
- [ ] **内部测试**
  - [ ] 邀请内部测试员（最多 100 人）
  - [ ] 收集反馈
  - [ ] 修复问题
  
- [ ] **Beta 测试**（可选）
  - [ ] 进行 Beta 测试（最多 10,000 人）
  - [ ] 收集反馈

---

### 8. 文档准备

- [ ] **用户文档**
  - [ ] 用户指南
  - [ ] 常见问题（FAQ）
  - [ ] 支持联系方式
  
- [ ] **开发者文档**
  - [ ] API 文档
  - [ ] 部署文档
  - [ ] 配置文档

---

### 9. 法律合规

- [x] **服务条款** ✅
  - [x] 已完善，包含论坛和跳蚤市场条款
  - [x] 符合英国法律（英格兰与威尔士）
  
- [x] **隐私政策** ✅
  - [x] 已完善，符合 UK GDPR
  - [x] 包含详细的数据收集和使用说明
  
- [x] **Cookie 政策** ✅
  - [x] 已创建独立页面
  - [x] 符合 PECR

- [ ] **App Store 隐私信息**
  - [ ] 在 App Store Connect 中填写隐私实践
  - [ ] 说明收集的数据类型
  - [ ] 说明数据使用目的
  - [ ] 说明数据共享情况

---

## 🟢 低优先级（可以上线后优化）

### 10. 营销材料

- [ ] 应用预览视频（可选）
- [ ] 营销网站优化
- [ ] 社交媒体账号
- [ ] 新闻稿（可选）

---

### 11. 性能优化

- [ ] 前端代码分割优化
- [ ] 图片懒加载优化
- [ ] API 响应缓存优化
- [ ] 数据库查询优化

---

## 📊 总体进度

### 已完成 ✅
- ✅ 支付安全漏洞修复
- ✅ `pending_payment` 状态处理完善
- ✅ 前端支付流程完整
- ✅ iOS 支付集成
- ✅ 法律文档准备
- ✅ 基础功能实现

### 进行中 🔄
- 🔄 iOS App Store 提交准备
- 🔄 生产环境配置
- 🔄 完整功能测试

### 待完成 ⏳
- ⏳ App Store Connect 配置
- ⏳ TestFlight 测试
- ⏳ 监控和日志配置
- ⏳ 性能测试

---

## 🎯 上线时间线建议

### 第 1 周：准备阶段
- 完成开发者账号注册
- 完成生产环境配置
- 完成代码清理

### 第 2 周：测试阶段
- 完成功能测试
- 完成性能测试
- 修复发现的问题

### 第 3 周：提交阶段
- 上传到 TestFlight
- 进行 Beta 测试
- 准备 App Store 材料

### 第 4 周：审核阶段
- 提交到 App Store
- 等待审核
- 准备发布

---

## 📝 检查清单总结

**高优先级（必须完成）**：
- [ ] iOS App Store 提交准备
- [ ] 生产环境配置检查
- [ ] 安全审计最终确认
- [ ] 完整功能测试
- [ ] 性能测试
- [ ] 监控和日志配置

**中优先级（建议完成）**：
- [ ] TestFlight 测试
- [ ] 文档准备
- [ ] 法律合规（App Store 隐私信息）

**低优先级（可以上线后优化）**：
- [ ] 营销材料
- [ ] 性能优化

---

## 📞 支持资源

- **Apple 官方资源**:
  - [App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
  - [App Store Connect 帮助](https://help.apple.com/app-store-connect/)
  - [TestFlight 测试指南](https://developer.apple.com/testflight/)

- **项目文档**:
  - `ios/APP_STORE_SUBMISSION_CHECKLIST.md` - App Store 提交详细清单
  - `PAYMENT_BYPASS_SECURITY_AUDIT.md` - 支付安全审计
  - `PENDING_PAYMENT_STATUS_AUDIT.md` - 支付状态审计
  - `FRONTEND_PENDING_PAYMENT_AUDIT.md` - 前端支付审计

---

**最后更新**: 2025年1月27日
