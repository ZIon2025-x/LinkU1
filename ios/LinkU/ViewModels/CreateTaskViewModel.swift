import Foundation
import Combine

class CreateTaskViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var price: Double?
    @Published var currency = "GBP"
    @Published var city = ""
    @Published var category = ""
    @Published var taskType = "normal"
    @Published var selectedImages: [UIImage] = []
    @Published var uploadedImageUrls: [String] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    let categories = ["其他", "配送", "代购", "维修", "清洁", "搬家", "学习", "娱乐", "其他"]
    let taskTypes = ["normal", "urgent", "flexible"]
    
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
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
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
                self?.errorMessage = "部分图片上传失败"
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
            
            if !self.uploadedImageUrls.isEmpty {
                body["images"] = self.uploadedImageUrls
            }
            
            self.apiService.request(Task.self, "/api/tasks", method: "POST", body: body)
                .sink(receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
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
        category = ""
        selectedImages = []
        uploadedImageUrls = []
        errorMessage = nil
    }
}

