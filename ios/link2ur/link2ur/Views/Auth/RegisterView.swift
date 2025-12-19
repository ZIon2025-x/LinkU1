import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        ZStack {
            // 现代渐变背景（与登录页一致）
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.08),
                    AppColors.primary.opacity(0.03),
                    AppColors.background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 装饰性圆形背景
            Circle()
                .fill(AppColors.primary.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: -150, y: -300)
            
            Circle()
                .fill(AppColors.primary.opacity(0.03))
                .frame(width: 200, height: 200)
                .offset(x: 200, y: 400)
            
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Logo 区域 - 与登录页一致
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            // 渐变背景圆圈
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                        }
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("创建账户")
                                .font(AppTypography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("加入 Link²Ur，开启新体验")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.bottom, AppSpacing.lg)
                    
                    // 注册表单 - 符合 HIG
                    VStack(spacing: AppSpacing.lg) {
                        // 用户名输入
                        EnhancedTextField(
                            title: "用户名",
                            placeholder: "请输入用户名",
                            text: $viewModel.registerName,
                            icon: "person.fill",
                            autocapitalization: .never,
                            isRequired: true
                        )
                        .id("nameField")
                        
                        // 邮箱输入
                        EnhancedTextField(
                            title: "邮箱",
                            placeholder: "请输入邮箱",
                            text: $viewModel.registerEmail,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            isRequired: true
                        )
                        .id("emailField")
                        
                        // 密码输入
                        EnhancedTextField(
                            title: "密码",
                            placeholder: "请输入密码",
                            text: $viewModel.registerPassword,
                            icon: "lock.fill",
                            isSecure: true,
                            showPasswordToggle: true,
                            helperText: "至少8个字符，包含字母和数字",
                            isRequired: true
                        )
                        .id("passwordField")
                        
                        // 手机号输入（可选）
                        EnhancedTextField(
                            title: "手机号",
                            placeholder: "请输入手机号",
                            text: $viewModel.registerPhone,
                            icon: "phone.fill",
                            keyboardType: .phonePad,
                            textContentType: .telephoneNumber
                        )
                        .id("phoneField")
                        
                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: AppSpacing.sm) {
                                IconStyle.icon("exclamationmark.circle.fill", size: IconStyle.small)
                                    .foregroundColor(AppColors.error)
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // 注册按钮 - 更现代的设计（带渐变）
                        Button(action: {
                            hideKeyboard()
                            viewModel.register { success, message in
                                if success {
                                    successMessage = message ?? "注册成功！"
                                    showSuccessAlert = true
                                }
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("注册")
                                        .font(AppTypography.bodyBold)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large, useGradient: true))
                        .disabled(viewModel.isLoading || viewModel.registerName.isEmpty || viewModel.registerEmail.isEmpty || viewModel.registerPassword.isEmpty)
                        .opacity((viewModel.isLoading || viewModel.registerName.isEmpty || viewModel.registerEmail.isEmpty || viewModel.registerPassword.isEmpty) ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.isLoading || viewModel.registerName.isEmpty || viewModel.registerEmail.isEmpty || viewModel.registerPassword.isEmpty)
                        
                        // 登录链接 - 符合 HIG
                        HStack {
                            Text("已有账户？")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Button("立即登录") {
                                dismiss()
                            }
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .cardStyle(cornerRadius: AppCornerRadius.xlarge, shadow: AppShadow.medium)
                    .padding(.horizontal, AppSpacing.md)
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            .contentShape(Rectangle()) // 确保整个区域可点击
    }
}

