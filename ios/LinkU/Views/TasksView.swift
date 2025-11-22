//
//  TasksView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var selectedCategory: String?
    @State private var selectedCity: String?
    @State private var searchText = ""
    @State private var showFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .onChange(of: searchText) { _ in
                        viewModel.loadTasks(category: selectedCategory, city: selectedCity, keyword: searchText.isEmpty ? nil : searchText)
                    }
                
                // 筛选栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                            viewModel.loadTasks(category: nil, city: selectedCity, keyword: searchText.isEmpty ? nil : searchText)
                        }
                        
                        ForEach(["Housekeeping", "Campus Life", "Errand Running", "Skill Service"], id: \.self) { category in
                            FilterChip(title: category, isSelected: selectedCategory == category) {
                                selectedCategory = category
                                viewModel.loadTasks(category: category, city: selectedCity, keyword: searchText.isEmpty ? nil : searchText)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // 任务列表
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadTasks(category: selectedCategory, city: selectedCity)
                    }
                } else if viewModel.tasks.isEmpty {
                    VStack {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无任务")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.tasks) { task in
                        TaskRowView(task: task)
                    }
                    .refreshable {
                        viewModel.loadTasks(category: selectedCategory, city: selectedCity, keyword: searchText.isEmpty ? nil : searchText)
                    }
                }
            }
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PublishTaskView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                if viewModel.tasks.isEmpty {
                    viewModel.loadTasks()
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

struct TaskRowView: View {
    let task: Task
    @State private var showDetail = false
    
    var body: some View {
        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: task.status)
                }
                
                Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label(task.city, systemImage: "location")
                        .font(.caption)
                    Spacer()
                    if let price = task.price {
                        Text("£\(price, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TasksView()
}

