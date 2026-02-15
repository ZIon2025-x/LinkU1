# 提交 17df22a 变更分析

## 有效代码更新（需保留）

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| **uk_cities.dart** | 新增 | 新文件，但 zhName 中文为乱码需修复 |
| **deep_link_handler.dart** | 逻辑 | profileSubRoute、leaderboardItem 路由，_buildAppPath，path 分支逻辑 |
| **error_localizer.dart** | 功能 | 新增 auth/search/flea_market/customer_service 错误码映射 |
| **offline_manager.dart** | 重构 | _dataPath 用 `??=` 简化 |
| **offline_storage_stub.dart** | 语法 | 添加 `library;` |
| **discovery_repository.dart** | 类型 | DiscoveryException 类，throw DiscoveryException |
| **flea_market_repository.dart** | 优化 | const FleaMarketException、const cacheKey |
| **payment_repository.dart** | 健壮性 | checkout_url/onboarding url 空值检查与抛错 |
| **api_service.dart** | 功能 | 传递 cancelToken |
| **secure_storage_web.dart** | 迁移 | dart:html → package:web |
| **storage_service.dart** | 健壮性 | JSON 解析 try-catch 防崩溃；clearAccount 重置 notification/sound |
| **websocket_service.dart** | 健壮性 | isClosed 检查；dispose 完善（取消订阅、关闭 channel） |
| **auth_bloc.dart** | 架构 | 硬编码中文 → error code（配合 ErrorLocalizer） |
| **forgot_password_view.dart** | 架构 | 使用 ErrorLocalizer.localize |
| **login_view.dart** | 架构 | 使用 ErrorLocalizer.localize |
| **register_view.dart** | 架构 | ErrorLocalizer + 密码强度用 l10n |

## 仅注释/编码损坏（应还原为 parent 的注释）

| 文件 | 问题 |
|------|------|
| **payment_view.dart** | BOM 添加；所有中文注释乱码 |
| **chat_bloc.dart** | BOM 导致 `锘縤mport` 破坏 import；中文注释改坏 |
| **deep_link_handler.dart** | 一处中文注释乱码 |
| **error_localizer.dart** | 一处中文注释乱码 |
| **storage_service.dart** | 注释乱码 |
| **websocket_service.dart** | 注释乱码 |

## 修复策略

1. **payment_view.dart**：从 parent  checkout 恢复，再仅重新应用该文件内的 const Icon 等代码改动（当前 diff 中未见 const Icon，主要是 BOM 和注释损坏）
2. **chat_bloc.dart**：去掉 BOM，恢复正确 import；注释保留 parent 版本或修复为正确中文
3. 其他文件：保留所有有效代码更新，仅修复乱码注释
