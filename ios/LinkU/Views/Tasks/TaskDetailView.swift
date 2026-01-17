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
                LoadingView()
            } else if let task = viewModel.task {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. 沉浸式图片预览
                        if let images = task.images, !images.isEmpty {
                            TabView {
                                ForEach(images, id: \.self) { imageUrl in
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(AppColors.primary.opacity(0.05))
                                    }
                                }
                            }
                            .frame(height: 340)
                            .tabViewStyle(.page)
                        } else {
                            // 无图时的品牌占位
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.primary.opacity(0.3))
                                Text("发布者未上传图片")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(AppColors.primary.opacity(0.05))
                        }
                        
                        // 2. 核心内容卡片：向上偏移产生重叠感
                        VStack(alignment: .leading, spacing: 24) {
                            // 标题与价格区域
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    Text(task.title)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Spacer()
                                    
                                    TaskStatusBadge(status: task.status)
                                }
                                
                                if let price = task.price {
                                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                                        Text("¥")
                                            .font(.system(size: 18, weight: .bold))
                                        Text(String(format: "%.2f", price))
                                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    }
                                    .foregroundColor(AppColors.error)
                                }
                            }
                            
                            // 标签区域
                            HStack(spacing: 8) {
                                Label(task.category, systemImage: "tag.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.primary.opacity(0.1))
                                    .foregroundColor(AppColors.primary)
                                    .cornerRadius(8)
                                
                                Label(task.city, systemImage: "location.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.1))
                                    .foregroundColor(AppColors.textSecondary)
                                    .cornerRadius(8)
                            }
                            
                            Divider()
                            
                            // 任务描述
                            VStack(alignment: .leading, spacing: 12) {
                                Text("任务详情")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(task.description)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineSpacing(6)
                            }
                            
                            // 发布者卡片
                            if let author = task.author {
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: author.avatar ?? "")) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle().fill(AppColors.primary.opacity(0.1))
                                            .overlay(Image(systemName: "person.fill").foregroundColor(AppColors.primary))
                                    }
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(author.username ?? "用户")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("发布于 \(formatTime(task.createdAt))")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("联系他") {
                                        // 聊天逻辑
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.primary.opacity(0.1))
                                    .foregroundColor(AppColors.primary)
                                    .cornerRadius(20)
                                }
                                .padding(14)
                                .background(AppColors.secondaryBackground)
                                .cornerRadius(16)
                            }
                        }
                        .padding(24)
                        .background(AppColors.cardBackground)
                        .clipShape(
                            UnevenRoundedRectangle(
                                cornerRadii: .init(
                                    topLeading: 32,
                                    bottomLeading: 0,
                                    bottomTrailing: 0,
                                    topTrailing: 32
                                )
                            )
                        )
                        .offset(y: -30)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            
            // 底部悬浮操作栏
            if let task = viewModel.task, task.status == .open {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { /* 收藏逻辑 */ }) {
                            Image(systemName: "heart")
                                .font(.title3)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 54, height: 54)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        
                        Button(action: { showApplySheet = true }) {
                            Text("立即申请任务")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AppColors.primaryGradient)
                                .cornerRadius(27)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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

