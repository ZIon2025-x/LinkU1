import Foundation
import Combine
import UIKit

class CreateTaskViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var price: Double?
    @Published var currency = "GBP"
    @Published var city = ""
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var category = ""
    @Published var taskType = "Other"
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
    
    // 后端真实的任务类型列表
    let taskTypes: [(label: String, value: String)] = [
        ("家政服务", "Housekeeping"),
        ("校园生活", "Campus Life"),
        ("二手租赁", "Second-hand & Rental"),
        ("跑腿代购", "Errand Running"),
        ("技能服务", "Skill Service"),
        ("社交互助", "Social Help"),
        ("交通用车", "Transportation"),
        ("宠物寄养", "Pet Care"),
        ("生活便利", "Life Convenience"),
        ("其他", "Other")
    ]
    
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
            
            apiService.uploadImage(imageData, filename: "task_image_\(UUID().uuidString).jpg")
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "上传图片")
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
                    ErrorHandler.shared.handle(firstError, context: "上传任务图片")
                }
                self?.errorMessage = "部分图片上传失败，请重试"
                completion(false)
            }
        }
    }
    
    func createTask(completion: @escaping (Bool) -> Void) {
        guard !title.isEmpty, !description.isEmpty, !city.isEmpty else {
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
            
            // 创建任务
            var body: [String: Any] = [
                "title": self.title,
                "description": self.description,
                "location": self.city,
                "task_type": self.taskType,
                "currency": self.currency
            ]
            
            if let price = self.price {
                body["reward"] = price
            }
            
            // 添加坐标信息（如果存在）
            if let lat = self.latitude, let lon = self.longitude {
                body["latitude"] = lat
                body["longitude"] = lon
            }
            
            if !self.uploadedImageUrls.isEmpty {
                body["images"] = self.uploadedImageUrls
            }
            
            self.apiService.request(Task.self, "/api/tasks", method: "POST", body: body)
                .sink(receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "创建任务")
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
        city = ""
        latitude = nil
        longitude = nil
        category = ""
        taskType = "Other"
        selectedImages = []
        uploadedImageUrls = []
        errorMessage = nil
    }
}

