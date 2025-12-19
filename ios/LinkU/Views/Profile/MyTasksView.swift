import SwiftUI

struct MyTasksView: View {
    @StateObject private var viewModel = MyTasksViewModel()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                ProgressView()
            } else if viewModel.tasks.isEmpty {
                EmptyStateView(
                    icon: "doc.text.fill",
                    title: "暂无任务",
                    message: "您还没有发布或接受任何任务"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.tasks) { task in
                            NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                TaskCard(task: task)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationTitle("我的任务")
        .refreshable {
            viewModel.loadTasks()
        }
        .onAppear {
            if viewModel.tasks.isEmpty {
                viewModel.loadTasks()
            }
        }
    }
}

