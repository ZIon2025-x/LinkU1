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
                    
                    Text("成为任务达人")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("展示您的专业技能，获得更多任务机会")
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
                    title: "什么是任务达人？",
                    content: "任务达人是平台认证的专业服务提供者，拥有丰富的经验和良好的口碑。成为任务达人后，您的服务将获得更多曝光，吸引更多客户。",
                    color: .yellow
                )
                
                // 成为达人的好处
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("成为达人的好处")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    BenefitRow(
                        icon: "eye.fill",
                        title: "更多曝光",
                        description: "您的服务将优先展示，获得更多用户关注"
                    )
                    
                    BenefitRow(
                        icon: "star.fill",
                        title: "专属标识",
                        description: "显示达人认证标识，提升您的专业形象"
                    )
                    
                    BenefitRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "更多订单",
                        description: "获得更多任务申请，增加收入机会"
                    )
                    
                    BenefitRow(
                        icon: "shield.checkered",
                        title: "平台支持",
                        description: "享受平台提供的专业支持和资源"
                    )
                }
                .padding(.top, AppSpacing.md)
                
                // 如何申请
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("如何申请？")
                        .font(AppTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                    
                    StepRow(
                        number: 1,
                        title: "填写申请信息",
                        description: "介绍您的专业技能和经验"
                    )
                    
                    StepRow(
                        number: 2,
                        title: "提交审核",
                        description: "平台将在3-5个工作日内完成审核"
                    )
                    
                    StepRow(
                        number: 3,
                        title: "开始服务",
                        description: "审核通过后即可发布服务，开始接单"
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
                            Text("立即申请")
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
                            Text("登录后申请")
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
        .navigationTitle("任务达人")
        .navigationBarTitleDisplayMode(.large)
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
                        Text("申请信息")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } footer: {
                        Text("请介绍您的专业技能、经验和优势，这将帮助平台更好地了解您。")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Section {
                        Button(action: submitApplication) {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("提交申请")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSubmitting || applicationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .navigationTitle("申请成为达人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("申请成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("您的申请已提交，我们将在3-5个工作日内完成审核。")
            }
            .alert("申请失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
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

