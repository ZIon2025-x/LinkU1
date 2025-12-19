import Foundation
import Network
import Combine

/// 网络可达性监控 - 企业级网络状态管理
public final class Reachability: ObservableObject {
    public static let shared = Reachability()
    
    @Published public var isConnected: Bool = true
    @Published public var connectionType: ConnectionType = .unknown
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case unavailable
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ReachabilityMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .unknown
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.status == .unsatisfied {
            return .unavailable
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        
        return .unknown
    }
    
    deinit {
        monitor.cancel()
    }
}

