import SwiftUI

struct TaskFilterView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedCity: String?
    @Environment(\.dismiss) var dismiss
    
    // 任务分类映射 (显示名称 -> 后端值)
    let categories: [(name: String, value: String)] = [
        ("全部", ""),
        ("清洁家政", "Housekeeping"),
        ("校园生活", "Campus Life"),
        ("二手租赁", "Second-hand & Rental"),
        ("跑腿代购", "Errand Running"),
        ("技能服务", "Skill Service"),
        ("社交互助", "Social Help"),
        ("交通用车", "Transportation"),
        ("宠物寄养", "Pet Care"),
        ("生活便利", "Life Convenience"),
        ("其他", "Other")
    ]
    
    // 英国主要城市列表
    let cities = ["全部", "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("分类") {
                    Picker("选择分类", selection: $selectedCategory) {
                        ForEach(categories, id: \.value) { category in
                            Text(category.name)
                                .tag(category.value.isEmpty ? nil : category.value as String?)
                        }
                    }
                }
                
                Section("城市") {
                    Picker("选择城市", selection: $selectedCity) {
                        ForEach(cities, id: \.self) { city in
                            Text(city == "全部" ? "全部" : city)
                                .tag(city == "全部" ? nil : city as String?)
                        }
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

