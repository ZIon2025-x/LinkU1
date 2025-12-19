import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Logo或标题
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.primary)
                    
                    Text("创建账户")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.top, AppSpacing.xl)
                
                // 表单
                VStack(spacing: AppSpacing.md) {
                    // 用户名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用户名 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入用户名", text: $viewModel.registerName)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
                    // 邮箱
                    VStack(alignment: .leading, spacing: 8) {
                        Text("邮箱 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入邮箱", text: $viewModel.registerEmail)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    // 密码
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密码 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        SecureField("请输入密码", text: $viewModel.registerPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 手机号（可选）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("手机号（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入手机号", text: $viewModel.registerPhone)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                    
                    // 错误提示
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 注册按钮
                    Button(action: {
                        viewModel.register { success, message in
                            if success {
                                successMessage = message ?? "注册成功！"
                                showSuccessAlert = true
                            }
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("注册")
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
                    .padding(.top, AppSpacing.md)
                    
                    // 登录链接
                    HStack {
                        Text("已有账户？")
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button("立即登录") {
                            dismiss()
                        }
                        .foregroundColor(AppColors.primary)
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .alert("注册成功", isPresented: $showSuccessAlert) {
            Button("确定") {
                if successMessage.contains("验证") {
                    // 需要邮箱验证，返回登录页
                    dismiss()
                } else {
                    // 不需要验证，已自动登录，关闭注册页
                    dismiss()
                }
            }
        } message: {
            Text(successMessage)
        }
    }
}

// 自定义文本输入框样式
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
            )
    }
}

