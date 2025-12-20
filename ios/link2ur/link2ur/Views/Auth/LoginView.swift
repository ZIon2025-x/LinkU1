import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject public var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showPassword = false
    @State private var showCaptcha = false  // 显示 CAPTCHA 验证界面
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
        case phone
        case verificationCode
    }
    
    public var body: some View {
        ZStack {
            // 现代渐变背景（更柔和的渐变）
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
            
            ZStack {
                KeyboardAvoidingScrollView(showsIndicators: false, extraPadding: 20) {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo 区域 - 现代简洁设计
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            // 渐变背景圆圈（更柔和）
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: AppColors.primary.opacity(0.2), radius: 16, x: 0, y: 8)
                            
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                        }
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text(LocalizationKey.appName.localized)
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(LocalizationKey.appTagline.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.bottom, AppSpacing.lg)
                    
                    // 登录方式切换
                    Picker(LocalizationKey.authLoginMethod.localized, selection: $viewModel.isPhoneLogin) {
                        Text(LocalizationKey.authEmailPassword.localized).tag(false)
                        Text(LocalizationKey.authPhoneCode.localized).tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                    .onChange(of: viewModel.isPhoneLogin) { _ in
                        // 切换登录方式时清空错误消息和输入框
                        viewModel.errorMessage = nil
                        if viewModel.isPhoneLogin {
                            viewModel.email = ""
                            viewModel.password = ""
                        } else {
                            viewModel.phone = ""
                            viewModel.verificationCode = ""
                            viewModel.countryCode = "+44"  // 重置为默认区号
                        }
                    }
                    
                    // 登录表单 - 符合 HIG
                    VStack(spacing: AppSpacing.lg) {
                        if viewModel.isPhoneLogin {
                            // 手机验证码登录
                            // 区号和手机号输入
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text(LocalizationKey.authPhone.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: AppSpacing.sm) {
                                    // 区号选择器
                                    Menu {
                                        ForEach(viewModel.supportedCountryCodes, id: \.1) { emoji, code, name in
                                            Button(action: {
                                                withAnimation {
                                                    viewModel.countryCode = code
                                                }
                                            }) {
                                                HStack {
                                                    Text(emoji)
                                                        .font(.system(size: 20))
                                                    Text(code)
                                                        .font(AppTypography.body)
                                                    Spacer()
                                                    Text(name)
                                                        .font(AppTypography.caption)
                                                        .foregroundColor(AppColors.textSecondary)
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(viewModel.supportedCountryCodes.first(where: { $0.1 == viewModel.countryCode })?.0 ?? "🇬🇧")
                                                .font(.system(size: 18))
                                            Text(viewModel.countryCode)
                                                .font(AppTypography.body)
                                                .foregroundColor(AppColors.textPrimary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.md)
                                        .frame(minWidth: 85)
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(AppCornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    
                                    // 手机号输入
                                    EnhancedTextField(
                                        title: nil,
                                        placeholder: LocalizationKey.authEnterPhone.localized,
                                        text: $viewModel.phone,
                                        icon: "phone.fill",
                                        keyboardType: .phonePad,
                                        textContentType: .telephoneNumber,
                                        autocapitalization: .never,
                                        errorMessage: viewModel.errorMessage,
                                        onSubmit: {
                                            focusedField = .verificationCode
                                        }
                                    )
                                }
                            }
                            .id("phoneField")
                            
                            // 验证码输入和发送按钮
                            HStack(spacing: AppSpacing.sm) {
                                EnhancedTextField(
                                    title: LocalizationKey.authVerificationCode.localized,
                                    placeholder: LocalizationKey.authEnterCode.localized,
                                    text: $viewModel.verificationCode,
                                    icon: "key.fill",
                                    keyboardType: .numberPad,
                                    textContentType: .oneTimeCode,
                                    autocapitalization: .never,
                                    errorMessage: nil,
                                    onSubmit: {
                                        if !viewModel.phone.isEmpty && !viewModel.verificationCode.isEmpty {
                                            hideKeyboard()
                                            viewModel.loginWithPhone { success in
                                                if success {
                                                    withAnimation(.spring(response: 0.5)) {
                                                        appState.isAuthenticated = true
                                                        dismiss()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                )
                                .id("verificationCodeField")
                                .onChange(of: viewModel.verificationCode) { newValue in
                                    // 只允许数字，过滤掉所有非数字字符
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        viewModel.verificationCode = filtered
                                    }
                                }
                                
                                // 发送验证码按钮
                                Button(action: {
                                    hideKeyboard()
                                    // 如果 CAPTCHA 启用且还没有 token，先显示验证界面
                                    if viewModel.captchaEnabled && viewModel.captchaToken == nil {
                                        if viewModel.captchaSiteKey != nil && viewModel.captchaType != nil {
                                            showCaptcha = true
                                        } else {
                                            // 如果还没有获取到 site key，先获取配置
                                            viewModel.checkCaptchaConfig()
                                            // 等待一下再显示（实际应该用更好的方式处理）
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                if viewModel.captchaSiteKey != nil && viewModel.captchaType != nil {
                                                    showCaptcha = true
                                                } else {
                                                    viewModel.errorMessage = LocalizationKey.authCaptchaError.localized
                                                }
                                            }
                                        }
                                    } else {
                                        // CAPTCHA 未启用或已有 token，直接发送验证码
                                        sendPhoneCode()
                                    }
                                }) {
                                    if viewModel.isSendingCode {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                    } else {
                                        Text(viewModel.canResendCode ? LocalizationKey.authSendCode.localized : "\(viewModel.countdownSeconds)秒")
                                            .font(AppTypography.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                .frame(width: 100)
                                .frame(height: 52)
                                .foregroundColor(viewModel.canResendCode ? AppColors.primary : AppColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .fill(viewModel.canResendCode ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
                                )
                                .disabled(!viewModel.canResendCode || viewModel.isSendingCode || viewModel.phone.isEmpty)
                            }
                            
                            // 登录按钮
                            Button(action: {
                                hideKeyboard()
                                viewModel.loginWithPhone { success in
                                    if success {
                                        withAnimation(.spring(response: 0.5)) {
                                            appState.isAuthenticated = true
                                            dismiss()
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("登录")
                                            .font(AppTypography.bodyBold)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.25), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 52))
                            .disabled(viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty)
                            .opacity((viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty) ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty)
                        } else {
                            // 邮箱密码登录
                            // 邮箱输入
                            EnhancedTextField(
                                title: LocalizationKey.authEmail.localized,
                                placeholder: LocalizationKey.authEnterEmail.localized,
                                text: $viewModel.email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress,
                                autocapitalization: .never,
                                errorMessage: viewModel.errorMessage,
                                onSubmit: {
                                    focusedField = .password
                                }
                            )
                            .id("emailField")
                            
                            // 密码输入
                            EnhancedTextField(
                                title: LocalizationKey.authPassword.localized,
                                placeholder: LocalizationKey.authEnterPassword.localized,
                                text: $viewModel.password,
                                icon: "lock.fill",
                                isSecure: true,
                                showPasswordToggle: true,
                                errorMessage: nil,
                                onSubmit: {
                                    if !viewModel.email.isEmpty && !viewModel.password.isEmpty {
                                        hideKeyboard()
                                        viewModel.login { success in
                                            if success {
                                                withAnimation(.spring(response: 0.5)) {
                                                    appState.isAuthenticated = true
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }
                                }
                            )
                            .id("passwordField")
                            
                            // 登录按钮
                            Button(action: {
                                hideKeyboard()
                                viewModel.login { success in
                                    if success {
                                        withAnimation(.spring(response: 0.5)) {
                                            appState.isAuthenticated = true
                                            dismiss()
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(LocalizationKey.authLogin.localized)
                                            .font(AppTypography.bodyBold)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundColor(.white)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.25), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 52))
                            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                            .opacity((viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty) ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                        }
                        
                        // 注册链接 - 符合 HIG
                        HStack {
                            Text(LocalizationKey.authNoAccount.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            NavigationLink(destination: RegisterView()) {
                                Text(LocalizationKey.authRegisterNow.localized)
                                    .font(AppTypography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .cardStyle(cornerRadius: AppCornerRadius.large, shadow: AppShadow.small)
                    .padding(.horizontal, AppSpacing.md)
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
            }
            .fullScreenCover(isPresented: $showCaptcha) {
                captchaView
            }
        }
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 发送手机验证码（在 CAPTCHA 验证成功后调用）
    private func sendPhoneCode() {
        viewModel.sendPhoneCode { success, message in
            if success {
                // 验证码发送成功
            }
        }
    }
    
    /// CAPTCHA 验证界面
    @ViewBuilder
    private var captchaView: some View {
        if showCaptcha, let siteKey = viewModel.captchaSiteKey, let type = viewModel.captchaType {
            NavigationView {
                ZStack {
                    AppColors.background
                        .ignoresSafeArea()
                    
                    VStack(spacing: AppSpacing.lg) {
                        Text(LocalizationKey.authCaptchaMessage.localized)
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.top, AppSpacing.xl)
                        
                        CaptchaWebView(
                            siteKey: siteKey,
                            captchaType: type,
                            onVerify: { token in
                                // 验证成功，保存 token 并发送验证码
                                viewModel.captchaToken = token
                                showCaptcha = false
                                // 延迟一下再发送，确保token已保存
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    sendPhoneCode()
                                }
                            },
                            onError: { error in
                                viewModel.errorMessage = error
                                showCaptcha = false
                            }
                        )
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppSpacing.md)
                        .clipped()  // 防止内容溢出导致NaN
                        
                        Spacer()
                    }
                }
                .navigationTitle(LocalizationKey.authCaptchaTitle.localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(LocalizationKey.commonCancel.localized) {
                            showCaptcha = false
                        }
                    }
                }
            }
        }
    }
}
