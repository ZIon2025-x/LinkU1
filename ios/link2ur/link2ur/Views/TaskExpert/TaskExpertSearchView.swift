import SwiftUI

struct TaskExpertSearchView: View {
    @StateObject private var viewModel = TaskExpertViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedCity: String? = nil
    @FocusState private var isSearchFocused: Bool
    
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
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索栏和筛选
                VStack(spacing: AppSpacing.md) {
                    // 搜索框
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textTertiary)
                        
                        TextField(LocalizationKey.taskExpertSearchExperts.localized, text: $searchText)
                            .focused($isSearchFocused)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    searchText = ""
                                }
                                performSearch()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .transaction { $0.animation = nil }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(isSearchFocused ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: isSearchFocused ? 2 : 1)
                            .transaction { $0.animation = nil }
                    )
                    
                    // 筛选按钮
                    HStack(spacing: AppSpacing.sm) {
                        // 类型筛选
                        Menu {
                            ForEach(categories, id: \.value) { category in
                                Button(action: {
                                    selectedCategory = category.value.isEmpty ? nil : category.value
                                    performSearch()
                                }) {
                                    HStack {
                                        Text(category.name)
                                        if selectedCategory == category.value {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "tag.fill")
                                Text(selectedCategory == nil ? LocalizationKey.taskExpertAllTypes.localized : categories.first(where: { $0.value == selectedCategory })?.name ?? LocalizationKey.taskExpertType.localized)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(selectedCategory != nil ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: selectedCategory != nil ? 1.5 : 1)
                            )
                        }
                        
                        // 城市筛选
                        Menu {
                            ForEach(cities, id: \.self) { city in
                                Button(action: {
                                    selectedCity = city == "全部" ? nil : city
                                    performSearch()
                                }) {
                                    HStack {
                                        Text(city)
                                        if selectedCity == city || (selectedCity == nil && city == "全部") {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                Text(selectedCity == nil ? "全部城市" : selectedCity!)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(selectedCity != nil ? AppColors.primary : AppColors.separator.opacity(0.3), lineWidth: selectedCity != nil ? 1.5 : 1)
                            )
                        }
                        
                        Spacer()
                        
                        // 清除筛选
                        if selectedCategory != nil || selectedCity != nil {
                            Button(action: {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    selectedCategory = nil
                                    selectedCity = nil
                                }
                                performSearch()
                            }) {
                                Text(LocalizationKey.taskExpertClear.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.primary)
                            }
                            .transaction { $0.animation = nil }
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .transaction { transaction in
                    transaction.animation = nil
                }
                
                // 内容区域
                if viewModel.isLoading && viewModel.experts.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.experts.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: LocalizationKey.taskExpertNoExpertsFound.localized,
                        message: searchText.isEmpty ? LocalizationKey.taskExpertNoExpertsFoundMessage.localized : String(format: LocalizationKey.taskExpertNoExpertsFoundWithQuery.localized, searchText)
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
        .navigationTitle("搜索达人")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isSearchFocused = true
            }
        }
    }
    
    private func performSearch() {
        let category = selectedCategory?.isEmpty == true ? nil : selectedCategory
        let city = selectedCity == "全部" ? nil : selectedCity
        let keyword = searchText.isEmpty ? nil : searchText
        viewModel.loadExperts(category: category, location: city, keyword: keyword)
    }
}

