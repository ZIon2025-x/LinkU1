import SwiftUI
import PhotosUI
import UIKit

@available(iOS 16.0, *)
struct CreateTaskView: View {
    @StateObject private var viewModel = CreateTaskViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 基本信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskBasicInfo.localized, icon: "doc.text.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                // 标题
                                EnhancedTextField(
                                    title: "任务标题",
                                    placeholder: "简要说明您的需求 (例: 代取包裹)",
                                    text: $viewModel.title,
                                    icon: "pencil.line",
                                    isRequired: true
                                )
                                
                                // 描述
                                EnhancedTextEditor(
                                    title: "任务详情",
                                    placeholder: "请详细描述您的需求、时间、特殊要求等，越详细越容易被接单哦...",
                                    text: $viewModel.description,
                                    height: 150,
                                    isRequired: true,
                                    characterLimit: 1000
                                )
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 报酬与地点
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskRewardLocation.localized, icon: "dollarsign.circle.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                // 价格与货币
                                HStack(alignment: .bottom, spacing: AppSpacing.md) {
                                    EnhancedNumberField(
                                        title: "任务酬金",
                                        placeholder: "0.00",
                                        value: $viewModel.price,
                                        prefix: viewModel.currency == "GBP" ? "£" : (viewModel.currency == "USD" ? "$" : "¥"),
                                        isRequired: true
                                    )
                                    
                                    CustomPickerField(
                                        title: LocalizationKey.createTaskCurrency.localized,
                                        selection: $viewModel.currency,
                                        options: [
                                            ("GBP", "GBP (£)"),
                                            ("CNY", "CNY (¥)"),
                                            ("USD", "USD ($)")
                                        ]
                                    )
                                    .frame(width: 110)
                                }
                                
                                // 城市
                                EnhancedTextField(
                                    title: "所在城市",
                                    placeholder: "例如: London / Birmingham",
                                    text: $viewModel.city,
                                    icon: "mappin.and.ellipse",
                                    isRequired: true
                                )
                                
                                // 任务类型
                                CustomPickerField(
                                    title: LocalizationKey.createTaskTaskType.localized,
                                    selection: $viewModel.taskType,
                                    options: viewModel.taskTypes.map { ($0.value, $0.label) },
                                    icon: "tag.fill"
                                )
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 3. 图片展示
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                SectionHeader(title: LocalizationKey.createTaskImages.localized, icon: "photo.on.rectangle.angled")
                                Spacer()
                                Text("\(viewModel.selectedImages.count)/5")
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primaryLight)
                                    .clipShape(Capsule())
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    // 添加按钮
                                    if viewModel.selectedImages.count < 5 {
                                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - viewModel.selectedImages.count, matching: .images) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "plus.viewfinder")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(AppColors.primary)
                                                Text(LocalizationKey.createTaskAddImages.localized)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            .frame(width: 90, height: 90)
                                            .background(AppColors.background)
                                            .cornerRadius(AppCornerRadius.medium)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                            )
                                        }
                                        .onChange(of: selectedItems) { _ in
                                            handleImageSelection()
                                        }
                                    }
                                    
                                    // 图片预览
                                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                            
                                            Button(action: {
                                                withAnimation {
                                                    viewModel.selectedImages.remove(at: index)
                                                    selectedItems = []
                                                    HapticFeedback.light()
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                IconStyle.icon("exclamationmark.octagon.fill", size: 16)
                                Text(errorMessage)
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
                            if appState.isAuthenticated {
                                HapticFeedback.success()
                                viewModel.createTask { success in
                                    if success {
                                        dismiss()
                                    }
                                }
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("paperplane.fill", size: 18)
                                }
                                Text(viewModel.isLoading ? "正在发布..." : "立即发布任务")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isLoading || viewModel.isUploading)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("发布任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .onAppear {
                if !appState.isAuthenticated {
                    showLogin = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleImageSelection() {
        _Concurrency.Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if viewModel.selectedImages.count < 5 {
                            viewModel.selectedImages.append(image)
                        }
                    }
                }
            }
            selectedItems = [] // 清空以备下次选择
        }
    }
}

