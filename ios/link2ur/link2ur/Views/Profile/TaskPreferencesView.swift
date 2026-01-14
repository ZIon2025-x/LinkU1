import SwiftUI
import Combine

struct TaskPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = TaskPreferencesViewModel()
    
    // 任务类型选项
    private var taskTypes: [(name: String, value: String)] {
        [
            (LocalizationKey.taskCategoryHousekeeping.localized, "Housekeeping"),
            (LocalizationKey.taskCategoryCampusLife.localized, "Campus Life"),
            (LocalizationKey.taskCategorySecondhandRental.localized, "Second-hand & Rental"),
            (LocalizationKey.taskCategoryErrandRunning.localized, "Errand Running"),
            (LocalizationKey.taskCategorySkillService.localized, "Skill Service"),
            (LocalizationKey.taskCategorySocialHelp.localized, "Social Help"),
            (LocalizationKey.taskCategoryTransportation.localized, "Transportation"),
            (LocalizationKey.taskCategoryPetCare.localized, "Pet Care"),
            (LocalizationKey.taskCategoryLifeConvenience.localized, "Life Convenience"),
            (LocalizationKey.taskCategoryOther.localized, "Other")
        ]
    }
    
    // 地点选项
    private let locations = [
        "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow",
        "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton",
        "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York",
        "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast",
        "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster",
        "Warwick", "Cambridge", "Oxford", "Other"
    ]
    
    // 任务等级选项
    private let taskLevels = ["Normal", "VIP", "Super"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.preferences == nil {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.xl) {
                            // 偏好的任务类型
                            PreferenceSection(
                                title: LocalizationKey.taskPreferencesPreferredTypes.localized,
                                description: LocalizationKey.taskPreferencesPreferredTypesDescription.localized
                            ) {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: AppSpacing.sm),
                                    GridItem(.flexible(), spacing: AppSpacing.sm)
                                ], spacing: AppSpacing.sm) {
                                    ForEach(taskTypes, id: \.value) { type in
                                        PreferenceToggle(
                                            title: type.name,
                                            isSelected: viewModel.preferences?.taskTypes.contains(type.value) ?? false
                                        ) {
                                            viewModel.toggleTaskType(type.value)
                                        }
                                    }
                                }
                            }
                            
                            // 偏好的地点
                            PreferenceSection(
                                title: LocalizationKey.taskPreferencesPreferredLocations.localized,
                                description: LocalizationKey.taskPreferencesPreferredLocationsDescription.localized
                            ) {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: AppSpacing.sm),
                                    GridItem(.flexible(), spacing: AppSpacing.sm)
                                ], spacing: AppSpacing.sm) {
                                    ForEach(locations, id: \.self) { location in
                                        PreferenceToggle(
                                            title: location,
                                            isSelected: viewModel.preferences?.locations.contains(location) ?? false
                                        ) {
                                            viewModel.toggleLocation(location)
                                        }
                                    }
                                }
                            }
                            
                            // 偏好的任务等级
                            PreferenceSection(
                                title: LocalizationKey.taskPreferencesPreferredLevels.localized,
                                description: LocalizationKey.taskPreferencesPreferredLevelsDescription.localized
                            ) {
                                HStack(spacing: AppSpacing.md) {
                                    ForEach(taskLevels, id: \.self) { level in
                                        PreferenceToggle(
                                            title: level,
                                            isSelected: viewModel.preferences?.taskLevels.contains(level) ?? false
                                        ) {
                                            viewModel.toggleTaskLevel(level)
                                        }
                                    }
                                }
                            }
                            
                            // 最少截止时间
                            PreferenceSection(
                                title: LocalizationKey.taskPreferencesMinDeadline.localized,
                                description: LocalizationKey.taskPreferencesMinDeadlineDescription.localized
                            ) {
                                HStack(spacing: AppSpacing.md) {
                                    Stepper(
                                        value: Binding(
                                            get: { viewModel.preferences?.minDeadlineDays ?? 1 },
                                            set: { viewModel.updateMinDeadlineDays($0) }
                                        ),
                                        in: 1...30
                                    ) {
                                        Text("\(viewModel.preferences?.minDeadlineDays ?? 1) \(LocalizationKey.taskPreferencesDays.localized)")
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    
                                    Text(LocalizationKey.taskPreferencesDaysRange.localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            
                            // 保存按钮
                            Button {
                                viewModel.savePreferences {
                                    dismiss()
                                }
                            } label: {
                                Text(LocalizationKey.taskPreferencesSave.localized)
                                    .font(AppTypography.bodyBold)
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
                                    .cornerRadius(AppCornerRadius.large)
                                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(PrimaryButtonStyle(cornerRadius: AppCornerRadius.large, useGradient: true))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.xl)
                            .disabled(viewModel.isSaving)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationTitle(LocalizationKey.taskPreferencesTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.commonDone.localized) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                viewModel.loadPreferences()
            }
        }
    }
}

struct PreferenceSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(description)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            
            content
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.large)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

struct PreferenceToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.body)
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .stroke(isSelected ? AppColors.primary : AppColors.separator, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

@MainActor
class TaskPreferencesViewModel: ObservableObject {
    @Published var preferences: UserPreferences?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadPreferences() {
        isLoading = true
        errorMessage = nil
        
        apiService.getUserPreferences()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                        // 如果加载失败，使用默认值
                        self?.preferences = UserPreferences()
                    }
                },
                receiveValue: { [weak self] prefs in
                    self?.isLoading = false
                    self?.preferences = prefs
                }
            )
            .store(in: &cancellables)
    }
    
    func toggleTaskType(_ type: String) {
        guard let prefs = preferences else { return }
        if prefs.taskTypes.contains(type) {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes.filter { $0 != type },
                locations: prefs.locations,
                taskLevels: prefs.taskLevels,
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        } else {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes + [type],
                locations: prefs.locations,
                taskLevels: prefs.taskLevels,
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        }
    }
    
    func toggleLocation(_ location: String) {
        guard let prefs = preferences else { return }
        if prefs.locations.contains(location) {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes,
                locations: prefs.locations.filter { $0 != location },
                taskLevels: prefs.taskLevels,
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        } else {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes,
                locations: prefs.locations + [location],
                taskLevels: prefs.taskLevels,
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        }
    }
    
    func toggleTaskLevel(_ level: String) {
        guard let prefs = preferences else { return }
        if prefs.taskLevels.contains(level) {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes,
                locations: prefs.locations,
                taskLevels: prefs.taskLevels.filter { $0 != level },
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        } else {
            preferences = UserPreferences(
                taskTypes: prefs.taskTypes,
                locations: prefs.locations,
                taskLevels: prefs.taskLevels + [level],
                keywords: prefs.keywords,
                minDeadlineDays: prefs.minDeadlineDays
            )
        }
    }
    
    func updateMinDeadlineDays(_ days: Int) {
        guard let prefs = preferences else { return }
        preferences = UserPreferences(
            taskTypes: prefs.taskTypes,
            locations: prefs.locations,
            taskLevels: prefs.taskLevels,
            keywords: prefs.keywords,
            minDeadlineDays: days
        )
    }
    
    func savePreferences(completion: @escaping () -> Void) {
        guard let prefs = preferences else { return }
        
        isSaving = true
        errorMessage = nil
        
        apiService.updateUserPreferences(preferences: prefs)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSaving = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isSaving = false
                    HapticFeedback.success()
                    completion()
                }
            )
            .store(in: &cancellables)
    }
}

