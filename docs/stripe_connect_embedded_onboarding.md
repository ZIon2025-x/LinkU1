# Stripe Connect 嵌入式 Onboarding 实现指南

## 概述

Stripe Connect 支持两种 onboarding 方式：
1. **AccountLink（跳转方式）**：用户跳转到 Stripe 页面完成 onboarding
2. **AccountSession（嵌入式）**：在自己的页面中嵌入 Stripe onboarding 表单

本文档介绍如何在 Web 和 iOS 应用中实现嵌入式 onboarding。

## 后端 API

### 1. 创建账户（嵌入式方式）

```http
POST /api/stripe/connect/account/create-embedded
```

**响应**：
```json
{
  "account_id": "acct_xxxxx",
  "client_secret": "acs_client_secret_xxxxx",
  "account_status": false,
  "charges_enabled": false,
  "message": "账户创建成功，请完成账户设置"
}
```

### 2. 创建 Onboarding Session

```http
POST /api/stripe/connect/account/onboarding-session
```

**响应**：
```json
{
  "account_id": "acct_xxxxx",
  "client_secret": "acs_client_secret_xxxxx",
  "account_status": false,
  "charges_enabled": false,
  "message": "请完成账户设置"
}
```

## Web 前端实现

### 1. 安装依赖

```bash
npm install @stripe/stripe-js @stripe/connect-embedded
```

### 2. React 组件示例

```tsx
import { useEffect, useState } from 'react';
import { loadStripe } from '@stripe/stripe-js';
import { ConnectEmbedded } from '@stripe/connect-embedded';

const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY;

function StripeConnectOnboarding() {
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [stripe, setStripe] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 初始化 Stripe
    loadStripe(STRIPE_PUBLISHABLE_KEY!).then(setStripe);
    
    // 获取 onboarding session
    fetch('/api/stripe/connect/account/create-embedded', {
      method: 'POST',
      credentials: 'include',
    })
      .then(res => res.json())
      .then(data => {
        if (data.client_secret) {
          setClientSecret(data.client_secret);
        } else if (data.account_status && data.charges_enabled) {
          // 账户已完成设置
          setError(null);
        } else {
          setError('无法创建 onboarding session');
        }
        setLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const handleOnboardingComplete = () => {
    // 检查账户状态
    fetch('/api/stripe/connect/account/status', {
      credentials: 'include',
    })
      .then(res => res.json())
      .then(data => {
        if (data.charges_enabled) {
          // 账户已启用，可以接收付款
          alert('账户设置完成！');
          window.location.reload();
        } else {
          alert('账户设置中，请稍候...');
        }
      });
  };

  if (loading) {
    return <div>加载中...</div>;
  }

  if (error) {
    return <div>错误: {error}</div>;
  }

  if (!clientSecret) {
    return <div>账户已完成设置</div>;
  }

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto' }}>
      <h2>设置收款账户</h2>
      <p>请完成以下信息以接收任务奖励</p>
      {stripe && clientSecret && (
        <ConnectEmbedded
          stripe={stripe}
          clientSecret={clientSecret}
          onReady={() => console.log('Onboarding ready')}
          onComplete={handleOnboardingComplete}
          onError={(error) => {
            console.error('Onboarding error:', error);
            setError(error.message);
          }}
        />
      )}
    </div>
  );
}

export default StripeConnectOnboarding;
```

### 3. 使用 Connect Embedded Components

```tsx
import { ConnectEmbedded } from '@stripe/connect-embedded';

// 在组件中使用
<ConnectEmbedded
  stripe={stripe}
  clientSecret={clientSecret}
  onComplete={() => {
    // 处理完成事件
    console.log('Onboarding completed');
  }}
/>
```

## iOS 实现

### 1. 使用 WKWebView 加载嵌入式页面

```swift
import SwiftUI
import WebKit
import StripeConnect

struct StripeConnectOnboardingView: View {
    @State private var clientSecret: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("加载中...")
            } else if let error = errorMessage {
                Text("错误: \(error)")
            } else if let secret = clientSecret {
                StripeConnectWebView(clientSecret: secret)
            } else {
                Text("账户已完成设置")
            }
        }
        .onAppear {
            loadOnboardingSession()
        }
    }
    
    func loadOnboardingSession() {
        // 调用后端 API 获取 client_secret
        guard let url = URL(string: "\(API_BASE_URL)/api/stripe/connect/account/create-embedded") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 添加认证 token
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONDecoder().decode(OnboardingResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.clientSecret = json.client_secret
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法加载 onboarding session"
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

struct StripeConnectWebView: UIViewRepresentable {
    let clientSecret: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // 构建嵌入式的 onboarding URL
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://js.stripe.com/v3/"></script>
            <script src="https://js.stripe.com/connect-embedded/v1/"></script>
        </head>
        <body>
            <div id="connect-embedded"></div>
            <script>
                const stripe = Stripe('\(STRIPE_PUBLISHABLE_KEY)');
                const connectEmbedded = new ConnectEmbedded({
                    clientSecret: '\(clientSecret)',
                    onComplete: function() {
                        window.webkit.messageHandlers.onboardingComplete.postMessage('completed');
                    }
                });
                connectEmbedded.mount('#connect-embedded');
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 处理导航
            decisionHandler(.allow)
        }
    }
}
```

### 2. 使用 Stripe iOS SDK（推荐）

如果 Stripe iOS SDK 支持 Connect Embedded，可以使用原生组件：

```swift
import StripeConnect

class StripeConnectOnboardingViewController: UIViewController {
    var clientSecret: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadOnboardingSession { [weak self] secret in
            guard let self = self, let secret = secret else { return }
            
            // 使用 Stripe Connect SDK
            let onboardingController = STPConnectAccountOnboardingViewController(
                clientSecret: secret,
                delegate: self
            )
            
            self.present(onboardingController, animated: true)
        }
    }
    
    func loadOnboardingSession(completion: @escaping (String?) -> Void) {
        // 调用后端 API
        // ...
    }
}

extension StripeConnectOnboardingViewController: STPConnectAccountOnboardingDelegate {
    func connectAccountOnboarding(_ controller: STPConnectAccountOnboardingViewController, didCompleteWith account: STPConnectAccount) {
        // 处理完成
        dismiss(animated: true)
    }
    
    func connectAccountOnboarding(_ controller: STPConnectAccountOnboardingViewController, didFailWith error: Error) {
        // 处理错误
        print("Error: \(error)")
    }
}
```

## 流程说明

1. **用户申请任务或需要收款时**：
   - 检查是否有 Stripe Connect 账户
   - 如果没有，引导用户创建账户

2. **创建账户**：
   - 调用 `POST /api/stripe/connect/account/create-embedded`
   - 获取 `client_secret`

3. **显示 Onboarding 表单**：
   - Web: 使用 `@stripe/connect-embedded` 组件
   - iOS: 使用 WKWebView 或 Stripe SDK

4. **完成 Onboarding**：
   - 用户填写信息（银行账户、身份验证等）
   - Stripe 自动验证
   - 触发 `onComplete` 事件

5. **验证账户状态**：
   - 调用 `GET /api/stripe/connect/account/status`
   - 检查 `charges_enabled` 是否为 `true`

## 注意事项

1. **安全性**：
   - `client_secret` 应该从后端获取，不要硬编码在前端
   - 使用 HTTPS 传输

2. **错误处理**：
   - 处理网络错误
   - 处理 Stripe API 错误
   - 提供友好的错误提示

3. **用户体验**：
   - 显示加载状态
   - 提供清晰的步骤说明
   - 完成后自动刷新账户状态

4. **测试**：
   - 使用 Stripe 测试模式
   - 测试各种错误场景
   - 验证账户状态更新

## 参考文档

- [Stripe Connect Embedded Components](https://stripe.com/docs/connect/embedded-components)
- [Stripe Connect AccountSession API](https://stripe.com/docs/api/account_sessions)
- [Stripe iOS SDK](https://stripe.dev/stripe-ios/)

