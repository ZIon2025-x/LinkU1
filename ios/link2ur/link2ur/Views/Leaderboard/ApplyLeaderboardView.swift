import SwiftUI
import PhotosUI

struct ApplyLeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var name = ""
    @State private var description = ""
    @State private var location = ""
    @State private var applicationReason = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var coverImage: UIImage?
    @State private var isUploading = false
    @State private var localErrorMessage: String?
    
    // 支持的城市列表（与发布任务一致）
    let cities = ["London", "Manchester", "Birmingham", "Edinburgh", "Glasgow", "Liverpool", "Online"]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 基本信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "排行榜信息", icon: "trophy.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                EnhancedTextField(
                                    title: "排行榜名称",
                                    placeholder: "例：最受欢迎的中餐厅",
                                    text: $name,
                                    icon: "tag.fill",
                                    isRequired: true
                                )
                                
                                CustomPickerField(
                                    title: "所属地区",
                                    selection: $location,
                                    options: cities.map { ($0, $0) },
                                    icon: "mappin.and.ellipse"
                                )
                                
                                EnhancedTextEditor(
                                    title: "详细描述",
                                    placeholder: "请描述该排行榜的主旨和收录标准...",
                                    text: $description,
                                    height: 120,
                                    characterLimit: 500
                                )
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 申请理由
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "申请理由", icon: "doc.text.fill")
                            
                            EnhancedTextEditor(
                                title: "为什么创建该榜单？",
                                placeholder: "向管理员说明创建此排行榜的必要性，有助于快速通过审核...",
                                text: $applicationReason,
                                height: 100,
                                characterLimit: 300
                            )
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 3. 封面图
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "封面图 (可选)", icon: "photo.fill")
                            
                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                                if let image = coverImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 180)
                                            .frame(maxWidth: .infinity)
                                            .cornerRadius(AppCornerRadius.medium)
                                            .clipped()
                                        
                                        Button(action: {
                                            coverImage = nil
                                            selectedItems = []
                                            HapticFeedback.light()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .padding(8)
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus.viewfinder")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppColors.primary)
                                        Text("添加封面图片")
                                            .font(AppTypography.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .background(AppColors.background)
                                    .cornerRadius(AppCornerRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                            .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    )
                                }
                            }
                            .onChange(of: selectedItems) { newValue in
                                handleImageSelection()
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 错误提示
                        if let error = localErrorMessage ?? viewModel.errorMessage {
                            HStack(spacing: 8) {
                                IconStyle.icon("exclamationmark.octagon.fill", size: 16)
                                Text(error)
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 提交按钮
                        Button(action: {
                            submitApplication()
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoading || isUploading {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("paperplane.fill", size: 18)
                                }
                                Text(viewModel.isLoading || isUploading ? "正在提交..." : "提交申请")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isLoading || isUploading || name.isEmpty || location.isEmpty)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("申请新榜单")
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleImageSelection() {
        _Concurrency.Task {
            if let item = selectedItems.first {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.coverImage = image
                    }
                }
            }
        }
    }
    
    private func submitApplication() {
        guard !name.isEmpty && !location.isEmpty else { return }
        
        HapticFeedback.success()
        
        if let image = coverImage {
            isUploading = true
            localErrorMessage = nil
            
            // 先上传图片
            APIService.shared.uploadImage(image, path: "leaderboard_covers") { result in
                isUploading = false
                switch result {
                case .success(let url):
                    self.performSubmit(coverImageUrl: url)
                case .failure(let error):
                    self.localErrorMessage = "图片上传失败: \(error.localizedDescription)"
                }
            }
        } else {
            performSubmit(coverImageUrl: nil)
        }
    }
    
    private func performSubmit(coverImageUrl: String?) {
        viewModel.applyLeaderboard(
            name: name,
            location: location,
            description: description.isEmpty ? nil : description,
            applicationReason: applicationReason.isEmpty ? nil : applicationReason,
            coverImage: coverImageUrl
        ) { success, error in
            if success {
                dismiss()
            } else {
                self.localErrorMessage = error
            }
        }
    }
}

