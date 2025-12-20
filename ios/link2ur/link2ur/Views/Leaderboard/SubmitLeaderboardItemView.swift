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
                VStack(spacing: AppSpacing.xl) {
                    // 1. 基本信息
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "基本信息", icon: "building.2.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 名称
                            EnhancedTextField(
                                title: "竞品名称",
                                placeholder: "请输入名称",
                                text: $name,
                                icon: "pencil",
                                isRequired: true
                            )
                            
                            // 描述
                            EnhancedTextEditor(
                                title: "竞品描述",
                                placeholder: "简单介绍一下这个竞品...",
                                text: $description,
                                height: 120,
                                characterLimit: 500
                            )
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // 2. 联系方式
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "联系方式 (可选)", icon: "info.circle.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 地址
                            EnhancedTextField(
                                title: "地址",
                                placeholder: "请输入详细地址",
                                text: $address,
                                icon: "mappin.and.ellipse"
                            )
                            
                            // 电话
                            EnhancedTextField(
                                title: "电话",
                                placeholder: "请输入联系电话",
                                text: $phone,
                                icon: "phone.fill",
                                keyboardType: .phonePad,
                                textContentType: .telephoneNumber
                            )
                            
                            // 网站
                            EnhancedTextField(
                                title: "官方网站",
                                placeholder: "请输入网站地址",
                                text: $website,
                                icon: "globe",
                                keyboardType: .URL,
                                autocapitalization: .never
                            )
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // 3. 图片展示
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            SectionHeader(title: "图片展示 (可选)", icon: "photo.on.rectangle.angled")
                            Spacer()
                            Text("\(selectedImages.count)/5")
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.primaryLight)
                                .clipShape(Capsule())
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.md) {
                                // 添加按钮
                                if selectedImages.count < 5 {
                                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - selectedImages.count, matching: .images) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "plus.viewfinder")
                                                .font(.system(size: 28))
                                                .foregroundColor(AppColors.primary)
                                            Text("添加图片")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                        .frame(width: 90, height: 90)
                                        .background(AppColors.background)
                                        .cornerRadius(AppCornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        )
                                    }
                                    .onChange(of: selectedItems) { newValue in
                                        handleImageSelection(newValue)
                                    }
                                }
                                
                                // 图片预览
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                        
                                        Button(action: {
                                            withAnimation {
                                                selectedImages.remove(at: index)
                                                if index < selectedItems.count {
                                                    selectedItems.remove(at: index)
                                                }
                                                HapticFeedback.light()
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // 错误提示
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            IconStyle.icon("exclamationmark.octagon.fill", size: 16)
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.error.opacity(0.08))
                        .cornerRadius(AppCornerRadius.medium)
                    }
                    
                    // 提交按钮
                    Button(action: {
                        if appState.isAuthenticated {
                            HapticFeedback.success()
                            submitItem()
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading || isUploading {
                                ProgressView().tint(.white)
                            } else {
                                IconStyle.icon("checkmark.seal.fill", size: 18)
                            }
                            Text(viewModel.isLoading || isUploading ? "正在提交..." : "提交竞品")
                                .font(AppTypography.bodyBold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading || isUploading || name.isEmpty)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
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
    
    // MARK: - Helper Methods
    
    private func handleImageSelection(_ items: [PhotosPickerItem]) {
        _Concurrency.Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if selectedImages.count < 5 {
                            selectedImages.append(image)
                        }
                    }
                }
            }
            // 不要在这里清空 selectedItems，否则 onChange 会再次触发
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

