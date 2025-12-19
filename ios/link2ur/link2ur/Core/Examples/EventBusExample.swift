import Foundation
import Combine

/// 事件总线使用示例
class EventBusExample {
    private var cancellables = Set<AnyCancellable>()
    
    /// 示例1: 基本事件发布和订阅
    func basicEventBus() {
        // 定义事件
        struct UserLoginEvent: AppEvent {
            let timestamp = Date()
            let userId: String
        }
        
        // 订阅事件
        EventBus.shared.subscribe(UserLoginEvent.self)
            .sink { event in
                print("用户登录: \(event.userId)")
            }
            .store(in: &cancellables)
        
        // 发布事件
        EventBus.shared.publish(UserLoginEvent(userId: "123"))
    }
    
    /// 示例2: 使用自定义主题
    func customTopic() {
        // 订阅自定义主题
        EventBus.shared.subscribe(String.self, topic: "notifications")
            .sink { message in
                print("通知: \(message)")
            }
            .store(in: &cancellables)
        
        // 发布到自定义主题
        EventBus.shared.publish("新消息", topic: "notifications")
    }
    
    /// 示例3: 多个订阅者
    func multipleSubscribers() {
        struct DataUpdatedEvent: AppEvent {
            let timestamp = Date()
            let dataType: String
        }
        
        // 订阅者1
        EventBus.shared.subscribe(DataUpdatedEvent.self)
            .sink { event in
                print("订阅者1: 数据更新 - \(event.dataType)")
            }
            .store(in: &cancellables)
        
        // 订阅者2
        EventBus.shared.subscribe(DataUpdatedEvent.self)
            .sink { event in
                print("订阅者2: 数据更新 - \(event.dataType)")
            }
            .store(in: &cancellables)
        
        // 发布事件（所有订阅者都会收到）
        EventBus.shared.publish(DataUpdatedEvent(dataType: "用户"))
    }
    
    /// 示例4: 在 ViewModel 中使用
    class ExampleViewModel: ObservableObject {
        @Published var user: User?
        private var cancellables = Set<AnyCancellable>()
        
        init() {
            // 订阅用户更新事件
            EventBus.shared.subscribe(UserUpdatedEvent.self)
                .sink { [weak self] event in
                    self?.user = event.user
                }
                .store(in: &cancellables)
        }
        
        func updateUser() {
            // 更新用户后发布事件
            let updatedUser = User(id: "1", name: "新名称")
            EventBus.shared.publish(UserUpdatedEvent(user: updatedUser))
        }
    }
    
    struct UserUpdatedEvent: AppEvent {
        let timestamp = Date()
        let user: User
    }
}

