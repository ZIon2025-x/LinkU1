import SwiftUI

struct TaskExpertListView: View {
    @StateObject private var viewModel = TaskExpertViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showFilter = false
    
    // 任务达人分类映射（根据后端 models.py 中的 category 字段）
    let categories: [(name: String, value: String)] = [
        (LocalizationKey.expertCategoryAll.localized, ""),
        (LocalizationKey.expertCategoryProgramming.localized, "programming"),
        (LocalizationKey.expertCategoryTranslation.localized, "translation"),
        (LocalizationKey.expertCategoryTutoring.localized, "tutoring"),
        (LocalizationKey.expertCategoryFood.localized, "food"),
        (LocalizationKey.expertCategoryBeverage.localized, "beverage"),
        (LocalizationKey.expertCategoryCake.localized, "cake"),
        (LocalizationKey.expertCategoryErrandTransport.localized, "errand_transport"),
        (LocalizationKey.expertCategorySocialEntertainment.localized, "social_entertainment"),
        (LocalizationKey.expertCategoryBeautySkincare.localized, "beauty_skincare"),
        (LocalizationKey.expertCategoryHandicraft.localized, "handicraft")
    ]
    
    // 城市列表
    let cities = ["全部", "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 筛选栏
                    if selectedCategory != nil || selectedCity != nil {
                        HStack(spacing: AppSpacing.sm) {
                            if let category = selectedCategory, !category.isEmpty {
                                FilterChip(
                                    text: categories.first(where: { $0.value == category })?.name ?? category,
                                    onRemove: {
                                        selectedCategory = nil
                                        applyFilters()
                                    }
                                )
                            }
                            
                            if let city = selectedCity, !city.isEmpty, city != "全部" {
                                FilterChip(
                                    text: city,
                                    onRemove: {
                                        selectedCity = nil
                                        applyFilters()
                                    }
                                )
                            }
                            
                            Spacer()
                            
                            Button(LocalizationKey.taskExpertClear.localized) {
                                selectedCategory = nil
                                selectedCity = nil
                                applyFilters()
                            }
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.primary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground)
                    }
                    
                    // 内容区域
                    Group {
                        if viewModel.isLoading && viewModel.experts.isEmpty {
                            // 使用列表骨架屏
                            ScrollView {
                                ListSkeleton(itemCount: 5, itemHeight: 100)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                            }
                        } else if viewModel.experts.isEmpty {
                            VStack {
                                Spacer()
                                EmptyStateView(
                                    icon: "person.3.fill",
                                    title: LocalizationKey.taskExpertNoExperts.localized,
                                    message: searchText.isEmpty ? LocalizationKey.taskExpertNoExpertsMessage.localized : LocalizationKey.taskExpertNoExpertsSearchMessage.localized
                                )
                                Spacer()
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: AppSpacing.md) {
                                    ForEach(Array(viewModel.experts.enumerated()), id: \.element.id) { index, expert in
                                        NavigationLink(destination: TaskExpertDetailView(expertId: expert.id)) {
                                            ExpertCard(expert: expert)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .listItemAppear(index: index, totalItems: viewModel.experts.count) // 添加错落入场动画
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
                }
            }
            .navigationTitle(LocalizationKey.taskExpertTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            showFilter = true
                        }
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppColors.primary)
                    }
                    .transaction { $0.animation = nil } // 禁用动画
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TaskExpertsIntroView()) {
                        Text(LocalizationKey.taskExpertBecomeExpert.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.primary)
                    }
                    .transaction { $0.animation = nil } // 禁用动画
                }
            }
            .transaction { transaction in
                transaction.animation = nil // 禁用整个toolbar的动画
            }
            .searchable(text: $searchText, prompt: LocalizationKey.taskExpertSearchPrompt.localized)
            .onChange(of: searchText) { newValue in
                applyFilters()
            }
            .onSubmit(of: .search) {
                // 当用户提交搜索时，应用筛选
                applyFilters()
            }
            .sheet(isPresented: $showFilter) {
                TaskExpertFilterView(
                    selectedCategory: $selectedCategory,
                    selectedCity: $selectedCity,
                    categories: categories,
                    cities: cities,
                    onApply: {
                        applyFilters()
                    }
                )
            }
            .refreshable {
                applyFilters()
            }
            .onAppear {
                if viewModel.experts.isEmpty {
                    applyFilters()
                }
            }
        }
    }
    
    private func applyFilters() {
        let category = selectedCategory?.isEmpty == true ? nil : selectedCategory
        let city = selectedCity == "全部" ? nil : selectedCity
        let keyword = searchText.isEmpty ? nil : searchText
        viewModel.loadExperts(category: category, location: city, keyword: keyword)
    }
}

// 筛选标签
struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(text)
                .font(AppTypography.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(AppColors.primaryLight)
        .foregroundColor(AppColors.primary)
        .cornerRadius(AppCornerRadius.small)
    }
}

// 筛选视图
struct TaskExpertFilterView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedCity: String?
    let categories: [(name: String, value: String)]
    let cities: [String]
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("任务类型") {
                    Picker("选择类型", selection: $selectedCategory) {
                        Text(LocalizationKey.expertCategoryAll.localized).tag(nil as String?)
                        ForEach(categories, id: \.value) { category in
                            if !category.value.isEmpty {
                                Text(category.name).tag(category.value as String?)
                            }
                        }
                    }
                }
                
                Section("所在城市") {
                    Picker("选择城市", selection: $selectedCity) {
                        Text(LocalizationKey.expertCategoryAll.localized).tag(nil as String?)
                        ForEach(cities, id: \.self) { city in
                            if city != "全部" {
                                Text(city).tag(city as String?)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizationKey.commonFilter.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// 任务达人卡片
struct ExpertCard: View {
    let expert: TaskExpert
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像 - 带光晕效果
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 74, height: 74)
                
                AvatarView(
                    urlString: expert.avatar,
                    size: 68,
                    placeholder: Image(systemName: "person.fill")
                )
                .clipShape(Circle())
            }
            .shadow(color: AppColors.primary.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(expert.name)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                
                    // 认证徽章
                    IconStyle.icon("checkmark.seal.fill", size: 14)
                        .foregroundColor(AppColors.primary)
                }
                
                if let bio = expert.localizedBio, !bio.isEmpty {
                    Text(bio)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(LocalizationKey.taskExpertNoIntro.localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // 统计数据
                HStack(spacing: 12) {
                    // 评分
                    if let rating = expert.avgRating {
                        HStack(spacing: 3) {
                            IconStyle.icon("star.fill", size: 10)
                            Text(String(format: "%.1f", rating))
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppColors.warning.opacity(0.12))
                        )
                        .foregroundColor(AppColors.warning)
                    }
                    
                    // 单数和完成率
                    HStack(spacing: 4) {
                        if let completed = expert.completedTasks {
                            Text("\(completed) \(LocalizationKey.taskExpertOrder.localized)")
                                .font(AppTypography.caption)
                        }
                        
                        if let rate = expert.completionRate {
                            Text("·")
                            Text("\(Int(rate))%")
                                .font(AppTypography.caption)
                        }
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            IconStyle.icon("chevron.right", size: 14, weight: .semibold)
                .foregroundColor(AppColors.textQuaternary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground) // 内容区域背景
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        // 移除阴影，使用更轻量的视觉分隔
    }
}

