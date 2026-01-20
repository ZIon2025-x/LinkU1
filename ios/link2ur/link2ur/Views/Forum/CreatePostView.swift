import SwiftUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    
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
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                IconStyle.icon("paperplane.fill", size: 18)
                            }
                            Text(viewModel.isLoading ? LocalizationKey.forumCreatePostPublishing.localized : LocalizationKey.forumCreatePostPublishNow.localized)
                                .font(AppTypography.bodyBold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading || viewModel.title.isEmpty || viewModel.content.isEmpty || viewModel.selectedCategoryId == nil)
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
}

