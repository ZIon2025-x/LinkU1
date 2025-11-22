//
//  TaskDetailView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct TaskDetailView: View {
    let taskId: Int
    @StateObject private var viewModel = TaskDetailViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let task = viewModel.task {
                    // 标题
                    Text(task.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // 价格
                    if let price = task.price {
                        Text("£\(price, specifier: "%.2f")")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    // 状态标签
                    HStack {
                        StatusBadge(status: task.status)
                        Spacer()
                        Label(task.city, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // 描述
                    Text("描述")
                        .font(.headline)
                    Text(task.description)
                        .font(.body)
                    
                    // 图片
                    if let images = task.images, !images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(images, id: \.self) { imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    // 作者信息
                    if let author = task.author {
                        Divider()
                        HStack {
                            AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(author.username)
                                    .font(.headline)
                                Text("发布于 \(formatDate(task.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("加载失败")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTask(id: taskId)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch status {
        case .open: return "进行中"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .open: return .green
        case .inProgress: return .blue
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

class TaskDetailViewModel: ObservableObject {
    @Published var task: Task?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    func loadTask(id: Int) {
        isLoading = true
        errorMessage = nil
        
        // TODO: 实现获取任务详情的API
        // apiService.getTask(id: id)
        //     .receive(on: DispatchQueue.main)
        //     .sink(...)
    }
}

#Preview {
    NavigationView {
        TaskDetailView(taskId: 1)
    }
}

