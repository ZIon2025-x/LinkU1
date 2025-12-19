import SwiftUI

struct TaskDetailView: View {
    let taskId: Int
    @StateObject private var viewModel = TaskDetailViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showApplySheet = false
    @State private var applyMessage = ""
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.task == nil {
                ProgressView()
            } else if let task = viewModel.task {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 任务图片
                        if let images = task.images, !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(images, id: \.self) { imageUrl in
                                        AsyncImage(url: URL(string: imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .fill(AppColors.primaryLight)
                                        }
                                        .frame(width: 300, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        
                        // 任务信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // 标题和价格
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    if let price = task.price {
                                        Text("¥ \(String(format: "%.2f", price))")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.error)
                                    }
                                }
                                
                                Spacer()
                                
                                StatusBadge(status: task.status)
                            }
                            
                            // 分类和城市
                            HStack(spacing: 8) {
                                Text(task.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primaryLight)
                                    .foregroundColor(AppColors.primary)
                                    .cornerRadius(6)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                    Text(task.city)
                                        .font(.caption)
                                }
                                .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Divider()
                            
                            // 描述
                            Text("任务描述")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(task.description)
                                .font(.body)
                                .foregroundColor(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // 发布者信息
                            if let author = task.author {
                                Divider()
                                
                                HStack {
                                    AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    
                                    Text(author.username ?? author.email)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Spacer()
                                }
                            }
                            
                            // 时间信息
                            HStack {
                                Label(formatTime(task.createdAt), systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 申请按钮
                        if task.status == .open {
                            Button(action: {
                                showApplySheet = true
                            }) {
                                Text("申请任务")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .foregroundColor(.white)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(AppCornerRadius.medium)
                                    .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showApplySheet) {
            ApplyTaskSheet(
                message: $applyMessage,
                onApply: {
                    viewModel.applyTask(taskId: taskId, message: applyMessage.isEmpty ? nil : applyMessage) { success in
                        if success {
                            showApplySheet = false
                            applyMessage = ""
                        }
                    }
                }
            )
        }
        .onAppear {
            viewModel.loadTask(taskId: taskId)
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 申请任务弹窗
struct ApplyTaskSheet: View {
    @Binding var message: String
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                Text("申请任务")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                TextEditor(text: $message)
                    .frame(height: 150)
                    .padding(8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                    )
                
                Text("留言（可选）")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Button(action: onApply) {
                    Text("提交申请")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                }
            }
            .padding(AppSpacing.md)
            .navigationTitle("申请任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

