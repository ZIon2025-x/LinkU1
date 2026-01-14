import SwiftUI

struct TaskFilterView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedCity: String?
    @Environment(\.dismiss) var dismiss
    
    // 任务分类映射 (显示名称 -> 后端值)
    var categories: [(name: String, value: String)] {
        [
            (LocalizationKey.commonAll.localized, ""),
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
    
    // 英国主要城市列表
    var cities: [String] {
        [LocalizationKey.commonAll.localized, "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizationKey.taskFilterCategory.localized) {
                    Picker(LocalizationKey.taskFilterSelectCategory.localized, selection: $selectedCategory) {
                        ForEach(categories, id: \.value) { category in
                            Text(category.name)
                                .tag(category.value.isEmpty ? nil : category.value as String?)
                        }
                    }
                }
                
                Section(LocalizationKey.taskFilterCity.localized) {
                    Picker(LocalizationKey.taskFilterSelectCity.localized, selection: $selectedCity) {
                        ForEach(cities, id: \.self) { city in
                            Text(city == LocalizationKey.commonAll.localized ? LocalizationKey.commonAll.localized : city)
                                .tag(city == "全部" ? nil : city as String?)
                        }
                    }
                }
            }
            .navigationTitle(LocalizationKey.commonFilter.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.commonDone.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

