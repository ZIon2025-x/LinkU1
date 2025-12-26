import Foundation
import Combine
import UIKit

class CreateFleaMarketItemViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    
    @Published var title = ""
    @Published var description = ""
    @Published var price: Double?
    @Published var currency = "GBP"
    @Published var location = "Online"
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var category = ""
    @Published var contact = ""
    @Published var selectedImages: [UIImage] = []
    @Published var uploadedImageUrls: [String] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var errorMessage: String?
    @Published var categories: [String] = [] // 从 API 加载的分类列表
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
        loadCategories()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadCategories() {
        apiService.request(FleaMarketCategoryResponse.self, "/api/flea-market/categories", method: "GET")
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载商品分类")
                }
            }, receiveValue: { [weak self] response in
                // 使用分类名称列表（后端期望的是名称，如 "Electronics", "Clothing" 等）
                self?.categories = response.data.categories
            })
            .store(in: &cancellables)
    }
    
    func uploadImages(completion: @escaping (Bool) -> Void) {
        guard !selectedImages.isEmpty else {
            completion(true)
            return
        }
        
        isUploading = true
        uploadedImageUrls = []
        
        let uploadGroup = DispatchGroup()
        var uploadErrors: [Error] = []
        
        for image in selectedImages {
            uploadGroup.enter()
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                uploadGroup.leave()
                continue
            }
            
            apiService.uploadImage(imageData, filename: "item_\(UUID().uuidString).jpg")
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "上传商品图片")
                        uploadErrors.append(error)
                    }
                    uploadGroup.leave()
                }, receiveValue: { [weak self] url in
                    self?.uploadedImageUrls.append(url)
                })
                .store(in: &cancellables)
        }
        
        uploadGroup.notify(queue: .main) { [weak self] in
            self?.isUploading = false
            if uploadErrors.isEmpty {
                completion(true)
            } else {
                // 使用 ErrorHandler 统一处理错误
                if let firstError = uploadErrors.first {
                    ErrorHandler.shared.handle(firstError, context: "上传商品图片")
                }
                self?.errorMessage = "部分图片上传失败，请重试"
                completion(false)
            }
        }
    }
    
    func createItem(completion: @escaping (Bool) -> Void) {
        guard !title.isEmpty, !description.isEmpty, let price = price, price > 0 else {
            errorMessage = "请填写所有必填项"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 先上传图片
        uploadImages { [weak self] success in
            guard let self = self else { return }
            
            if !success && self.uploadedImageUrls.isEmpty {
                self.isLoading = false
                completion(false)
                return
            }
            
            // 创建商品
            var body: [String: Any] = [
                "title": self.title,
                "description": self.description,
                "price": price,
                "location": self.location
            ]
            
            // 添加坐标信息（如果存在）
            if let lat = self.latitude, let lon = self.longitude {
                body["latitude"] = lat
                body["longitude"] = lon
            }
            
            if !self.category.isEmpty {
                body["category"] = self.category
            }
            if !self.contact.isEmpty {
                body["contact"] = self.contact
            }
            if !self.uploadedImageUrls.isEmpty {
                body["images"] = self.uploadedImageUrls
            }
            
            let startTime = Date()
            let endpoint = "/api/flea-market/items"
            
            self.apiService.request(CreateFleaMarketItemResponse.self, endpoint, method: "POST", body: body)
                .sink(receiveCompletion: { [weak self] result in
                    let duration = Date().timeIntervalSince(startTime)
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "创建商品")
                        // 记录性能指标
                        self?.performanceMonitor.recordNetworkRequest(
                            endpoint: endpoint,
                            method: "POST",
                            duration: duration,
                            error: error
                        )
                        self?.errorMessage = error.userFriendlyMessage
                        completion(false)
                    } else {
                        // 记录成功请求的性能指标
                        self?.performanceMonitor.recordNetworkRequest(
                            endpoint: endpoint,
                            method: "POST",
                            duration: duration,
                            statusCode: 200
                        )
                    }
                }, receiveValue: { [weak self] response in
                    // 响应成功，可以访问 response.data.id 获取创建的商品 ID
                    self?.reset()
                    completion(true)
                })
                .store(in: &self.cancellables)
        }
    }
    
    func reset() {
        title = ""
        description = ""
        price = nil
        location = "Online"
        latitude = nil
        longitude = nil
        category = ""
        contact = ""
        selectedImages = []
        uploadedImageUrls = []
        errorMessage = nil
    }
}

