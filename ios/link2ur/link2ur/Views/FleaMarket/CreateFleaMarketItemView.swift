import SwiftUI
import PhotosUI
import UIKit

@available(iOS 16.0, *)
struct CreateFleaMarketItemView: View {
    @StateObject private var viewModel = CreateFleaMarketItemViewModel()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: AppSpacing.xl) {
                    // 1. 基本信息
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "商品信息", icon: "bag.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 标题
                            EnhancedTextField(
                                title: "商品标题",
                                placeholder: "品牌、型号、成色等 (例: iPhone 15 Pro)",
                                text: $viewModel.title,
                                icon: "tag.fill",
                                isRequired: true
                            )
                            
                            // 分类
                            CustomPickerField(
                                title: "商品分类",
                                selection: $viewModel.category,
                                options: viewModel.categories.map { ($0, $0) },
                                icon: "list.bullet.indent"
                            )
                            
                            // 描述
                            EnhancedTextEditor(
                                title: "详情描述",
                                placeholder: "请详细描述商品信息、成色、使用情况、转手原因等...",
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
                    
                    // 2. 价格与交易
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "价格与交易", icon: "dollarsign.circle.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 价格
                            EnhancedNumberField(
                                title: "出售价格",
                                placeholder: "0.00",
                                value: $viewModel.price,
                                prefix: "£",
                                suffix: "GBP",
                                isRequired: true
                            )
                            
                            // 位置
                            EnhancedTextField(
                                title: "交易地点",
                                placeholder: "请输入地点或 Online",
                                text: $viewModel.location,
                                icon: "mappin.and.ellipse"
                            )
                            
                            // 联系方式
                            EnhancedTextField(
                                title: "联系方式",
                                placeholder: "微信、电话或 WhatsApp",
                                text: $viewModel.contact,
                                icon: "phone.fill"
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
                            SectionHeader(title: "商品图片", icon: "photo.on.rectangle.angled")
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
                                            Text("添加图片")
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
                            viewModel.createItem { success in
                                if success {
                                    dismiss()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading || viewModel.isUploading {
                                ProgressView().tint(.white)
                            } else {
                                IconStyle.icon("cart.fill.badge.plus", size: 18)
                            }
                            Text(viewModel.isLoading || viewModel.isUploading ? "正在发布..." : "立即发布商品")
                                .font(AppTypography.bodyBold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading || viewModel.isUploading || viewModel.title.isEmpty || viewModel.price == nil)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .padding(AppSpacing.md)
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("发布商品")
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

