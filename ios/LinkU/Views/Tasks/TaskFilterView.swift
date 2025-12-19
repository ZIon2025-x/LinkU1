import SwiftUI

struct TaskFilterView: View {
    @Binding var selectedCategory: String?
    @Binding var selectedStatus: String?
    @Environment(\.dismiss) var dismiss
    
    let categories = ["全部", "配送", "代购", "维修", "清洁", "搬家", "学习", "娱乐", "其他"]
    let statuses = ["全部", "开放中", "进行中", "已完成", "已取消"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("分类") {
                    Picker("选择分类", selection: $selectedCategory) {
                        Text("全部").tag(nil as String?)
                        ForEach(categories.filter { $0 != "全部" }, id: \.self) { category in
                            Text(category).tag(category as String?)
                        }
                    }
                }
                
                Section("状态") {
                    Picker("选择状态", selection: $selectedStatus) {
                        Text("全部").tag(nil as String?)
                        ForEach(statuses.filter { $0 != "全部" }, id: \.self) { status in
                            Text(status).tag(status as String?)
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

