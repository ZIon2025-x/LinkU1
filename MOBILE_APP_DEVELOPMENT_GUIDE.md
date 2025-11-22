# Link²Ur 移动应用开发指南 - 原生开发方案

> **文档创建时间**: 2025-01-20  
> **适用平台**: iOS & Android  
> **技术栈**: iOS (Swift + SwiftUI) / Android (Kotlin + Jetpack Compose)

## 📖 文档导航

**快速开始**：
- 方案选择 → 第2节（原生开发优势分析）
- iOS开发 → 第3节（Swift + SwiftUI开发指南）
- Android开发 → 第4节（Kotlin + Jetpack Compose开发指南）
- 共享代码 → 第5节（API集成、数据模型等）

**开发流程**：
- iOS环境搭建 → 第3.1节
- Android环境搭建 → 第4.1节
- 项目架构设计 → 第3.2节 / 第4.2节
- API集成 → 第5节（后端API对接）
- 原生功能 → 第3.4节 / 第4.4节（推送通知、相机、定位等）
- 测试部署 → 第7节（测试和发布流程）

## 📋 目录

1. [概述](#1-概述)
2. [方案选择](#2-方案选择)
3. [iOS 原生开发方案](#3-ios-原生开发方案) 🍎
4. [Android 原生开发方案](#4-android-原生开发方案) 🤖
5. [共享代码与API集成](#5-共享代码与api集成)
6. [架构设计](#6-架构设计)
7. [测试与部署](#7-测试与部署)
8. [性能优化](#8-性能优化)
9. [常见问题](#9-常见问题)

---

## 1. 概述

### 1.1 项目现状

**当前技术栈**：
- **前端**: React 18 + TypeScript + Ant Design
- **后端**: FastAPI (Python) + PostgreSQL + Redis
- **部署**: Railway (后端) + Vercel (前端)

**主要功能模块**：
- ✅ 任务发布与浏览
- ✅ 跳蚤市场（二手交易）
- ✅ 消息系统（WebSocket实时通信）
- ✅ 用户资料与认证
- ✅ 钱包与VIP系统
- ✅ 任务专家系统
- ✅ 客服系统
- ✅ 多语言支持（中英文）

### 1.2 移动化目标

**核心目标**：
1. 提供最佳原生移动应用体验
2. 充分利用平台特性（iOS/Android）
3. 复用现有后端API
4. 保持功能一致性
5. 优化移动端用户体验和性能

**关键功能需求**：
- 📱 推送通知（任务更新、消息提醒）
- 📷 相机集成（图片上传）
- 📍 定位服务（城市选择、任务位置）
- 💳 支付集成（钱包功能）
- 🔔 后台消息接收
- 🎨 原生UI/UX体验

---

## 2. 方案选择

### 2.1 原生开发 vs 跨平台开发

| 特性 | 原生开发 | React Native | Flutter | PWA |
|------|---------|-------------|---------|-----|
| **性能** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **用户体验** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **平台特性支持** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **开发成本** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **维护成本** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **代码复用** | ⭐ (0%) | ⭐⭐⭐⭐⭐ (80-90%) | ⭐⭐⭐ (30-40%) | ⭐⭐⭐⭐⭐ (95%+) |
| **学习曲线** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### 2.2 选择原生开发的理由

**优势**：
1. ✅ **最佳性能**：直接使用系统API，无中间层损耗
2. ✅ **完整平台支持**：100%支持iOS/Android最新特性
3. ✅ **原生用户体验**：符合平台设计规范，用户熟悉
4. ✅ **更好的安全性**：直接使用平台安全机制
5. ✅ **长期维护性**：不依赖第三方框架生命周期
6. ✅ **更好的调试工具**：Xcode、Android Studio专业工具

**适用场景**：
- 追求最佳性能和用户体验
- 需要充分利用平台特性
- 有专门的iOS和Android开发团队
- 长期维护的项目
- 对应用大小和启动速度有严格要求

### 2.3 技术栈选择

**iOS开发**：
- **语言**: Swift 5.9+
- **UI框架**: SwiftUI (推荐) 或 UIKit
- **架构**: MVVM + Combine
- **网络**: URLSession + Codable
- **数据持久化**: Core Data 或 SwiftData
- **依赖管理**: Swift Package Manager

**Android开发**：
- **语言**: Kotlin 1.9+
- **UI框架**: Jetpack Compose (推荐) 或 View System
- **架构**: MVVM + Kotlin Coroutines + Flow
- **网络**: Retrofit + OkHttp
- **数据持久化**: Room Database
- **依赖管理**: Gradle + Kotlin DSL

---

## 3. iOS 原生开发方案 🍎

### 3.1 环境搭建

#### 3.1.1 系统要求

**必需**：
- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本
- CocoaPods (可选，用于第三方库管理)

#### 3.1.2 安装步骤

```bash
# 1. 安装Xcode (从App Store)
# 2. 安装命令行工具
xcode-select --install

# 3. 安装CocoaPods (可选)
sudo gem install cocoapods

# 4. 创建新项目
# 在Xcode中: File > New > Project > iOS > App
# 或使用命令行:
mkdir LinkU-iOS && cd LinkU-iOS
swift package init --type executable
```

#### 3.1.3 项目配置

**Info.plist配置**：
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>我们需要您的位置信息以提供附近的任务和跳蚤市场商品</string>
<key>NSCameraUsageDescription</key>
<string>我们需要访问相机以拍摄任务或商品图片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>我们需要访问相册以选择图片</string>
<key>NSUserNotificationsUsageDescription</key>
<string>我们需要发送通知以提醒您任务更新和消息</string>
```

### 3.2 项目结构

```
LinkU-iOS/
├── LinkU/
│   ├── App/
│   │   ├── LinkUApp.swift          # 应用入口
│   │   └── ContentView.swift       # 主视图
│   ├── Models/                     # 数据模型
│   │   ├── Task.swift
│   │   ├── User.swift
│   │   ├── Message.swift
│   │   └── FleaMarketItem.swift
│   ├── Views/                      # 视图层
│   │   ├── Home/
│   │   │   └── HomeView.swift
│   │   ├── Tasks/
│   │   │   ├── TasksView.swift
│   │   │   └── TaskDetailView.swift
│   │   ├── FleaMarket/
│   │   │   └── FleaMarketView.swift
│   │   ├── Message/
│   │   │   └── MessageView.swift
│   │   └── Profile/
│   │       └── ProfileView.swift
│   ├── ViewModels/                 # 视图模型
│   │   ├── TasksViewModel.swift
│   │   ├── MessageViewModel.swift
│   │   └── AuthViewModel.swift
│   ├── Services/                   # 服务层
│   │   ├── APIService.swift        # API调用
│   │   ├── WebSocketService.swift  # WebSocket
│   │   ├── ImageService.swift      # 图片处理
│   │   └── LocationService.swift   # 定位服务
│   ├── Utils/                      # 工具类
│   │   ├── Constants.swift
│   │   ├── Extensions.swift
│   │   └── Helpers.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings     # 多语言
├── LinkU.xcodeproj
└── Package.swift                   # Swift Package依赖
```

### 3.3 核心代码实现

#### 3.3.1 应用入口

```swift
// LinkU/App/LinkUApp.swift
import SwiftUI

@main
struct LinkUApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(appState)
                .onAppear {
                    // 初始化推送通知
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
```

#### 3.3.2 主视图结构

```swift
// LinkU/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            TasksView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet")
                }
                .tag(1)
            
            FleaMarketView()
                .tabItem {
                    Label("跳蚤市场", systemImage: "storefront.fill")
                }
                .tag(2)
            
            MessageView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(4)
        }
    }
}
```

#### 3.3.3 API服务

```swift
// LinkU/Services/APIService.swift
import Foundation
import Combine

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://your-railway-app.railway.app"
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // 通用请求方法
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加自定义headers
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // 添加请求体
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: APIError.encodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // 获取任务列表
    func getTasks(params: TaskListParams) -> AnyPublisher<TaskListResponse, APIError> {
        var queryItems: [URLQueryItem] = []
        if let category = params.category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let city = params.city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        
        var endpoint = "/api/tasks"
        if !queryItems.isEmpty {
            var components = URLComponents(string: baseURL + endpoint)!
            components.queryItems = queryItems
            endpoint = components.url!.path + "?" + components.query!
        }
        
        return request(endpoint: endpoint)
    }
    
    // 上传图片
    func uploadImage(_ imageData: Data) -> AnyPublisher<ImageUploadResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/api/upload/image") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ImageUploadResponse.self, decoder: JSONDecoder())
            .mapError { _ in APIError.networkError(NSError()) }
            .eraseToAnyPublisher()
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum APIError: Error {
    case invalidURL
    case encodingError
    case decodingError
    case networkError(Error)
    case unauthorized
    case serverError(Int)
}
```

#### 3.3.4 ViewModel示例

```swift
// LinkU/ViewModels/TasksViewModel.swift
import SwiftUI
import Combine

class TasksViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadTasks(category: String? = nil, city: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        let params = TaskListParams(category: category, city: city)
        apiService.getTasks(params: params)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.tasks = response.tasks
                }
            )
            .store(in: &cancellables)
    }
}
```

#### 3.3.5 图片选择与上传

```swift
// LinkU/Services/ImageService.swift
import SwiftUI
import PhotosUI

class ImageService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isUploading = false
    
    func pickImage() {
        // 使用PHPickerViewController或UIImagePickerController
    }
    
    func uploadImage(_ image: UIImage) -> AnyPublisher<String, Error> {
        isUploading = true
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: NSError(domain: "ImageService", code: -1))
                .eraseToAnyPublisher()
        }
        
        return APIService.shared.uploadImage(imageData)
            .map { $0.url }
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.isUploading = false
            })
            .eraseToAnyPublisher()
    }
}
```

#### 3.3.6 WebSocket服务

```swift
// LinkU/Services/WebSocketService.swift
import Foundation
import Combine

class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    @Published var isConnected = false
    @Published var receivedMessage: Message?
    
    func connect(token: String) {
        guard let url = URL(string: "wss://your-railway-app.railway.app/ws?token=\(token)") else {
            return
        }
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage() // 继续接收
            case .failure(let error):
                print("WebSocket接收错误: \(error)")
                self?.reconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }
    
    func send(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket发送错误: \(error)")
            }
        }
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let token = KeychainHelper.shared.getToken() else {
            return
        }
        
        reconnectAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(reconnectAttempts)) {
            self.connect(token: token)
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        reconnect()
    }
}
```

#### 3.3.7 推送通知

```swift
// LinkU/Services/NotificationManager.swift
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }
    
    func scheduleLocalNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // 处理通知点击
        completionHandler()
    }
}
```

### 3.4 数据模型

```swift
// LinkU/Models/Task.swift
import Foundation

struct Task: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let category: String
    let city: String
    let price: Double?
    let status: TaskStatus
    let createdAt: String
    let updatedAt: String
    let author: User?
    let images: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, price, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author, images
    }
}

enum TaskStatus: String, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}
```

---

## 4. Android 原生开发方案 🤖

### 4.1 环境搭建

#### 4.1.1 系统要求

**必需**：
- Android Studio Hedgehog (2023.1.1) 或更高版本
- JDK 17 或更高版本
- Android SDK API 24+ (Android 7.0+)
- Kotlin 1.9.0 或更高版本

#### 4.1.2 安装步骤

```bash
# 1. 下载并安装Android Studio
# 2. 安装Android SDK和构建工具
# 3. 创建新项目
# 在Android Studio中: File > New > New Project > Empty Activity
```

#### 4.1.3 项目配置

**build.gradle.kts (Module: app)**:
```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("kotlin-kapt")
    id("kotlin-parcelize")
}

android {
    namespace = "com.linku.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.linku.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.3"
    }
}

dependencies {
    // Compose
    implementation("androidx.compose.ui:ui:1.5.4")
    implementation("androidx.compose.material3:material3:1.1.2")
    implementation("androidx.compose.ui:ui-tooling-preview:1.5.4")
    implementation("androidx.activity:activity-compose:1.8.1")
    
    // ViewModel
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.6.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.6.2")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.5")
    
    // Network
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")
    
    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.0.0")
    
    // Room
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")
}
```

**AndroidManifest.xml权限**:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### 4.2 项目结构

```
LinkU-Android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/linku/app/
│   │   │   │   ├── MainActivity.kt
│   │   │   │   ├── LinkUApplication.kt
│   │   │   │   ├── data/
│   │   │   │   │   ├── models/          # 数据模型
│   │   │   │   │   │   ├── Task.kt
│   │   │   │   │   │   ├── User.kt
│   │   │   │   │   │   └── Message.kt
│   │   │   │   │   ├── api/             # API接口
│   │   │   │   │   │   ├── ApiService.kt
│   │   │   │   │   │   └── RetrofitClient.kt
│   │   │   │   │   ├── local/           # 本地数据库
│   │   │   │   │   │   ├── database/
│   │   │   │   │   │   └── dao/
│   │   │   │   │   └── repository/      # 数据仓库
│   │   │   │   ├── ui/
│   │   │   │   │   ├── theme/           # 主题
│   │   │   │   │   ├── screens/         # 屏幕
│   │   │   │   │   │   ├── home/
│   │   │   │   │   │   ├── tasks/
│   │   │   │   │   │   ├── fleamarket/
│   │   │   │   │   │   ├── message/
│   │   │   │   │   │   └── profile/
│   │   │   │   │   └── components/      # 组件
│   │   │   │   ├── viewmodel/           # 视图模型
│   │   │   │   ├── utils/               # 工具类
│   │   │   │   └── di/                  # 依赖注入
│   │   │   └── res/
│   │   │       ├── values/
│   │   │       │   └── strings.xml      # 多语言
│   │   │       └── drawable/
│   │   └── test/
│   └── build.gradle.kts
└── build.gradle.kts
```

### 4.3 核心代码实现

#### 4.3.1 应用入口

```kotlin
// MainActivity.kt
package com.linku.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.linku.app.ui.navigation.AppNavigation
import com.linku.app.ui.theme.LinkUTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LinkUTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AppNavigation()
                }
            }
        }
    }
}
```

#### 4.3.2 导航配置

```kotlin
// ui/navigation/AppNavigation.kt
package com.linku.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.linku.app.ui.screens.home.HomeScreen
import com.linku.app.ui.screens.tasks.TasksScreen
import com.linku.app.ui.screens.fleamarket.FleaMarketScreen
import com.linku.app.ui.screens.message.MessageScreen
import com.linku.app.ui.screens.profile.ProfileScreen
import com.linku.app.ui.screens.login.LoginScreen

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = "login"
    ) {
        composable("login") {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate("main") {
                        popUpTo("login") { inclusive = true }
                    }
                }
            )
        }
        
        composable("main") {
            MainScreen(navController = navController)
        }
        
        composable("tasks/{taskId}") { backStackEntry ->
            val taskId = backStackEntry.arguments?.getString("taskId")?.toIntOrNull()
            // TaskDetailScreen(taskId = taskId)
        }
    }
}

@Composable
fun MainScreen(navController: NavHostController) {
    // 底部导航栏实现
}
```

#### 4.3.3 API服务

```kotlin
// data/api/ApiService.kt
package com.linku.app.data.api

import com.linku.app.data.models.Task
import com.linku.app.data.models.TaskListResponse
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    @GET("api/tasks")
    suspend fun getTasks(
        @Query("category") category: String? = null,
        @Query("city") city: String? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): Response<TaskListResponse>
    
    @GET("api/tasks/{id}")
    suspend fun getTask(@Path("id") id: Int): Response<Task>
    
    @POST("api/tasks")
    suspend fun createTask(@Body task: CreateTaskRequest): Response<Task>
    
    @Multipart
    @POST("api/upload/image")
    suspend fun uploadImage(
        @Part file: MultipartBody.Part
    ): Response<ImageUploadResponse>
    
    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>
}

// data/api/RetrofitClient.kt
package com.linku.app.data.api

import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object RetrofitClient {
    private const val BASE_URL = "https://your-railway-app.railway.app"
    
    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BODY
    }
    
    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(loggingInterceptor)
        .addInterceptor { chain ->
            val request = chain.request().newBuilder()
                .addHeader("Content-Type", "application/json")
                .apply {
                    // 添加认证token
                    val token = TokenManager.getToken()
                    if (token != null) {
                        addHeader("Authorization", "Bearer $token")
                    }
                }
                .build()
            chain.proceed(request)
        }
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    
    val apiService: ApiService = Retrofit.Builder()
        .baseUrl(BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
        .create(ApiService::class.java)
}
```

#### 4.3.4 ViewModel示例

```kotlin
// viewmodel/TasksViewModel.kt
package com.linku.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linku.app.data.api.RetrofitClient
import com.linku.app.data.models.Task
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TasksViewModel : ViewModel() {
    private val apiService = RetrofitClient.apiService
    
    private val _tasks = MutableStateFlow<List<Task>>(emptyList())
    val tasks: StateFlow<List<Task>> = _tasks.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
    
    fun loadTasks(category: String? = null, city: String? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            
            try {
                val response = apiService.getTasks(category = category, city = city)
                if (response.isSuccessful) {
                    _tasks.value = response.body()?.tasks ?: emptyList()
                } else {
                    _errorMessage.value = "加载失败: ${response.code()}"
                }
            } catch (e: Exception) {
                _errorMessage.value = "网络错误: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
}
```

#### 4.3.5 图片选择与上传

```kotlin
// utils/ImagePicker.kt
package com.linku.app.utils

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File

class ImagePicker {
    @Composable
    fun rememberImagePickerLauncher(
        onImageSelected: (Uri?) -> Unit
    ) = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        onImageSelected(uri)
    }
    
    suspend fun uploadImage(
        context: Context,
        uri: Uri,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        try {
            val file = File(uri.path ?: return)
            val requestFile = file.asRequestBody("image/*".toMediaType())
            val body = MultipartBody.Part.createFormData("file", file.name, requestFile)
            
            val response = RetrofitClient.apiService.uploadImage(body)
            if (response.isSuccessful) {
                onSuccess(response.body()?.url ?: "")
            } else {
                onError("上传失败: ${response.code()}")
            }
        } catch (e: Exception) {
            onError("上传错误: ${e.message}")
        }
    }
}
```

#### 4.3.6 WebSocket服务

```kotlin
// data/websocket/WebSocketService.kt
package com.linku.app.data.websocket

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import okhttp3.*
import okio.ByteString
import org.json.JSONObject

class WebSocketService : WebSocketListener() {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient()
    
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    
    private val _receivedMessage = MutableStateFlow<Message?>(null)
    val receivedMessage: StateFlow<Message?> = _receivedMessage.asStateFlow()
    
    fun connect(token: String) {
        val request = Request.Builder()
            .url("wss://your-railway-app.railway.app/ws?token=$token")
            .build()
        
        webSocket = client.newWebSocket(request, this)
    }
    
    fun send(message: String) {
        webSocket?.send(message)
    }
    
    fun disconnect() {
        webSocket?.close(1000, "正常关闭")
        webSocket = null
    }
    
    override fun onOpen(webSocket: WebSocket, response: Response) {
        _isConnected.value = true
    }
    
    override fun onMessage(webSocket: WebSocket, text: String) {
        try {
            val json = JSONObject(text)
            val message = Message.fromJson(json)
            _receivedMessage.value = message
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        onMessage(webSocket, bytes.utf8())
    }
    
    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        _isConnected.value = false
    }
    
    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        _isConnected.value = false
        // 实现重连逻辑
    }
}
```

#### 4.3.7 推送通知

```kotlin
// utils/NotificationManager.kt
package com.linku.app.utils

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationManager(private val context: Context) {
    private val channelId = "linku_default"
    private val channelName = "LinkU通知"
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "LinkU应用通知"
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    fun showNotification(title: String, message: String) {
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        
        with(NotificationManagerCompat.from(context)) {
            notify(System.currentTimeMillis().toInt(), builder.build())
        }
    }
}
```

### 4.4 数据模型

```kotlin
// data/models/Task.kt
package com.linku.app.data.models

import com.google.gson.annotations.SerializedName

data class Task(
    val id: Int,
    val title: String,
    val description: String,
    val category: String,
    val city: String,
    val price: Double?,
    val status: TaskStatus,
    @SerializedName("created_at")
    val createdAt: String,
    @SerializedName("updated_at")
    val updatedAt: String,
    val author: User?,
    val images: List<String>?
)

enum class TaskStatus {
    @SerializedName("open")
    OPEN,
    @SerializedName("in_progress")
    IN_PROGRESS,
    @SerializedName("completed")
    COMPLETED,
    @SerializedName("cancelled")
    CANCELLED
}
```

---

## 5. 共享代码与API集成

### 5.1 API端点映射

**后端API端点**（FastAPI）：
```
POST   /api/auth/login          # 登录
POST   /api/auth/register       # 注册
GET    /api/tasks               # 获取任务列表
GET    /api/tasks/{id}          # 获取任务详情
POST   /api/tasks               # 创建任务
PUT    /api/tasks/{id}          # 更新任务
DELETE /api/tasks/{id}          # 删除任务
GET    /api/flea-market         # 获取跳蚤市场商品
POST   /api/upload/image        # 上传图片
WS     /ws?token={token}        # WebSocket连接
```

### 5.2 数据模型对应关系

| Web (TypeScript) | iOS (Swift) | Android (Kotlin) |
|-----------------|------------|------------------|
| `interface Task` | `struct Task: Codable` | `data class Task` |
| `type TaskStatus` | `enum TaskStatus` | `enum class TaskStatus` |
| `interface User` | `struct User: Codable` | `data class User` |
| `interface Message` | `struct Message: Codable` | `data class Message` |

### 5.3 认证流程

**Token管理**：
- iOS: 使用Keychain存储token
- Android: 使用DataStore或SharedPreferences存储token

**Token刷新**：
- 实现自动刷新机制
- 401错误时自动刷新token并重试请求

---

## 6. 架构设计

### 6.1 iOS架构 (MVVM + Combine)

```
View (SwiftUI)
  ↓
ViewModel (ObservableObject)
  ↓
Service (APIService, WebSocketService)
  ↓
Model (Codable)
```

### 6.2 Android架构 (MVVM + Coroutines)

```
UI (Compose)
  ↓
ViewModel (StateFlow)
  ↓
Repository
  ↓
DataSource (API, Local DB)
```

### 6.3 状态管理

**iOS**: Combine框架 + @Published属性
**Android**: StateFlow + ViewModel

---

## 7. 测试与部署

### 7.1 iOS测试

#### 7.1.1 单元测试

```swift
// LinkUTests/TasksViewModelTests.swift
import XCTest
@testable import LinkU

class TasksViewModelTests: XCTestCase {
    var viewModel: TasksViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = TasksViewModel()
    }
    
    func testLoadTasks() {
        let expectation = expectation(description: "Load tasks")
        viewModel.loadTasks()
        // 验证结果
        waitForExpectations(timeout: 5)
    }
}
```

#### 7.1.2 UI测试

```swift
// LinkUITests/LinkUITests.swift
import XCTest

class LinkUITests: XCTestCase {
    func testLoginFlow() {
        let app = XCUIApplication()
        app.launch()
        
        let emailTextField = app.textFields["email"]
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        let passwordTextField = app.secureTextFields["password"]
        passwordTextField.tap()
        passwordTextField.typeText("password123")
        
        app.buttons["登录"].tap()
        
        // 验证登录成功
    }
}
```

### 7.2 Android测试

#### 7.2.1 单元测试

```kotlin
// test/TasksViewModelTest.kt
import org.junit.Test
import org.junit.Assert.*

class TasksViewModelTest {
    @Test
    fun testLoadTasks() {
        val viewModel = TasksViewModel()
        viewModel.loadTasks()
        // 验证结果
    }
}
```

### 7.3 构建发布版本

#### 7.3.1 iOS构建

```bash
# 1. 在Xcode中配置证书和描述文件
# 2. 选择 Product > Archive
# 3. 上传到App Store Connect
# 或使用命令行:
xcodebuild -workspace LinkU.xcworkspace \
           -scheme LinkU \
           -configuration Release \
           archive \
           -archivePath ./build/LinkU.xcarchive
```

#### 7.3.2 Android构建

```bash
# 1. 生成签名密钥
keytool -genkeypair -v -storetype PKCS12 \
        -keystore linku-release.keystore \
        -alias linku-key \
        -keyalg RSA -keysize 2048 -validity 10000

# 2. 配置签名 (app/build.gradle.kts)
# 3. 构建AAB
./gradlew bundleRelease

# 4. 构建APK (可选)
./gradlew assembleRelease
```

### 7.4 应用商店提交

#### App Store (iOS)
1. 在App Store Connect创建应用
2. 上传构建版本（使用Xcode或Transporter）
3. 填写应用信息、截图、描述
4. 提交审核

#### Google Play (Android)
1. 在Google Play Console创建应用
2. 上传AAB文件
3. 填写商店信息
4. 提交审核

---

## 8. 性能优化

### 8.1 iOS优化

- ✅ 使用异步加载图片
- ✅ 实现列表虚拟化
- ✅ 使用Combine进行响应式编程
- ✅ 合理使用缓存机制
- ✅ 优化网络请求（合并、去重）

### 8.2 Android优化

- ✅ 使用Coil加载图片
- ✅ 实现列表分页加载
- ✅ 使用Coroutines处理异步操作
- ✅ Room数据库缓存
- ✅ 使用ProGuard/R8代码混淆

### 8.3 通用优化

- ✅ 实现离线模式
- ✅ 压缩图片上传
- ✅ 使用CDN加速
- ✅ 实现请求缓存
- ✅ 监控性能指标

---

## 9. 常见问题

### 9.1 iOS常见问题

**Q: 如何解决证书问题？**
A: 
1. 在Xcode中启用自动管理签名
2. 确保Apple ID已登录
3. 在开发者中心注册设备UDID

**Q: WebSocket在后台断开？**
A:
- 使用后台任务保持连接
- 实现重连机制
- 使用推送通知作为补充

### 9.2 Android常见问题

**Q: 如何解决构建错误？**
A:
1. 清理构建缓存：`./gradlew clean`
2. 检查Gradle版本兼容性
3. 检查依赖冲突

**Q: 图片上传失败？**
A:
- 检查文件大小限制
- 确保Multipart格式正确
- 检查网络权限

---

## 10. 开发时间估算

### iOS原生开发
- **环境搭建**: 1-2天
- **项目架构**: 3-5天
- **核心功能开发**: 6-8周
- **UI/UX实现**: 2-3周
- **测试与优化**: 2-3周
- **总计**: 10-14周

### Android原生开发
- **环境搭建**: 1-2天
- **项目架构**: 3-5天
- **核心功能开发**: 6-8周
- **UI/UX实现**: 2-3周
- **测试与优化**: 2-3周
- **总计**: 10-14周

### 双平台并行开发
- **总计**: 12-16周（两个团队并行）

---

## 11. 后续优化建议

1. **性能监控**: 集成Firebase Analytics或Sentry
2. **A/B测试**: 优化用户体验
3. **深度链接**: 支持分享和跳转
4. **离线功能**: 实现关键功能离线可用
5. **多语言**: 扩展支持更多语言
6. **无障碍**: 提升可访问性
7. **暗黑模式**: 支持系统主题切换

---

## 12. 参考资料

### iOS开发
- [Swift官方文档](https://swift.org/documentation/)
- [SwiftUI教程](https://developer.apple.com/tutorials/swiftui)
- [Apple开发者文档](https://developer.apple.com/documentation/)
- [App Store审核指南](https://developer.apple.com/app-store/review/guidelines/)

### Android开发
- [Kotlin官方文档](https://kotlinlang.org/docs/home.html)
- [Jetpack Compose教程](https://developer.android.com/jetpack/compose)
- [Android开发者文档](https://developer.android.com/docs)
- [Google Play政策](https://play.google.com/about/developer-content-policy/)

---

**文档维护**: 本文档应随项目进展持续更新  
**最后更新**: 2025-01-20