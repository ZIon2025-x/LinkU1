import SwiftUI
import Combine

struct TaskExpertsIntroView: View {
    @EnvironmentObject var appState: AppState
    @State private var showApply = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Hero Section
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(AppColors.primary)
                        .padding(.top, AppSpacing.xl)
                    
                    Text(LocalizationKey.taskExpertBecomeExpertTitle.localized)
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.taskExpertShowcaseSkills.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, AppSpacing.lg)
                
                // 什么是任务达人
                InfoCard(
                    icon: "lightbulb.fill",
                    title: LocalizationKey.taskExpertWhatIs.localized,
                    content: LocalizationKey.taskExpertWhatIsContent.localized,
                    color: .yellow
                )
                
                // 成为达人的好处
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.taskExpertBenefits.localized)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    BenefitRow(
                        icon: "eye.fill",
                        title: LocalizationKey.taskExpertMoreExposure.localized,
                        description: LocalizationKey.taskExpertMoreExposureDesc.localized
                    )
                    
                    BenefitRow(
                        icon: "star.fill",
                        title: LocalizationKey.taskExpertExclusiveBadge.localized,
                        description: LocalizationKey.taskExpertExclusiveBadgeDesc.localized
                    )
                    
                    BenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: LocalizationKey.taskExpertMoreOrders.localized,
                        description: LocalizationKey.taskExpertMoreOrdersDesc.localized
                    )
                    
                    BenefitRow(
                        icon: "shield.checkered",
                        title: LocalizationKey.taskExpertPlatformSupport.localized,
                        description: LocalizationKey.taskExpertPlatformSupportDesc.localized
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 如何申请
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(LocalizationKey.taskExpertHowToApply.localized)
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    StepRow(
                        number: 1,
                        title: LocalizationKey.taskExpertFillApplication.localized,
                        description: LocalizationKey.taskExpertFillApplicationDesc.localized
                    )
                    
                    StepRow(
                        number: 2,
                        title: LocalizationKey.taskExpertSubmitReview.localized,
                        description: LocalizationKey.taskExpertSubmitReviewDesc.localized
                    )
                    
                    StepRow(
                        number: 3,
                        title: LocalizationKey.taskExpertStartService.localized,
                        description: LocalizationKey.taskExpertStartServiceDesc.localized
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 申请按钮
                if appState.isAuthenticated {
                    Button(action: {
                        showApply = true
                    }) {
                        HStack {
                            Spacer()
                            Text(LocalizationKey.taskExpertApplyNow.localized)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.large)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                } else {
                    NavigationLink(destination: LoginView()) {
                        HStack {
                            Spacer()
                            Text(LocalizationKey.taskExpertLoginToApply.localized)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.primary)
                        .cornerRadius(AppCornerRadius.large)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                }
                
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .navigationTitle(LocalizationKey.taskExpertTitle.localized)
        .navigationBarTitleDisplayMode(.large)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showApply) {
            TaskExpertApplyView()
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 40)
                
                Text(title)
                    .font(AppTypography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(content)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .cardStyle()
        .padding(.horizontal, AppSpacing.md)
    }
}

struct TaskExpertApplyView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = TaskExpertViewModel()
    @State private var applicationMessage = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        TextEditor(text: $applicationMessage)
                            .frame(minHeight: 200)
                            .font(AppTypography.body)
                    } header: {
                        Text(LocalizationKey.taskExpertApplicationInfo.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } footer: {
                        Text(LocalizationKey.taskExpertApplicationHint.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Section {
                        Button(action: submitApplication) {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(LocalizationKey.taskExpertSubmitApplication.localized)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSubmitting || applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .navigationTitle(LocalizationKey.taskExpertApplyTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .alert(LocalizationKey.taskExpertApplicationSubmitted.localized, isPresented: $showSuccess) {
                Button(LocalizationKey.commonOk.localized) {
                    dismiss()
                }
            } message: {
                Text(LocalizationKey.taskExpertApplicationSubmittedMessage.localized)
            }
            .alert(LocalizationKey.errorError.localized, isPresented: $showError) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitApplication() {
        isSubmitting = true
        APIService.shared.applyToBeExpert(message: applicationMessage.isEmpty ? nil : applicationMessage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isSubmitting = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                        showError = true
                    } else {
                        showSuccess = true
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    NavigationView {
        TaskExpertsIntroView()
            .environmentObject(AppState())
    }
}

