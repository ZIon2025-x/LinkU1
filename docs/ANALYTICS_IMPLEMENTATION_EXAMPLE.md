# 第三方追踪实现示例

## 1. Firebase Analytics 集成示例

### iOS 实现

#### 步骤 1：安装 Firebase SDK

在 `Podfile` 中添加：
```ruby
pod 'Firebase/Analytics'
pod 'Firebase/Crashlytics'  # 可选：崩溃报告
```

#### 步骤 2：创建 Analytics 服务封装

```swift
// ios/link2ur/link2ur/Services/AnalyticsService.swift
import Foundation
import FirebaseAnalytics

/// 统一的追踪服务（支持 Firebase Analytics 和其他服务）
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private var isEnabled = true
    private var hasUserConsent = false
    
    private init() {
        // 从用户设置中读取是否同意追踪
        loadConsentStatus()
    }
    
    /// 设置用户同意状态
    func setUserConsent(_ granted: Bool) {
        hasUserConsent = granted
        UserDefaults.standard.set(granted, forKey: "analytics_consent")
        
        if !granted {
            // 用户拒绝追踪，停止收集数据
            Analytics.setAnalyticsCollectionEnabled(false)
        } else {
            Analytics.setAnalyticsCollectionEnabled(true)
        }
    }
    
    /// 加载用户同意状态
    private func loadConsentStatus() {
        hasUserConsent = UserDefaults.standard.bool(forKey: "analytics_consent")
        Analytics.setAnalyticsCollectionEnabled(hasUserConsent)
    }
    
    /// 追踪事件
    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isEnabled && hasUserConsent else { return }
        
        // Firebase Analytics
        Analytics.logEvent(name, parameters: parameters)
        
        // 同时记录到本地（用于调试）
        Logger.debug("📊 Analytics: \(name)", category: .analytics)
    }
    
    /// 追踪屏幕浏览
    func trackScreenView(_ screenName: String, parameters: [String: Any]? = nil) {
        guard isEnabled && hasUserConsent else { return }
        
        var params = parameters ?? [:]
        params[AnalyticsParameterScreenName] = screenName
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }
    
    /// 设置用户属性
    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled && hasUserConsent else { return }
        Analytics.setUserProperty(value, forName: name)
    }
    
    /// 设置用户ID（登录后）
    func setUserId(_ userId: String?) {
        guard isEnabled && hasUserConsent else { return }
        Analytics.setUserID(userId)
    }
    
    /// 追踪关键业务事件
    func trackTaskApplication(taskId: Int, taskCategory: String? = nil) {
        var params: [String: Any] = ["task_id": taskId]
        if let category = taskCategory {
            params["task_category"] = category
        }
        trackEvent("task_application", parameters: params)
    }
    
    func trackTaskCompletion(taskId: Int, reward: Double? = nil) {
        var params: [String: Any] = ["task_id": taskId]
        if let reward = reward {
            params["reward"] = reward
        }
        trackEvent("task_completed", parameters: params)
    }
    
    func trackPaymentCompleted(amount: Double, currency: String) {
        trackEvent("payment_completed", parameters: [
            "amount": amount,
            "currency": currency
        ])
    }
}
```

#### 步骤 3：在 AppDelegate 中初始化

```swift
// ios/link2ur/link2ur/link2urApp.swift
import FirebaseCore

@main
struct link2urApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // 初始化 Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 步骤 4：在关键位置使用

```swift
// 示例：在任务详情页
struct TaskDetailView: View {
    var body: some View {
        // ...
        .onAppear {
            // 追踪屏幕浏览
            AnalyticsService.shared.trackScreenView("task_detail", parameters: [
                "task_id": taskId
            ])
        }
    }
    
    func applyForTask() {
        // 业务逻辑...
        
        // 追踪事件
        AnalyticsService.shared.trackTaskApplication(
            taskId: taskId,
            taskCategory: task.category
        )
    }
}
```

### Web 实现

#### 步骤 1：安装依赖

```bash
npm install firebase
```

#### 步骤 2：创建 Analytics 服务

```typescript
// frontend/src/services/analytics.ts
import { initializeApp, FirebaseApp } from 'firebase/app';
import { getAnalytics, Analytics, logEvent, setUserId, setUserProperties } from 'firebase/analytics';

let analytics: Analytics | null = null;
let app: FirebaseApp | null = null;

// 初始化 Firebase
export function initAnalytics() {
  if (typeof window === 'undefined') return;
  
  const firebaseConfig = {
    apiKey: process.env.REACT_APP_FIREBASE_API_KEY,
    authDomain: process.env.REACT_APP_FIREBASE_AUTH_DOMAIN,
    projectId: process.env.REACT_APP_FIREBASE_PROJECT_ID,
    appId: process.env.REACT_APP_FIREBASE_APP_ID,
    measurementId: process.env.REACT_APP_FIREBASE_MEASUREMENT_ID,
  };

  app = initializeApp(firebaseConfig);
  analytics = getAnalytics(app);
}

// 追踪事件
export function trackEvent(eventName: string, parameters?: Record<string, any>) {
  if (!analytics) return;
  
  // 检查用户是否同意追踪
  const consent = localStorage.getItem('analytics_consent');
  if (consent !== 'true') return;
  
  logEvent(analytics, eventName, parameters);
}

// 追踪屏幕浏览
export function trackScreenView(screenName: string, parameters?: Record<string, any>) {
  trackEvent('screen_view', {
    screen_name: screenName,
    ...parameters,
  });
}

// 设置用户ID
export function setAnalyticsUserId(userId: string | null) {
  if (!analytics) return;
  setUserId(analytics, userId);
}

// 业务事件追踪
export const trackTaskApplication = (taskId: number, category?: string) => {
  trackEvent('task_application', {
    task_id: taskId,
    task_category: category,
  });
};

export const trackTaskCompletion = (taskId: number, reward?: number) => {
  trackEvent('task_completed', {
    task_id: taskId,
    reward: reward,
  });
};
```

#### 步骤 3：在应用入口初始化

```typescript
// frontend/src/App.tsx
import { useEffect } from 'react';
import { initAnalytics } from './services/analytics';

function App() {
  useEffect(() => {
    // 初始化 Analytics
    initAnalytics();
  }, []);
  
  // ...
}
```

## 2. Sentry 错误追踪集成示例

### iOS 实现

#### 步骤 1：安装 Sentry SDK

在 `Podfile` 中添加：
```ruby
pod 'Sentry'
```

#### 步骤 2：初始化 Sentry

```swift
// ios/link2ur/link2ur/link2urApp.swift
import Sentry

@main
struct link2urApp: App {
    init() {
        // 初始化 Sentry
        SentrySDK.start { options in
            options.dsn = "YOUR_SENTRY_DSN"
            options.debug = false // 生产环境设为 false
            options.environment = "production"
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### 步骤 3：在错误处理中使用

```swift
// 示例：在 API 错误处理中
func handleError(_ error: Error, context: String) {
    // 发送到 Sentry
    SentrySDK.capture(error: error) { scope in
        scope.setContext(value: ["context": context], key: "error_context")
        scope.setTag(value: "api_error", key: "error_type")
    }
    
    // 同时记录到本地日志
    Logger.error("API Error: \(error.localizedDescription)", category: .api)
}
```

### Web 实现

#### 步骤 1：安装依赖

```bash
npm install @sentry/react @sentry/tracing
```

#### 步骤 2：初始化 Sentry

```typescript
// frontend/src/services/sentry.ts
import * as Sentry from "@sentry/react";
import { BrowserTracing } from "@sentry/tracing";

export function initSentry() {
  Sentry.init({
    dsn: process.env.REACT_APP_SENTRY_DSN,
    environment: process.env.NODE_ENV,
    integrations: [
      new BrowserTracing(),
    ],
    tracesSampleRate: 1.0, // 生产环境建议设为 0.1
    beforeSend(event, hint) {
      // 可以在这里过滤敏感信息
      return event;
    },
  });
}

// 捕获错误
export function captureError(error: Error, context?: Record<string, any>) {
  Sentry.captureException(error, {
    extra: context,
  });
}
```

#### 步骤 3：在错误处理中使用

```typescript
// frontend/src/utils/errorHandler.ts
import { captureError } from '../services/sentry';

export function handleError(error: Error, context?: string) {
  // 发送到 Sentry
  captureError(error, { context });
  
  // 显示用户友好的错误消息
  // ...
}
```

### 后端实现

#### 步骤 1：安装依赖

```bash
pip install sentry-sdk[fastapi]
```

#### 步骤 2：初始化 Sentry

```python
# backend/app/main.py
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

# 在应用启动时初始化
sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    integrations=[
        FastApiIntegration(),
        SqlalchemyIntegration(),
    ],
    traces_sample_rate=1.0,  # 生产环境建议设为 0.1
    environment=os.getenv("ENVIRONMENT", "development"),
    before_send=lambda event, hint: event,  # 可以过滤敏感信息
)
```

## 3. 统一追踪接口（推荐）

创建一个统一的追踪接口，可以同时支持多个追踪服务：

```swift
// iOS - 统一追踪接口
protocol AnalyticsProvider {
    func trackEvent(_ name: String, parameters: [String: Any]?)
    func trackScreenView(_ screenName: String, parameters: [String: Any]?)
    func setUserId(_ userId: String?)
}

class UnifiedAnalytics {
    private var providers: [AnalyticsProvider] = []
    
    func addProvider(_ provider: AnalyticsProvider) {
        providers.append(provider)
    }
    
    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        providers.forEach { $0.trackEvent(name, parameters: parameters) }
    }
    
    func trackScreenView(_ screenName: String, parameters: [String: Any]? = nil) {
        providers.forEach { $0.trackScreenView(screenName, parameters: parameters) }
    }
}
```

## 4. 环境变量配置

### iOS (.xcconfig)

```xcconfig
// Config.xcconfig
FIREBASE_API_KEY = YOUR_API_KEY
FIREBASE_PROJECT_ID = YOUR_PROJECT_ID
SENTRY_DSN = YOUR_SENTRY_DSN
```

### Web (.env)

```env
REACT_APP_FIREBASE_API_KEY=your_api_key
REACT_APP_FIREBASE_PROJECT_ID=your_project_id
REACT_APP_SENTRY_DSN=your_sentry_dsn
```

### Backend (.env)

```env
SENTRY_DSN=your_sentry_dsn
ENVIRONMENT=production
```

## 5. 关键事件追踪清单

### 必须追踪的事件

1. **用户生命周期**
   - 用户注册
   - 用户登录
   - 用户注销

2. **核心业务**
   - 任务浏览
   - 任务申请
   - 任务完成
   - 任务取消
   - 支付完成

3. **功能使用**
   - 搜索执行
   - 筛选应用
   - 消息发送

4. **错误和性能**
   - API 错误
   - 页面加载时间
   - 崩溃事件

## 6. 隐私合规实现

```swift
// iOS - 用户同意管理
class ConsentManager {
    static let shared = ConsentManager()
    
    func requestConsent(completion: @escaping (Bool) -> Void) {
        // 显示同意对话框
        // 用户选择后调用 completion
    }
    
    func hasConsent() -> Bool {
        return UserDefaults.standard.bool(forKey: "analytics_consent")
    }
}
```

## 总结

通过集成第三方追踪工具，你可以：
- 📊 深入了解用户行为
- 🐛 快速发现和修复错误
- 📈 优化产品功能和用户体验
- 🎯 基于数据做决策

**建议实施顺序**：
1. 先集成 Sentry（错误追踪）- 最重要
2. 再集成 Firebase Analytics（基础分析）
3. 最后根据需要添加其他工具
