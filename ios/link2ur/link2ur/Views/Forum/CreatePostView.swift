import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: AppSpacing.xl) {
                    // 1. 标题与板块
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: LocalizationKey.forumCreatePostBasicInfo.localized, icon: "doc.text.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 标题
                            EnhancedTextField(
                                title: LocalizationKey.forumCreatePostPostTitle.localized,
                                placeholder: LocalizationKey.forumCreatePostPostTitlePlaceholder.localized,
                                text: $viewModel.title,
                                icon: "pencil.line",
                                isRequired: true
                            )
                            
                            // 分类选择
                            CustomPickerField(
                                title: LocalizationKey.forumSelectSection.localized,
                                selection: Binding(
                                    get: { viewModel.selectedCategoryId != nil ? "\(viewModel.selectedCategoryId!)" : "" },
                                    set: { newValue in viewModel.selectedCategoryId = Int(newValue) }
                                ),
                                options: viewModel.categories.map { ("\($0.id)", $0.displayName) },
                                icon: "tray.full.fill"
                            )
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // 2. 帖子内容
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: LocalizationKey.forumCreatePostPostContent.localized, icon: "text.alignleft")
                        
                        EnhancedTextEditor(
                            title: nil,
                            placeholder: LocalizationKey.forumCreatePostContentPlaceholder.localized,
                            text: $viewModel.content,
                            height: 250,
                            isRequired: true,
                            characterLimit: 2000
                        )
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // 3. 帖子图片（最多5张）
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            SectionHeader(title: LocalizationKey.forumCreatePostImages.localized, icon: "photo.on.rectangle.angled")
                            Spacer()
                            Text("\(viewModel.selectedImages.count)/5")
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
                                if viewModel.selectedImages.count < 5 {
                                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - viewModel.selectedImages.count, matching: .images) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "plus.viewfinder")
                                                .font(.system(size: 28))
                                                .foregroundColor(AppColors.primary)
                                            Text(LocalizationKey.forumCreatePostAddImage.localized)
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
                                    .onChange(of: selectedItems) { _ in
                                        handleImageSelection()
                                    }
                                }
                                
                                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                        
                                        Button(action: {
                                            withAnimation {
                                                viewModel.selectedImages.remove(at: index)
                                                selectedItems = []
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
                    if let errorMessage = viewModel.errorMessage {
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
                    
                    // 发布按钮
                    Button(action: {
                        if appState.isAuthenticated {
                            HapticFeedback.success()
                            viewModel.createPost { success in
                                if success {
                                    dismiss()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading || viewModel.isUploading {
                                ProgressView().tint(.white)
                            } else {
                                IconStyle.icon("paperplane.fill", size: 18)
                            }
                            Text(viewModel.isLoading || viewModel.isUploading ? LocalizationKey.forumCreatePostPublishing.localized : LocalizationKey.forumCreatePostPublishNow.localized)
                                .font(AppTypography.bodyBold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading || viewModel.isUploading || viewModel.title.isEmpty || viewModel.content.isEmpty || viewModel.selectedCategoryId == nil)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .padding(AppSpacing.md)
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            .navigationTitle(LocalizationKey.forumCreatePostTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                // 用户体验优化：视图消失时自动收起键盘
                // 使用系统方法隐藏键盘
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
            .onAppear {
                // 如果未登录，立即显示登录页面
                if !appState.isAuthenticated {
                    DispatchQueue.main.async {
                        showLogin = true
                    }
                }
                if viewModel.categories.isEmpty {
                    viewModel.loadCategories()
                }
            }
            .onChange(of: appState.isAuthenticated) { newValue in
                // 当用户登录成功后，如果之前显示的是登录页面，关闭它
                if newValue && showLogin {
                    showLogin = false
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    private func handleImageSelection() {
        Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        if viewModel.selectedImages.count < 5 {
                            viewModel.selectedImages.append(image)
                        }
                    }
                }
            }
            await MainActor.run {
                selectedItems = []
            }
        }
    }
}

