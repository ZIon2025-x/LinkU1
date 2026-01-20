import SwiftUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("帖子标题 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入标题", text: $viewModel.title)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 分类选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择板块 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Picker("选择板块", selection: $viewModel.selectedCategoryId) {
                            Text("请选择板块").tag(nil as Int?)
                            ForEach(viewModel.categories) { category in
                                Text(category.displayName).tag(category.id as Int?)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("帖子内容 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $viewModel.content)
                            .frame(height: 200)
                            .padding(8)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // 错误提示
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 发布按钮
                    Button(action: {
                        viewModel.createPost { success in
                            if success {
                                dismiss()
                            }
                        }
                    }) {
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
                        LinearGradient(
                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.medium)
                    .disabled(viewModel.isLoading)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.background)
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
                if viewModel.categories.isEmpty {
                    viewModel.loadCategories()
                }
            }
        }
    }
}

