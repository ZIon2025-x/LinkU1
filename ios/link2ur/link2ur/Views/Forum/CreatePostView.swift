import SwiftUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: AppSpacing.lg) {
                    // 标题
                    EnhancedTextField(
                        title: "帖子标题",
                        placeholder: "请输入标题",
                        text: $viewModel.title,
                        icon: "text.bubble.fill",
                        isRequired: true
                    )
                    
                    // 分类选择
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("选择板块")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Text("*")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.error)
                        }
                        
                        Picker("选择板块", selection: $viewModel.selectedCategoryId) {
                            Text("请选择板块").tag(nil as Int?)
                            ForEach(viewModel.categories) { category in
                                Text(category.name).tag(category.id as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // 内容
                    EnhancedTextEditor(
                        title: "帖子内容",
                        placeholder: "请输入帖子内容",
                        text: $viewModel.content,
                        height: 200,
                        isRequired: true,
                        characterLimit: 2000
                    )
                    
                    // 错误提示
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: AppSpacing.xs) {
                            IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                                .foregroundColor(AppColors.error)
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.error)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 发布按钮
                    Button(action: {
                        print("🔘 发布按钮被点击")
                        if appState.isAuthenticated {
                            print("✅ 用户已登录，开始发布帖子")
                            viewModel.createPost { success in
                                print("📝 发布结果: \(success)")
                                if success {
                                    dismiss()
                                }
                            }
                        } else {
                            print("⚠️ 用户未登录，显示登录页面")
                            showLogin = true
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("发布")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            Group {
                                if viewModel.isLoading {
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.primary.opacity(0.6), AppColors.primary.opacity(0.4)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(AppCornerRadius.medium)
                    }
                    .disabled(viewModel.isLoading)
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(AppSpacing.md)
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("发布帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
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
}

