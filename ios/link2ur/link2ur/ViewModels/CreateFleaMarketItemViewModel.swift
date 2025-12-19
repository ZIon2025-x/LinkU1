import Foundation
import Combine
import UIKit

class CreateFleaMarketItemViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var price: Double?
    @Published var currency = "GBP"
    @Published var location = "Online"
    @Published var category = ""
    @Published var contact = ""
    @Published var selectedImages: [UIImage] = []
    @Published var uploadedImageUrls: [String] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    let categories = ["电子产品", "服装配饰", "家具家电", "图书文具", "运动户外", "美妆护肤", "其他"]
    
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
            
            if !self.category.isEmpty {
                body["category"] = self.category
            }
            if !self.contact.isEmpty {
                body["contact"] = self.contact
            }
            if !self.uploadedImageUrls.isEmpty {
                body["images"] = self.uploadedImageUrls
            }
            
            self.apiService.request(FleaMarketItem.self, "/api/flea-market/items", method: "POST", body: body)
                .sink(receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "创建商品")
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                        completion(false)
                    }
                }, receiveValue: { [weak self] _ in
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
        category = ""
        contact = ""
        selectedImages = []
        uploadedImageUrls = []
        errorMessage = nil
    }
}

