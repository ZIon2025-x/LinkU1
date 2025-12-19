import SwiftUI
import PhotosUI
import UIKit
import Combine

@available(iOS 16.0, *)
struct SubmitLeaderboardItemView: View {
    let leaderboardId: Int
    @StateObject private var viewModel = LeaderboardDetailViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var selectedImages: [UIImage] = []
    @State private var uploadedImageUrls: [String] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("竞品名称 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入名称", text: $name)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(8)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // 地址
                    VStack(alignment: .leading, spacing: 8) {
                        Text("地址（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入地址", text: $address)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 电话
                    VStack(alignment: .leading, spacing: 8) {
                        Text("电话（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入电话", text: $phone)
                            .keyboardType(.phonePad)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 网站
                    VStack(alignment: .leading, spacing: 8) {
                        Text("网站（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入网站URL", text: $website)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 图片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("图片（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("选择图片")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primaryLight)
                            .foregroundColor(AppColors.primary)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .onChange(of: selectedItems) { newValue in
                            AsyncTask {
                                selectedImages = []
                                for item in newValue {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                        }
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                                            
                                            Button(action: {
                                                selectedImages.remove(at: index)
                                                selectedItems.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 错误提示
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 提交按钮
                    Button(action: {
                        submitItem()
                    }) {
                        if viewModel.isLoading || isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("提交竞品")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.medium)
                    .disabled(viewModel.isLoading || isUploading || name.isEmpty)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle("提交竞品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitItem() {
        guard !name.isEmpty else {
            errorMessage = "请输入竞品名称"
            return
        }
        
        errorMessage = nil
        
        // 先上传图片
        if !selectedImages.isEmpty {
            isUploading = true
            uploadImages { success in
                isUploading = false
                if success {
                    submitItemWithImages()
                } else {
                    errorMessage = "图片上传失败"
                }
            }
        } else {
            submitItemWithImages()
        }
    }
    
    private func uploadImages(completion: @escaping (Bool) -> Void) {
        let apiService = APIService.shared
        let uploadGroup = DispatchGroup()
        var uploadErrors: [Error] = []
        var localCancellables = Set<AnyCancellable>()
        uploadedImageUrls = []
        
        for image in selectedImages {
            uploadGroup.enter()
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                uploadGroup.leave()
                continue
            }
            
            apiService.uploadImage(imageData, filename: "item_\(UUID().uuidString).jpg")
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        uploadErrors.append(NSError(domain: "UploadError", code: 0))
                    }
                    uploadGroup.leave()
                }, receiveValue: { url in
                    uploadedImageUrls.append(url)
                })
                .store(in: &localCancellables)
        }
        
        uploadGroup.notify(queue: .main) {
            completion(uploadErrors.isEmpty)
        }
    }
    
    private func submitItemWithImages() {
        viewModel.submitItem(
            leaderboardId: leaderboardId,
            name: name,
            description: description.isEmpty ? nil : description,
            address: address.isEmpty ? nil : address,
            phone: phone.isEmpty ? nil : phone,
            website: website.isEmpty ? nil : website,
            images: uploadedImageUrls.isEmpty ? nil : uploadedImageUrls
        ) { success in
            if success {
                dismiss()
            } else {
                errorMessage = "提交失败，请重试"
            }
        }
    }
}

