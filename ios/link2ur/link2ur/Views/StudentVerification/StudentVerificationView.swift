import SwiftUI
import Combine

struct StudentVerificationView: View {
    @StateObject private var viewModel = StudentVerificationViewModel()
    @State private var showingSubmitSheet = false
    @State private var showingRenewSheet = false
    @State private var showingChangeEmailSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if viewModel.isLoading && viewModel.verificationStatus == nil {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, AppSpacing.xl)
                        } else if let status = viewModel.verificationStatus {
                            // Status Card
                            StatusCardView(status: status)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.top, AppSpacing.md)
                            
                            // Actions
                            if status.isVerified {
                                // Verified State
                                VStack(spacing: AppSpacing.md) {
                                    if status.canRenew == true {
                                        Button(action: {
                                            showingRenewSheet = true
                                        }) {
                                            HStack {
                                                IconStyle.icon("arrow.clockwise", size: IconStyle.medium)
                                                Text("续期认证")
                                                    .font(AppTypography.bodyBold)
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, AppSpacing.md)
                                            .background(AppColors.primary)
                                            .cornerRadius(AppCornerRadius.large)
                                        }
                                        .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large))
                                    }
                                    
                                    if status.emailLocked != true {
                                        Button(action: {
                                            showingChangeEmailSheet = true
                                        }) {
                                            HStack {
                                                IconStyle.icon("envelope", size: IconStyle.medium)
                                                Text("更换邮箱")
                                                    .font(AppTypography.bodyBold)
                                            }
                                            .foregroundColor(AppColors.primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, AppSpacing.md)
                                            .background(AppColors.primaryLight)
                                            .cornerRadius(AppCornerRadius.large)
                                        }
                                        .buttonStyle(SecondaryButtonStyle(cornerRadius: AppCornerRadius.large))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            } else {
                                // Not Verified State
                                Button(action: {
                                    showingSubmitSheet = true
                                }) {
                                    HStack {
                                        IconStyle.icon("checkmark.shield.fill", size: IconStyle.medium)
                                        Text("提交认证")
                                            .font(AppTypography.bodyBold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(AppColors.success)
                                    .cornerRadius(AppCornerRadius.large)
                                }
                                .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large))
                                .padding(.horizontal, AppSpacing.md)
                            }
                        } else {
                            // No Status - Empty State
                            VStack(spacing: AppSpacing.xl) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    AppColors.primary.opacity(0.2),
                                                    AppColors.primary.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 120, height: 120)
                                    
                                    IconStyle.icon("person.badge.shield.checkmark", size: IconStyle.xlarge)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                VStack(spacing: AppSpacing.sm) {
                                    Text("学生认证")
                                        .font(AppTypography.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text("验证您的学生身份以享受学生专属优惠")
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, AppSpacing.xl)
                                }
                                
                                Button(action: {
                                    showingSubmitSheet = true
                                }) {
                                    HStack {
                                        IconStyle.icon("arrow.right", size: IconStyle.medium)
                                        Text("开始认证")
                                            .font(AppTypography.bodyBold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.xl)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(AppColors.success)
                                    .cornerRadius(AppCornerRadius.large)
                                }
                                .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large))
                            }
                            .padding(.top, AppSpacing.xxl)
                        }
                    }
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("学生认证")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadStatus()
            }
            .onAppear {
                if viewModel.verificationStatus == nil {
                    viewModel.loadStatus()
                }
            }
            .sheet(isPresented: $showingSubmitSheet) {
                SubmitVerificationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingRenewSheet) {
                RenewVerificationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingChangeEmailSheet) {
                ChangeEmailView(viewModel: viewModel)
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

struct StatusCardView: View {
    let status: StudentVerificationStatusData
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Header
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    status.isVerified ? AppColors.success : AppColors.warning,
                                    (status.isVerified ? AppColors.success : AppColors.warning).opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(
                            color: (status.isVerified ? AppColors.success : AppColors.warning).opacity(0.3),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                    
                    IconStyle.icon(
                        status.isVerified ? "checkmark.shield.fill" : "shield.slash.fill",
                        size: IconStyle.xlarge
                    )
                    .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(status.isVerified ? "已认证" : "未认证")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let university = status.university {
                        Text(university.name)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            if status.isVerified {
                Divider()
                
                // Details
                VStack(spacing: AppSpacing.md) {
                    if let email = status.email {
                        DetailRow(icon: "envelope.fill", label: "认证邮箱", value: email, color: .blue)
                    }
                    
                    if let verifiedAt = status.verifiedAt {
                        DetailRow(icon: "calendar", label: "认证时间", value: verifiedAt, color: .green)
                    }
                    
                    if let expiresAt = status.expiresAt {
                        DetailRow(icon: "clock.fill", label: "到期时间", value: expiresAt, color: .orange)
                    }
                    
                    if let daysRemaining = status.daysRemaining {
                        DetailRow(
                            icon: "hourglass",
                            label: "剩余天数",
                            value: "\(daysRemaining) 天",
                            color: daysRemaining < 30 ? .red : .blue
                        )
                    }
                }
            } else if let statusText = status.status {
                HStack {
                    IconStyle.icon("info.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.warning)
                    Text("状态: \(statusText)")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.lg)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                IconStyle.icon(icon, size: IconStyle.small)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(value)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
    }
}

struct SubmitVerificationView: View {
    @ObservedObject var viewModel: StudentVerificationViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 邮箱信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "邮箱信息", icon: "envelope.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: "学校邮箱",
                                    placeholder: "请输入您的 .ac.uk 或 .edu 邮箱",
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text("说明: 请输入您的学校邮箱地址，我们将发送验证邮件到该邮箱。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 提交按钮
                        Button(action: {
                            HapticFeedback.success()
                            submit()
                        }) {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("paperplane.fill", size: 18)
                                }
                                Text(isSubmitting ? "正在提交..." : "发送验证邮件")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isSubmitting || email.isEmpty)
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("提交认证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: Binding(
                get: { submitError != nil },
                set: { if !$0 { submitError = nil } }
            )) {
                Button("确定", role: .cancel) {
                    submitError = nil
                }
            } message: {
                if let error = submitError {
                    Text(error)
                }
            }
        }
    }
    
    private func submit() {
        guard !email.isEmpty else { return }
        
        isSubmitting = true
        submitError = nil
        
        viewModel.submitVerification(email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSubmitting = false
                    if case .failure(let error) = completion {
                        submitError = error.localizedDescription
                    } else {
                        dismiss()
                        viewModel.loadStatus()
                    }
                },
                receiveValue: { _ in
                    dismiss()
                    viewModel.loadStatus()
                }
            )
            .store(in: &cancellables)
    }
}

struct RenewVerificationView: View {
    @ObservedObject var viewModel: StudentVerificationViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isRenewing = false
    @State private var renewError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 邮箱信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "续期信息", icon: "arrow.clockwise.circle.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: "学校邮箱",
                                    placeholder: "请输入您的学校邮箱",
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text("说明: 请输入您的学校邮箱地址以续期认证。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 续期按钮
                        Button(action: {
                            HapticFeedback.success()
                            renew()
                        }) {
                            HStack(spacing: 8) {
                                if isRenewing {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("arrow.clockwise", size: 18)
                                }
                                Text(isRenewing ? "正在续期..." : "立即续期")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isRenewing || email.isEmpty)
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("续期认证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: Binding(
                get: { renewError != nil },
                set: { if !$0 { renewError = nil } }
            )) {
                Button("确定", role: .cancel) {
                    renewError = nil
                }
            } message: {
                if let error = renewError {
                    Text(error)
                }
            }
        }
    }
    
    private func renew() {
        guard !email.isEmpty else { return }
        
        isRenewing = true
        renewError = nil
        
        viewModel.renewVerification(email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isRenewing = false
                    if case .failure(let error) = completion {
                        renewError = error.localizedDescription
                    } else {
                        dismiss()
                        viewModel.loadStatus()
                    }
                },
                receiveValue: { _ in
                    dismiss()
                    viewModel.loadStatus()
                }
            )
            .store(in: &cancellables)
    }
}

struct ChangeEmailView: View {
    @ObservedObject var viewModel: StudentVerificationViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var newEmail = ""
    @State private var isChanging = false
    @State private var changeError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 新邮箱信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "更换邮箱", icon: "envelope.badge.shield.half.filled")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: "新学校邮箱",
                                    placeholder: "请输入新的学校邮箱",
                                    text: $newEmail,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text("说明: 请输入新的学校邮箱地址，更换后需重新验证。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 更换按钮
                        Button(action: {
                            HapticFeedback.success()
                            changeEmail()
                        }) {
                            HStack(spacing: 8) {
                                if isChanging {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("arrow.left.and.right", size: 18)
                                }
                                Text(isChanging ? "正在更换..." : "确认更换")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isChanging || newEmail.isEmpty)
                        .padding(.top, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("更换邮箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: Binding(
                get: { changeError != nil },
                set: { if !$0 { changeError = nil } }
            )) {
                Button("确定", role: .cancel) {
                    changeError = nil
                }
            } message: {
                if let error = changeError {
                    Text(error)
                }
            }
        }
    }
    
    private func changeEmail() {
        guard !newEmail.isEmpty else { return }
        
        isChanging = true
        changeError = nil
        
        viewModel.changeEmail(newEmail: newEmail)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isChanging = false
                    if case .failure(let error) = completion {
                        changeError = error.localizedDescription
                    } else {
                        dismiss()
                        viewModel.loadStatus()
                    }
                },
                receiveValue: { _ in
                    dismiss()
                    viewModel.loadStatus()
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    StudentVerificationView()
}
