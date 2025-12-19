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
                            // 标题区域
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                                Text("基本信息")
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                            
                            VStack(spacing: AppSpacing.md) {
                                // 标题
                                EnhancedTextField(
                                    title: nil,
                                    placeholder: "任务标题 (例如：急求代取快递)",
                                    text: $viewModel.title,
                                    icon: "text.bubble.fill",
                                    isRequired: true
                                )
                                
                                // 描述
                                EnhancedTextEditor(
                                    title: "任务描述",
                                    placeholder: "请详细描述您的需求、时间、地点等信息",
                                    text: $viewModel.description,
                                    height: 120,
                                    isRequired: true,
                                    characterLimit: 1000
                                )
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.md)
                        }
                        .cardStyle(useMaterial: true)
                        
                        // 2. 报酬与地点
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // 标题区域
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                                Text("报酬与地点")
                                    .font(AppTypography.title3)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                            
                            VStack(spacing: AppSpacing.md) {
                                // 价格与货币
                                HStack(spacing: AppSpacing.md) {
                                    EnhancedNumberField(
                                        title: nil,
                                        placeholder: "0.00",
                                        value: $viewModel.price,
                                        prefix: "£"
                                    )
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("货币")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Picker("货币", selection: $viewModel.currency) {
                                            Text("GBP").tag("GBP")
                                            Text("CNY").tag("CNY")
                                            Text("USD").tag("USD")
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, AppSpacing.sm)
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(AppCornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .frame(width: 100)
                                }
                                
                                // 城市
                                EnhancedTextField(
                                    title: nil,
                                    placeholder: "所在城市",
                                    text: $viewModel.city,
                                    icon: "mappin.circle.fill"
                                )
                                
                                // 任务类型
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("任务类型")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Picker("任务类型", selection: $viewModel.taskType) {
                                        ForEach(viewModel.taskTypes, id: \.value) { taskType in
                                            Text(taskType.label).tag(taskType.value)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(AppCornerRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                            .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.md)
                        }
                        .cardStyle(useMaterial: true)
                        
                        // 3. 图片
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            // 标题区域
                            HStack {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(AppColors.primary)
                                    Text("图片")
                                        .font(AppTypography.title3)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                Spacer()
                                Text("\(viewModel.selectedImages.count)/5")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primaryLight)
                                    .cornerRadius(AppCornerRadius.small)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    // 添加按钮
                                    if viewModel.selectedImages.count < 5 {
                                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - viewModel.selectedImages.count, matching: .images) {
                                            VStack(spacing: AppSpacing.sm) {
                                                ZStack {
                                                    Circle()
                                                        .fill(AppColors.primaryLight)
                                                        .frame(width: 48, height: 48)
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.system(size: 24, weight: .medium))
                                                        .foregroundColor(AppColors.primary)
                                                }
                                                Text("添加图片")
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            .frame(width: 100, height: 100)
                                            .background(AppColors.cardBackground)
                                            .cornerRadius(AppCornerRadius.medium)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                                                    .foregroundColor(AppColors.primary.opacity(0.4))
                                            )
                                        }
                                    }
                                    
                                    // 图片预览
                                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                        .stroke(AppColors.separator.opacity(0.2), lineWidth: 1)
                                                )
                                            
                                            Button(action: {
                                                viewModel.selectedImages.remove(at: index)
                                                selectedItems = []
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                            .frame(width: 24, height: 24)
                                                    )
                                            }
                                            .padding(6)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, 4)
                            }
                            .padding(.bottom, AppSpacing.md)
                        }
                        .cardStyle(useMaterial: true)
                        
                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(errorMessage)
                                    .font(AppTypography.body)
                            }
                            .foregroundColor(AppColors.error)
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.errorLight)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.error.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // 提交按钮
                        Button(action: {
                            if appState.isAuthenticated {
                                viewModel.createTask { success in
                                    if success {
                                        dismiss()
                                    }
                                }
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(viewModel.isLoading ? "发布中..." : "立即发布")
                                    .font(AppTypography.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: AppColors.primary.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(viewModel.isLoading || viewModel.isUploading)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, 20)
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
}

