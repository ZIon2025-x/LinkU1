import SwiftUI
import Combine

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var avatar: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    // 邮箱和手机号更新相关
    @State private var emailVerificationCode: String = ""
    @State private var phoneVerificationCode: String = ""
    @State private var isSendingEmailCode = false
    @State private var isSendingPhoneCode = false
    @State private var emailCountdown = 0
    @State private var phoneCountdown = 0
    @State private var showEmailCodeField = false
    @State private var showPhoneCodeField = false
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // 头像编辑区域
                        VStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: AppColors.primary.opacity(0.3), radius: 16, x: 0, y: 8)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 114, height: 114)
                                
                                AvatarView(
                                    urlString: avatar.isEmpty ? nil : avatar,
                                    size: 110,
                                    placeholder: Image(systemName: "person.fill")
                                )
                                
                                // 编辑按钮
                                Button {
                                    // TODO: 实现头像选择功能
                                } label: {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(AppColors.primary)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                }
                                .offset(x: 40, y: 40)
                            }
                            
                            Text("点击相机图标更换头像")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, AppSpacing.xl)
                        
                        // 表单
                        VStack(spacing: AppSpacing.lg) {
                            // 名字输入
                            EnhancedTextField(
                                title: "名字",
                                placeholder: "请输入名字",
                                text: $name,
                                icon: "person.fill",
                                errorMessage: nil
                            )
                            
                            // 邮箱输入
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                EnhancedTextField(
                                    title: "邮箱",
                                    placeholder: appState.currentUser?.email == nil ? "请输入邮箱" : "请输入新邮箱",
                                    text: $email,
                                    icon: "envelope.fill",
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress,
                                    autocapitalization: .never,
                                    errorMessage: nil
                                )
                                
                                if showEmailCodeField {
                                    HStack(spacing: AppSpacing.sm) {
                                        EnhancedTextField(
                                            title: "验证码",
                                            placeholder: "请输入验证码",
                                            text: $emailVerificationCode,
                                            icon: "key.fill",
                                            keyboardType: .numberPad,
                                            errorMessage: nil
                                        )
                                        
                                        Button {
                                            sendEmailUpdateCode()
                                        } label: {
                                            if isSendingEmailCode {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                            } else {
                                                Text(emailCountdown > 0 ? "\(emailCountdown)秒" : "发送验证码")
                                                    .font(AppTypography.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .frame(width: 100)
                                        .frame(height: 52)
                                        .foregroundColor(emailCountdown > 0 ? AppColors.textSecondary : AppColors.primary)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(emailCountdown > 0 ? AppColors.cardBackground : AppColors.primary.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .stroke(emailCountdown > 0 ? AppColors.separator.opacity(0.2) : AppColors.primary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .disabled(isSendingEmailCode || emailCountdown > 0 || email.isEmpty || email == (appState.currentUser?.email ?? ""))
                                    }
                                } else if email != (appState.currentUser?.email ?? "") && !email.isEmpty {
                                    Button {
                                        showEmailCodeField = true
                                    } label: {
                                        Text("发送验证码")
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                            
                            // 手机号输入
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                EnhancedTextField(
                                    title: "手机号",
                                    placeholder: appState.currentUser?.phone == nil ? "请输入手机号" : "请输入新手机号",
                                    text: $phone,
                                    icon: "phone.fill",
                                    keyboardType: .phonePad,
                                    textContentType: .telephoneNumber,
                                    errorMessage: nil
                                )
                                
                                if showPhoneCodeField {
                                    HStack(spacing: AppSpacing.sm) {
                                        EnhancedTextField(
                                            title: "验证码",
                                            placeholder: "请输入验证码",
                                            text: $phoneVerificationCode,
                                            icon: "key.fill",
                                            keyboardType: .numberPad,
                                            errorMessage: nil
                                        )
                                        
                                        Button {
                                            sendPhoneUpdateCode()
                                        } label: {
                                            if isSendingPhoneCode {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                            } else {
                                                Text(phoneCountdown > 0 ? "\(phoneCountdown)秒" : "发送验证码")
                                                    .font(AppTypography.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .frame(width: 100)
                                        .frame(height: 52)
                                        .foregroundColor(phoneCountdown > 0 ? AppColors.textSecondary : AppColors.primary)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(phoneCountdown > 0 ? AppColors.cardBackground : AppColors.primary.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .stroke(phoneCountdown > 0 ? AppColors.separator.opacity(0.2) : AppColors.primary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .disabled(isSendingPhoneCode || phoneCountdown > 0 || phone.isEmpty || phone == (appState.currentUser?.phone ?? ""))
                                    }
                                } else if phone != (appState.currentUser?.phone ?? "") && !phone.isEmpty {
                                    Button {
                                        showPhoneCodeField = true
                                    } label: {
                                        Text("发送验证码")
                                            .font(AppTypography.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                            }
                            
                            // 错误提示
                            if let errorMessage = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(AppColors.error)
                                    Text(errorMessage)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.error)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // 保存按钮
                            Button {
                                saveProfile()
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("保存")
                                            .font(AppTypography.bodyBold)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundColor(.white)
                                .background(
                                    ZStack {
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        
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
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.medium, useGradient: true, height: 56))
                            .disabled(isLoading)
                            .opacity(isLoading ? 0.5 : 1.0)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .navigationTitle("编辑个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("保存成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("个人资料已更新")
            }
            .onAppear {
                loadCurrentProfile()
            }
        }
    }
    
    private func loadCurrentProfile() {
        if let user = appState.currentUser {
            name = user.name
            email = user.email ?? ""
            phone = user.phone ?? ""
            avatar = user.avatar ?? ""
        }
    }
    
    private func sendEmailUpdateCode() {
        guard !email.isEmpty, email != (appState.currentUser?.email ?? "") else { return }
        
        isSendingEmailCode = true
        apiService.sendEmailUpdateCode(newEmail: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingEmailCode = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSendingEmailCode = false
                    self?.errorMessage = nil
                    self?.startEmailCountdown()
                }
            )
            .store(in: &cancellables)
    }
    
    private func sendPhoneUpdateCode() {
        guard !phone.isEmpty, phone != (appState.currentUser?.phone ?? "") else { return }
        
        isSendingPhoneCode = true
        apiService.sendPhoneUpdateCode(newPhone: phone)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSendingPhoneCode = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSendingPhoneCode = false
                    self?.errorMessage = nil
                    self?.startPhoneCountdown()
                }
            )
            .store(in: &cancellables)
    }
    
    private func startEmailCountdown() {
        emailCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if emailCountdown > 0 {
                emailCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startPhoneCountdown() {
        phoneCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if phoneCountdown > 0 {
                phoneCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        var body: [String: Any] = [:]
        if name != (appState.currentUser?.name ?? "") {
            body["name"] = name
        }
        let currentEmail = appState.currentUser?.email ?? ""
        if email != currentEmail {
            if !email.isEmpty {
                body["email"] = email
                if !emailVerificationCode.isEmpty {
                    body["email_verification_code"] = emailVerificationCode
                }
            } else if !currentEmail.isEmpty {
                // 清空邮箱（解绑）
                body["email"] = ""
            }
        }
        let currentPhone = appState.currentUser?.phone ?? ""
        if phone != currentPhone {
            if !phone.isEmpty {
                body["phone"] = phone
                if !phoneVerificationCode.isEmpty {
                    body["phone_verification_code"] = phoneVerificationCode
                }
            } else if !currentPhone.isEmpty {
                // 清空手机号（解绑）
                body["phone"] = ""
            }
        }
        
        apiService.request(User.self, "/api/users/profile", method: "PATCH", body: body)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] updatedUser in
                    self?.isLoading = false
                    // 更新AppState中的用户信息
                    self?.appState.currentUser = updatedUser
                    self?.showSuccessAlert = true
                }
            )
            .store(in: &cancellables)
    }
}

