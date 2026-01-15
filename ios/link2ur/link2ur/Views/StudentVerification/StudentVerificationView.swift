import SwiftUI
import Combine

struct StudentVerificationView: View {
    @StateObject private var viewModel = StudentVerificationViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingSubmitSheet = false
    @State private var showingRenewSheet = false
    @State private var showingChangeEmailSheet = false
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if !appState.isAuthenticated {
                    // 未登录状态
                    VStack(spacing: AppSpacing.xl) {
                        Spacer()
                        
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.textTertiary)
                        
                        Text(LocalizationKey.loginRequired.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(LocalizationKey.loginRequiredForVerification.localized)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showLogin = true
                        }) {
                            Text(LocalizationKey.loginLoginNow.localized)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                                .frame(width: 200)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.primary)
                                .cornerRadius(AppCornerRadius.large)
                        }
                        
                        Spacer()
                    }
                    .padding(AppSpacing.xl)
                } else {
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
                                    // 学生认证特权说明（已认证状态）
                                    StudentBenefitsCard(isVerified: true)
                                        .padding(.horizontal, AppSpacing.md)
                                    
                                    if status.canRenew == true {
                                        Button(action: {
                                            showingRenewSheet = true
                                        }) {
                                            HStack {
                                                IconStyle.icon("arrow.clockwise", size: IconStyle.medium)
                                                Text(LocalizationKey.studentVerificationRenewVerification.localized)
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
                                                Text(LocalizationKey.studentVerificationChangeEmail.localized)
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
                                VStack(spacing: AppSpacing.md) {
                                    // 学生认证特权说明（未认证状态）
                                    StudentBenefitsCard(isVerified: false)
                                        .padding(.horizontal, AppSpacing.md)
                                    
                                    Button(action: {
                                        showingSubmitSheet = true
                                    }) {
                                        HStack {
                                            IconStyle.icon("checkmark.shield.fill", size: IconStyle.medium)
                                            Text(LocalizationKey.studentVerificationSubmitVerification.localized)
                                                .font(AppTypography.bodyBold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, AppSpacing.md)
                                        .background(AppColors.success)
                                        .cornerRadius(AppCornerRadius.large)
                                    }
                                    .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large))
                                }
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
                                    Text(LocalizationKey.studentVerificationStudentVerificationTitle.localized)
                                        .font(AppTypography.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(LocalizationKey.studentVerificationDescription.localized)
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, AppSpacing.xl)
                                }
                                
                                // 学生认证特权说明
                                StudentBenefitsCard()
                                    .padding(.horizontal, AppSpacing.md)
                                
                                Button(action: {
                                    showingSubmitSheet = true
                                }) {
                                    HStack {
                                        IconStyle.icon("arrow.right", size: IconStyle.medium)
                                        Text(LocalizationKey.studentVerificationStartVerification.localized)
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
                } // end else (已登录)
            }
            .navigationTitle(LocalizationKey.studentVerificationStudentVerification.localized)
            .navigationBarTitleDisplayMode(.large)
            .enableSwipeBack()
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
            .alert(LocalizationKey.errorError.localized, isPresented: .constant(viewModel.errorMessage != nil)) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
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
                    Text(status.isVerified ? LocalizationKey.studentVerificationVerified.localized : LocalizationKey.studentVerificationUnverified.localized)
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
                        DetailRow(icon: "envelope.fill", label: LocalizationKey.studentVerificationEmail.localized, value: email, color: .blue)
                    }
                    
                    if let verifiedAt = status.verifiedAt {
                        DetailRow(icon: "calendar", label: LocalizationKey.studentVerificationTime.localized, value: verifiedAt, color: .green)
                    }
                    
                    if let expiresAt = status.expiresAt {
                        DetailRow(icon: "clock.fill", label: LocalizationKey.studentVerificationExpiryTime.localized, value: expiresAt, color: .orange)
                    }
                    
                    if let daysRemaining = status.daysRemaining {
                        DetailRow(
                            icon: "hourglass",
                            label: LocalizationKey.studentVerificationDaysRemaining.localized,
                            value: String(format: LocalizationKey.studentVerificationDaysFormat.localized, daysRemaining),
                            color: daysRemaining < 30 ? .red : .blue
                        )
                    }
                }
            } else if let statusText = status.status {
                HStack {
                    IconStyle.icon("info.circle.fill", size: IconStyle.small)
                        .foregroundColor(AppColors.warning)
                    Text(String(format: LocalizationKey.studentVerificationStatus.localized, statusText))
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
                            SectionHeader(title: LocalizationKey.studentVerificationEmailInfo.localized, icon: "envelope.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: LocalizationKey.studentVerificationSchoolEmail.localized,
                                    placeholder: LocalizationKey.studentVerificationSchoolEmailPlaceholder.localized,
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text(LocalizationKey.studentVerificationEmailInstruction.localized)
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
                                Text(isSubmitting ? LocalizationKey.studentVerificationSubmitting.localized : LocalizationKey.studentVerificationSendEmail.localized)
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
            .navigationTitle(LocalizationKey.studentVerificationSubmitVerification.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationKey.errorError.localized, isPresented: Binding(
                get: { submitError != nil },
                set: { if !$0 { submitError = nil } }
            )) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
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
                            SectionHeader(title: LocalizationKey.studentVerificationRenewInfo.localized, icon: "arrow.clockwise.circle.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: LocalizationKey.studentVerificationSchoolEmail.localized,
                                    placeholder: LocalizationKey.studentVerificationRenewEmailPlaceholder.localized,
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text(LocalizationKey.studentVerificationRenewInstruction.localized)
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
                                Text(isRenewing ? LocalizationKey.studentVerificationRenewing.localized : LocalizationKey.studentVerificationRenewNow.localized)
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
            .navigationTitle(LocalizationKey.studentVerificationRenewVerification.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationKey.errorError.localized, isPresented: Binding(
                get: { renewError != nil },
                set: { if !$0 { renewError = nil } }
            )) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
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
                            SectionHeader(title: LocalizationKey.studentVerificationChangeEmail.localized, icon: "envelope.badge.shield.half.filled")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: LocalizationKey.studentVerificationNewSchoolEmail.localized,
                                    placeholder: LocalizationKey.studentVerificationNewSchoolEmailPlaceholder.localized,
                                    text: $newEmail,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never,
                                    isRequired: true
                                )
                                
                                Text(LocalizationKey.studentVerificationChangeEmailInstruction.localized)
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
                                Text(isChanging ? LocalizationKey.studentVerificationChanging.localized : LocalizationKey.studentVerificationConfirmChange.localized)
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
            .navigationTitle(LocalizationKey.studentVerificationChangeEmail.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationKey.errorError.localized, isPresented: Binding(
                get: { changeError != nil },
                set: { if !$0 { changeError = nil } }
            )) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {
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

// MARK: - Student Benefits Card
struct StudentBenefitsCard: View {
    var isVerified: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                IconStyle.icon("sparkles", size: IconStyle.medium)
                    .foregroundColor(AppColors.primary)
                Text(isVerified ? LocalizationKey.studentVerificationBenefitsTitleVerified.localized : LocalizationKey.studentVerificationBenefitsTitleUnverified.localized)
                    .font(AppTypography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                StudentBenefitRow(
                    icon: "graduationcap.fill",
                    title: LocalizationKey.studentVerificationBenefitCampusLife.localized,
                    description: LocalizationKey.studentVerificationBenefitCampusLifeDescription.localized,
                    color: .blue
                )
                
                StudentBenefitRow(
                    icon: "person.3.fill",
                    title: LocalizationKey.studentVerificationBenefitStudentCommunity.localized,
                    description: LocalizationKey.studentVerificationBenefitStudentCommunityDescription.localized,
                    color: .green
                )
                
                StudentBenefitRow(
                    icon: "gift.fill",
                    title: LocalizationKey.studentVerificationBenefitExclusiveBenefits.localized,
                    description: LocalizationKey.studentVerificationBenefitExclusiveBenefitsDescription.localized,
                    color: .orange
                )
                
                StudentBenefitRow(
                    icon: "checkmark.seal.fill",
                    title: LocalizationKey.studentVerificationBenefitVerificationBadge.localized,
                    description: LocalizationKey.studentVerificationBenefitVerificationBadgeDescription.localized,
                    color: .purple
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.05),
                    AppColors.primary.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppCornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(
                    isVerified ? AppColors.success.opacity(0.3) : AppColors.primary.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

struct StudentBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    StudentVerificationView()
}
