import Foundation

/// 代码生成器 - 企业级代码生成工具
public struct CodeGenerator {
    
    /// 生成 ViewModel 模板
    public static func generateViewModelTemplate(
        name: String,
        modelName: String
    ) -> String {
        return """
        import Foundation
        import Combine
        
        class \(name)ViewModel: ObservableObject {
            @Published var \(modelName.lowercased()): \(modelName)?
            @Published var isLoading = false
            @Published var errorMessage: String?
            
            private let apiService = DependencyContainer.shared.resolve(APIServiceProtocol.self)
            private var cancellables = Set<AnyCancellable>()
            
            func load\(modelName)() {
                isLoading = true
                errorMessage = nil
                
                // TODO: 实现加载逻辑
            }
        }
        """
    }
    
    /// 生成 View 模板
    public static func generateViewTemplate(
        name: String,
        viewModelName: String
    ) -> String {
        return """
        import SwiftUI
        
        struct \(name)View: View {
            @StateObject private var viewModel = \(viewModelName)ViewModel()
            @State private var loadingState: LoadingState<\(viewModelName)> = .idle
            
            var body: some View {
                NavigationView {
                    ScrollView {
                        VStack {
                            // TODO: 实现视图内容
                        }
                    }
                    .navigationTitle("\(name)")
                    .loadingState(loadingState)
                }
            }
        }
        """
    }
    
    /// 生成 API Service 模板
    public static func generateAPIServiceTemplate(
        endpoint: String,
        method: String,
        responseType: String
    ) -> String {
        return """
        func \(endpoint.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "-", with: "_"))() -> AnyPublisher<\(responseType), APIError> {
            return NetworkManager.shared.execute(
                \(responseType).self,
                endpoint: "\(endpoint)",
                method: "\(method)",
                cachePolicy: .networkFirst
            )
        }
        """
    }
}

