import Foundation
import Combine
import UIKit

class CreateTaskViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
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
    
    // 学生验证状态（用于检查权限）
    @Published var studentVerificationStatus: StudentVerificationStatusData?
    private var studentVerificationViewModel = StudentVerificationViewModel()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
        loadStudentVerificationStatus()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // 加载学生验证状态
    private func loadStudentVerificationStatus() {
        studentVerificationViewModel.loadStatus()
        studentVerificationViewModel.$verificationStatus
            .assign(to: &$studentVerificationStatus)
    }
    
    // 检查用户是否有权限发布"校园生活"类型的任务
    private func canPublishCampusLifeTask() -> Bool {
        guard taskType == "Campus Life" else {
            return true // 非校园生活类型，不需要检查
        }
        // 只有已通过学生认证的用户才能发布校园生活类型的任务
        return studentVerificationStatus?.isVerified == true
    }
    
    // 后端真实的任务类型列表（使用本地化）
    var taskTypes: [(label: String, value: String)] {
        [
            (LocalizationKey.taskCategoryHousekeeping.localized, "Housekeeping"),
            (LocalizationKey.taskCategoryCampusLife.localized, "Campus Life"),
            (LocalizationKey.taskCategorySecondhandRental.localized, "Second-hand & Rental"),
            (LocalizationKey.taskCategoryErrandRunning.localized, "Errand Running"),
            (LocalizationKey.taskCategorySkillService.localized, "Skill Service"),
            (LocalizationKey.taskCategorySocialHelp.localized, "Social Help"),
            (LocalizationKey.taskCategoryTransportation.localized, "Transportation"),
            (LocalizationKey.taskCategoryPetCare.localized, "Pet Care"),
            (LocalizationKey.taskCategoryLifeConvenience.localized, "Life Convenience"),
            (LocalizationKey.taskCategoryOther.localized, "Other")
        ]
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
                self?.errorMessage = LocalizationKey.createTaskImageUploadFailed.localized
                completion(false)
            }
        }
    }
    
    func createTask(completion: @escaping (Bool) -> Void) {
        guard !title.isEmpty, !description.isEmpty, !city.isEmpty else {
            errorMessage = LocalizationKey.createTaskFillAllRequired.localized
            return
        }
        
        // 权限检查：只有学生用户才能发布"校园生活"类型的任务
        if !canPublishCampusLifeTask() {
            errorMessage = LocalizationKey.createTaskStudentVerificationRequired.localized
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
            
            let startTime = Date()
            let endpoint = "/api/tasks"
            
            self.apiService.request(Task.self, endpoint, method: "POST", body: body)
                .sink(receiveCompletion: { [weak self] result in
                    let duration = Date().timeIntervalSince(startTime)
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "创建任务")
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
                }, receiveValue: { [weak self] _ in
                    self?.reset()
                    // 清除我的任务缓存，因为创建了新任务
                    CacheManager.shared.invalidateMyTasksCache()
                    // 发送通知刷新任务列表
                    NotificationCenter.default.post(name: .taskUpdated, object: nil)
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

