import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject public var appState: AppState
    @State private var showPassword = false
    
    public var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.1),
                    AppColors.background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo 区域
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        Text("LinkU")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("连接你我，创造价值")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.bottom, 20)
                    
                    // 登录表单
                    VStack(spacing: 20) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邮箱")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 20)
                                
                                TextField("请输入邮箱", text: $viewModel.email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textContentType(.emailAddress)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 20)
                                
                                if showPassword {
                                    TextField("请输入密码", text: $viewModel.password)
                                } else {
                                    SecureField("请输入密码", text: $viewModel.password)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 登录按钮
                        Button(action: {
                            hideKeyboard()
                            viewModel.login { success in
                                if success {
                                    appState.isAuthenticated = true
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("登录")
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
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                        .opacity((viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty) ? 0.6 : 1.0)
                        
                        // 注册链接
                        HStack {
                            Text("还没有账号？")
                                .foregroundColor(AppColors.textSecondary)
                            
                            NavigationLink(destination: RegisterView()) {
                                Text("立即注册")
                                    .foregroundColor(AppColors.primary)
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                    .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
                    .padding(.horizontal, AppSpacing.md)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
