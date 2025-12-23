import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject public var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showPassword = false
    @State private var showCaptcha = false  // 显示 CAPTCHA 验证界面
    @State private var showTerms = false  // 显示用户协议
    @State private var showPrivacy = false  // 显示隐私政策
    @FocusState private var focusedField: Field?
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var backgroundOffset: CGFloat = 0
    
    enum Field {
        case email
        case password
        case phone
        case verificationCode
    }
    
    public var body: some View {
        ZStack {
            // 现代渐变背景（更丰富的多层渐变）
            ZStack {
                // 主渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.primary.opacity(0.12),
                        AppColors.primary.opacity(0.06),
                        AppColors.primary.opacity(0.02),
                        AppColors.background
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 动态装饰性圆形背景（添加轻微动画）
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.primary.opacity(0.08),
                                AppColors.primary.opacity(0.02),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -180, y: -350)
                    .blur(radius: 20)
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.primary.opacity(0.06),
                                AppColors.primary.opacity(0.01),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: 220, y: 450)
                    .blur(radius: 15)
                
                // 添加第三个装饰圆形
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.primary.opacity(0.04),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: 0, y: -100)
                    .blur(radius: 10)
            }
            
            ZStack {
                KeyboardAvoidingScrollView(showsIndicators: false, extraPadding: 20) {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo 区域 - 精美设计，带动画效果
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            // 外圈光晕效果
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            AppColors.primary.opacity(0.15),
                                            AppColors.primary.opacity(0.05),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 40,
                                        endRadius: 70
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .blur(radius: 8)
                            
                            // 渐变背景圆圈（更精致）
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                            
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 75, height: 75)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: logoScale)
                        .animation(.easeOut(duration: 0.8), value: logoOpacity)
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text(LocalizationKey.appName.localized)
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                                .opacity(logoOpacity)
                                .offset(y: logoOpacity == 0 ? 10 : 0)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: logoOpacity)
                            
                            Text(LocalizationKey.appTagline.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .opacity(logoOpacity)
                                .offset(y: logoOpacity == 0 ? 10 : 0)
                                .animation(.easeOut(duration: 0.8).delay(0.3), value: logoOpacity)
                        }
                    }
                    .padding(.bottom, AppSpacing.lg)
                    
                    // Face ID 登录按钮（如果支持且已保存凭据）
                    if viewModel.canUseBiometric && BiometricAuth.shared.isBiometricLoginEnabled() {
                        Button(action: {
                            viewModel.loginWithBiometric { success in
                                if success {
                                    withAnimation(.spring(response: 0.5)) {
                                        appState.isAuthenticated = true
                                        dismiss()
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: viewModel.biometricType == .faceID ? "faceid" : "touchid")
                                    .font(.system(size: 20, weight: .medium))
                                
                                Text("使用 \(viewModel.biometricType.displayName) 登录")
                                    .font(AppTypography.body)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppCornerRadius.medium)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(logoOpacity)
                        .offset(y: logoOpacity == 0 ? 10 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: logoOpacity)
                        
                        // 分隔线
                        HStack {
                            Rectangle()
                                .fill(AppColors.separator.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("或")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                            
                            Rectangle()
                                .fill(AppColors.separator.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
                        .opacity(logoOpacity)
                        .offset(y: logoOpacity == 0 ? 10 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.45), value: logoOpacity)
                    }
                    
                    // 登录方式切换 - 美化设计
                    Picker(LocalizationKey.authLoginMethod.localized, selection: $viewModel.loginMethod) {
                        Text(LocalizationKey.authEmailPassword.localized).tag(AuthViewModel.LoginMethod.password)
                        Text(LocalizationKey.authEmailCode.localized).tag(AuthViewModel.LoginMethod.emailCode)
                        Text(LocalizationKey.authPhoneCode.localized).tag(AuthViewModel.LoginMethod.phone)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                    .opacity(logoOpacity)
                    .offset(y: logoOpacity == 0 ? 10 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: logoOpacity)
                    .onChange(of: viewModel.loginMethod) { newMethod in
                        // 切换登录方式时清空错误消息和输入框
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.errorMessage = nil
                            // 切换登录方式时重置协议同意状态（验证码登录需要，密码登录不需要）
                            if newMethod == .password {
                                viewModel.agreedToTerms = false
                            }
                            switch newMethod {
                            case .password:
                                viewModel.phone = ""
                                viewModel.verificationCode = ""
                                viewModel.countryCode = "+44"
                            case .emailCode:
                                viewModel.password = ""
                                viewModel.phone = ""
                                viewModel.countryCode = "+44"
                            case .phone:
                                viewModel.email = ""
                                viewModel.password = ""
                            }
                        }
                    }
                    
                    // 登录表单 - 符合 HIG
                    VStack(spacing: AppSpacing.lg) {
                        if viewModel.loginMethod == .phone {
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
                                            Button {
                                                withAnimation {
                                                    viewModel.countryCode = code
                                                }
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Text(emoji)
                                                        .font(.system(size: 24))
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(name)
                                                            .font(AppTypography.body)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(AppColors.textPrimary)
                                                        Text(code)
                                                            .font(AppTypography.caption)
                                                            .foregroundColor(AppColors.textSecondary)
                                                    }
                                                    Spacer()
                                                }
                                                .frame(minWidth: 200)
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
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            AppColors.separator.opacity(0.4),
                                                            AppColors.separator.opacity(0.2)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
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
                                
                                // 发送验证码按钮 - 美化设计
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
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(width: 100)
                                .frame(height: 52)
                                .foregroundColor(viewModel.canResendCode ? AppColors.primary : AppColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .fill(viewModel.canResendCode ? AppColors.primary.opacity(0.12) : AppColors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(
                                                    viewModel.canResendCode ? AppColors.primary.opacity(0.3) : AppColors.separator.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .shadow(color: viewModel.canResendCode ? AppColors.primary.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
                                .disabled(!viewModel.canResendCode || viewModel.isSendingCode || viewModel.phone.isEmpty)
                            }
                            
                            // 用户协议同意复选框 - 验证码登录需要
                            HStack(spacing: AppSpacing.sm) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.agreedToTerms.toggle()
                                    }
                                }) {
                                    Image(systemName: viewModel.agreedToTerms ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundColor(viewModel.agreedToTerms ? AppColors.primary : AppColors.textSecondary)
                                }
                                
                                HStack(spacing: 4) {
                                    Text(LocalizationKey.authAgreeToTerms.localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    // 用户协议链接
                                    Button(action: {
                                        // 在应用内打开用户协议
                                        showTerms = true
                                    }) {
                                        Text(LocalizationKey.authTermsOfService.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                            .underline()
                                    }
                                    
                                    Text("、")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    // 隐私政策链接
                                    Button(action: {
                                        // 在应用内打开隐私政策
                                        showPrivacy = true
                                    }) {
                                        Text(LocalizationKey.authPrivacyPolicy.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                            .underline()
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.top, AppSpacing.sm)
                            
                            // 登录按钮 - 精美设计
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
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(
                                    ZStack {
                                        // 主渐变
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        
                                        // 高光效果
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                                .shadow(color: AppColors.primary.opacity(0.1), radius: 20, x: 0, y: 10)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 56))
                            .disabled(viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms)
                            .opacity((viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms) ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || viewModel.phone.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms)
                        } else if viewModel.loginMethod == .emailCode {
                            // 邮箱验证码登录
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
                                    focusedField = .verificationCode
                                }
                            )
                            .id("emailField")
                            
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
                                        if !viewModel.email.isEmpty && !viewModel.verificationCode.isEmpty {
                                            hideKeyboard()
                                            viewModel.loginWithEmailCode { success in
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
                                
                                // 发送验证码按钮 - 美化设计
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
                                        sendEmailCode()
                                    }
                                }) {
                                    if viewModel.isSendingCode {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                    } else {
                                        Text(viewModel.canResendCode ? LocalizationKey.authSendCode.localized : "\(viewModel.countdownSeconds)秒")
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(width: 100)
                                .frame(height: 52)
                                .foregroundColor(viewModel.canResendCode ? AppColors.primary : AppColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .fill(viewModel.canResendCode ? AppColors.primary.opacity(0.12) : AppColors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(
                                                    viewModel.canResendCode ? AppColors.primary.opacity(0.3) : AppColors.separator.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .shadow(color: viewModel.canResendCode ? AppColors.primary.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
                                .disabled(!viewModel.canResendCode || viewModel.isSendingCode || viewModel.email.isEmpty)
                            }
                            
                            // 用户协议同意复选框 - 验证码登录需要
                            HStack(spacing: AppSpacing.sm) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.agreedToTerms.toggle()
                                    }
                                }) {
                                    Image(systemName: viewModel.agreedToTerms ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundColor(viewModel.agreedToTerms ? AppColors.primary : AppColors.textSecondary)
                                }
                                
                                HStack(spacing: 4) {
                                    Text(LocalizationKey.authAgreeToTerms.localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    // 用户协议链接
                                    Button(action: {
                                        // 在应用内打开用户协议
                                        showTerms = true
                                    }) {
                                        Text(LocalizationKey.authTermsOfService.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                            .underline()
                                    }
                                    
                                    Text("、")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    // 隐私政策链接
                                    Button(action: {
                                        // 在应用内打开隐私政策
                                        showPrivacy = true
                                    }) {
                                        Text(LocalizationKey.authPrivacyPolicy.localized)
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                            .underline()
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.top, AppSpacing.sm)
                            
                            // 登录按钮 - 精美设计
                            Button(action: {
                                hideKeyboard()
                                viewModel.loginWithEmailCode { success in
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
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(
                                    ZStack {
                                        // 主渐变
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        
                                        // 高光效果
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                                .shadow(color: AppColors.primary.opacity(0.1), radius: 20, x: 0, y: 10)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 56))
                            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms)
                            .opacity((viewModel.isLoading || viewModel.email.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms) ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || viewModel.email.isEmpty || viewModel.verificationCode.isEmpty || !viewModel.agreedToTerms)
                        } else {
                            // 邮箱/ID密码登录
                            // 邮箱或ID输入
                            EnhancedTextField(
                                title: LocalizationKey.authEmailOrId.localized,
                                placeholder: LocalizationKey.authEnterEmailOrId.localized,
                                text: $viewModel.email,
                                icon: "person.fill",
                                keyboardType: .default,
                                textContentType: .username,
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
                            
                            // 登录按钮 - 精美设计
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
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(
                                    ZStack {
                                        // 主渐变
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        
                                        // 高光效果
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    }
                                )
                                .cornerRadius(AppCornerRadius.medium)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                                .shadow(color: AppColors.primary.opacity(0.1), radius: 20, x: 0, y: 10)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 56))
                            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                            .opacity((viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty) ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                        }
                        
                        // 提示文本 - 符合 HIG，美化设计
                        HStack(spacing: AppSpacing.xs) {
                            Text(LocalizationKey.authNoAccount.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(LocalizationKey.authNoAccountUseCode.localized)
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.large)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                            .shadow(color: AppColors.primary.opacity(0.05), radius: 30, x: 0, y: 15)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .opacity(logoOpacity)
                    .offset(y: logoOpacity == 0 ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: logoOpacity)
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
            }
            .fullScreenCover(isPresented: $showCaptcha) {
                captchaView
            }
            .sheet(isPresented: $showTerms) {
                TermsWebView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyWebView()
            }
        }
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            // 启动动画
            withAnimation {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
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
    
    /// 发送邮箱验证码（在 CAPTCHA 验证成功后调用）
    private func sendEmailCode() {
        viewModel.sendEmailCode { success, message in
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
                                    if viewModel.loginMethod == .phone {
                                        sendPhoneCode()
                                    } else if viewModel.loginMethod == .emailCode {
                                        sendEmailCode()
                                    }
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
