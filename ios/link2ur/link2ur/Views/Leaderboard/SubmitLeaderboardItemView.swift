import SwiftUI
import PhotosUI
import UIKit
import Combine

@available(iOS 16.0, *)
struct SubmitLeaderboardItemView: View {
    let leaderboardId: Int
    @StateObject private var viewModel = LeaderboardDetailViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
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
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: AppSpacing.lg) {
                    // 名称
                    EnhancedTextField(
                        title: "竞品名称",
                        placeholder: "请输入名称",
                        text: $name,
                        icon: "building.2.fill",
                        isRequired: true
                    )
                    
                    // 描述
                    EnhancedTextEditor(
                        title: "描述",
                        placeholder: "请输入竞品描述",
                        text: $description,
                        height: 100,
                        characterLimit: 500
                    )
                    
                    // 地址
                    EnhancedTextField(
                        title: "地址",
                        placeholder: "请输入地址",
                        text: $address,
                        icon: "mappin.circle.fill"
                    )
                    
                    // 电话
                    EnhancedTextField(
                        title: "电话",
                        placeholder: "请输入电话",
                        text: $phone,
                        icon: "phone.fill",
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber
                    )
                    
                    // 网站
                    EnhancedTextField(
                        title: "网站",
                        placeholder: "请输入网站URL",
                        text: $website,
                        icon: "link",
                        keyboardType: .URL,
                        autocapitalization: .never
                    )
                    
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
                        if appState.isAuthenticated {
                            submitItem()
                        } else {
                            showLogin = true
                        }
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
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("提交竞品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .onAppear {
                if !appState.isAuthenticated {
                    showLogin = true
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

