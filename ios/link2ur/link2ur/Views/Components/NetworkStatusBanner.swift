import SwiftUI
import Combine

// MARK: - 网络状态 Banner

/// 全局网络状态 Banner
/// 在网络断开时显示提示，网络恢复时自动隐藏
public struct NetworkStatusBanner: View {
    @StateObject private var viewModel = NetworkStatusBannerViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isVisible {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isVisible)
    }
    
    private var bannerContent: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: viewModel.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // 状态文本
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                if let subtitle = viewModel.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // 重试按钮（网络恢复后显示）
            if viewModel.showRetryButton {
                Button(action: viewModel.retryConnection) {
                    Text("重试")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            
            // 关闭按钮
            Button(action: viewModel.dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(viewModel.backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - ViewModel

@MainActor
final class NetworkStatusBannerViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var showRetryButton: Bool = false
    
    private(set) var title: String = ""
    private(set) var subtitle: String?
    private(set) var iconName: String = "wifi.slash"
    private(set) var backgroundColor: Color = .red
    
    private var cancellables = Set<AnyCancellable>()
    private var dismissTimer: Timer?
    private var lastConnectionState: Bool = true
    
    init() {
        setupNetworkObserver()
    }
    
    private func setupNetworkObserver() {
        // 监听网络状态变化
        Reachability.shared.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleNetworkStateChange(isConnected: isConnected)
            }
            .store(in: &cancellables)
        
        // 监听连接类型变化
        Reachability.shared.$connectionType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateConnectionTypeInfo()
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkStateChange(isConnected: Bool) {
        dismissTimer?.invalidate()
        
        if !isConnected {
            // 网络断开
            showOfflineBanner()
        } else if !lastConnectionState {
            // 网络恢复（之前是断开状态）
            showOnlineBanner()
        }
        
        lastConnectionState = isConnected
    }
    
    private func showOfflineBanner() {
        title = "网络连接已断开"
        subtitle = "请检查您的网络设置"
        iconName = "wifi.slash"
        backgroundColor = .red
        showRetryButton = false
        
        withAnimation {
            isVisible = true
        }
        
        Logger.warning("网络连接断开，显示离线提示", category: .network)
    }
    
    private func showOnlineBanner() {
        title = "网络已恢复"
        subtitle = getConnectionTypeDescription()
        iconName = "wifi"
        backgroundColor = .green
        showRetryButton = true
        
        withAnimation {
            isVisible = true
        }
        
        // 3秒后自动隐藏（主线程执行，避免 Swift 6 并发捕获警告）
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.dismiss()
            }
        }
        
        Logger.info("网络连接恢复", category: .network)
        
        // 触发请求队列处理
        RequestQueueManager.shared.processQueue()
    }
    
    private func updateConnectionTypeInfo() {
        if isVisible && Reachability.shared.isConnected {
            subtitle = getConnectionTypeDescription()
        }
    }
    
    private func getConnectionTypeDescription() -> String {
        switch Reachability.shared.connectionType {
        case .wifi:
            return "已连接到 Wi-Fi"
        case .cellular:
            return "已连接到蜂窝网络"
        case .ethernet:
            return "已连接到以太网"
        default:
            return "网络已连接"
        }
    }
    
    func dismiss() {
        dismissTimer?.invalidate()
        withAnimation {
            isVisible = false
        }
    }
    
    func retryConnection() {
        // 触发重试失败的请求
        RequestQueueManager.shared.processQueue()
        
        // 发送通知让其他组件刷新
        NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
        
        dismiss()
    }
}

// MARK: - View Modifier

/// 网络状态 Banner 修饰符
public struct NetworkStatusBannerModifier: ViewModifier {
    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            NetworkStatusBanner()
        }
    }
}

extension View {
    /// 添加全局网络状态 Banner
    public func withNetworkStatusBanner() -> some View {
        modifier(NetworkStatusBannerModifier())
    }
}

// MARK: - 网络状态指示器（小型）

/// 小型网络状态指示器（用于状态栏等位置）
public struct NetworkStatusIndicator: View {
    @ObservedObject private var reachability = Reachability.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(reachability.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            if !reachability.isConnected {
                Text("离线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reachability.isConnected)
    }
}

// MARK: - 预览

#if DEBUG
struct NetworkStatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NetworkStatusBanner()
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
}
#endif
