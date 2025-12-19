import SwiftUI

struct TaskExpertListView: View {
    @StateObject private var viewModel = TaskExpertViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showFilter = false
    
    // 任务达人分类映射（根据后端 models.py 中的 category 字段）
    let categories: [(name: String, value: String)] = [
        ("全部", ""),
        ("编程", "programming"),
        ("翻译", "translation"),
        ("辅导", "tutoring"),
        ("食品", "food"),
        ("饮料", "beverage"),
        ("蛋糕", "cake"),
        ("跑腿/交通", "errand_transport"),
        ("社交/娱乐", "social_entertainment"),
        ("美容/护肤", "beauty_skincare"),
        ("手工艺", "handicraft")
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
                            
                            Button("清除") {
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
                    if viewModel.isLoading && viewModel.experts.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.experts.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "person.3.fill",
                            title: "暂无任务达人",
                            message: searchText.isEmpty ? "还没有任务达人，敬请期待..." : "没有找到相关达人"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.md) {
                                ForEach(viewModel.experts) { expert in
                                    NavigationLink(destination: TaskExpertDetailView(expertId: expert.id)) {
                                        ExpertCard(expert: expert)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                        }
                    }
                }
            }
            .navigationTitle("任务达人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showFilter = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TaskExpertsIntroView()) {
                        Text("成为达人")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索任务达人")
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
                        Text("全部").tag(nil as String?)
                        ForEach(categories, id: \.value) { category in
                            if !category.value.isEmpty {
                                Text(category.name).tag(category.value as String?)
                            }
                        }
                    }
                }
                
                Section("所在城市") {
                    Picker("选择城市", selection: $selectedCity) {
                        Text("全部").tag(nil as String?)
                        ForEach(cities, id: \.self) { city in
                            if city != "全部" {
                                Text(city).tag(city as String?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
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
            // 头像
            AvatarView(
                urlString: expert.avatar,
                size: 68,
                placeholder: Image(systemName: "person.fill")
            )
            .overlay(
                Circle()
                    .stroke(AppColors.background, lineWidth: 2)
            )
            .shadow(color: AppColors.primary.opacity(0.15), radius: 6, x: 0, y: 3)
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                Text(expert.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                    // 认证徽章（如果有）
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                }
                
                if let bio = expert.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("暂无简介")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // 统计数据
                HStack(spacing: 12) {
                    // 评分
                    if let rating = expert.avgRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.warning.opacity(0.1))
                            .foregroundColor(AppColors.warning)
                        .cornerRadius(4)
                    }
                    
                    // 单数
                    if let completed = expert.completedTasks {
                        HStack(spacing: 2) {
                            Text("\(completed)单")
                                .font(.system(size: 12))
                        }
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // 完成率
                    if let rate = expert.completionRate {
                        Text("·")
                            .foregroundColor(AppColors.textTertiary)
                        Text("完成率 \(String(format: "%.0f", rate))%")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

