//
//  PublishTaskView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct PublishTaskView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PublishTaskViewModel()
    @State private var title = ""
    @State private var description = ""
    @State private var taskType = "Housekeeping"
    @State private var location = "London"
    @State private var reward: Double = 0
    @State private var isFlexible = false
    @State private var deadline: Date = Date()
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    
    let taskTypes = ["Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", 
                     "Skill Service", "Social Help", "Transportation", "Pet Care", 
                     "Life Convenience", "Other"]
    
    let cities = ["Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", 
                  "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", 
                  "Southampton", "Liverpool", "Cardiff", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("任务标题", text: $title)
                    TextEditor(text: $description)
                        .frame(height: 100)
                    
                    Picker("任务类型", selection: $taskType) {
                        ForEach(taskTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Picker("城市", selection: $location) {
                        ForEach(cities, id: \.self) { city in
                            Text(city).tag(city)
                        }
                    }
                }
                
                Section("价格") {
                    HStack {
                        Text("£")
                        TextField("0.00", value: $reward, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("时间设置") {
                    Toggle("灵活时间（无截止日期）", isOn: $isFlexible)
                    
                    if !isFlexible {
                        DatePicker("截止日期", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("图片（最多5张）") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                }
                            }
                            
                            if selectedImages.count < 5 {
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                        Text("添加图片")
                                            .font(.caption)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("发布任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        publishTask()
                    }
                    .disabled(viewModel.isLoading || title.isEmpty || description.isEmpty || reward <= 0)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        if let image = image, selectedImages.count < 5 {
                            selectedImages.append(image)
                        }
                    }
                ))
            }
        }
    }
    
    private func publishTask() {
        viewModel.publishTask(
            title: title,
            description: description,
            taskType: taskType,
            location: location,
            reward: reward,
            isFlexible: isFlexible,
            deadline: isFlexible ? nil : deadline,
            images: selectedImages
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}

class PublishTaskViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func publishTask(
        title: String,
        description: String,
        taskType: String,
        location: String,
        reward: Double,
        isFlexible: Bool,
        deadline: Date?,
        images: [UIImage],
        completion: @escaping (Bool) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        
        // 先上传图片
        let imageUploads = images.map { image in
            apiService.uploadImage(image.jpegData(compressionQuality: 0.8)!)
        }
        
        Publishers.MergeMany(imageUploads)
            .collect()
            .flatMap { imageUrls -> AnyPublisher<Task, APIError> in
                let imageUrlStrings = imageUrls.map { $0.url }
                
                let formatter = ISO8601DateFormatter()
                let deadlineString = deadline != nil ? formatter.string(from: deadline!) : nil
                
                let request = CreateTaskRequest(
                    title: title,
                    description: description,
                    taskType: taskType,
                    location: location,
                    reward: reward,
                    images: imageUrlStrings.isEmpty ? nil : imageUrlStrings,
                    deadline: deadlineString,
                    isFlexible: isFlexible ? 1 : 0,
                    isPublic: 1
                )
                
                return self.apiService.createTask(request)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isLoading = false
                    if case .failure(let error) = result {
                        self?.errorMessage = error.localizedDescription
                        completion(false)
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isLoading = false
                    completion(true)
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    PublishTaskView()
}

