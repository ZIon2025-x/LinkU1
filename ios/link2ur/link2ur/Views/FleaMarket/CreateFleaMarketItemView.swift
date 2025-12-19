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
                VStack(spacing: AppSpacing.lg) {
                    // 标题
                    EnhancedTextField(
                        title: "商品标题",
                        placeholder: "请输入商品标题",
                        text: $viewModel.title,
                        icon: "tag.fill",
                        isRequired: true
                    )
                    
                    // 描述
                    EnhancedTextEditor(
                        title: "商品描述",
                        placeholder: "请详细描述商品信息、成色、使用情况等",
                        text: $viewModel.description,
                        height: 120,
                        isRequired: true,
                        characterLimit: 1000
                    )
                    
                    // 价格
                    EnhancedNumberField(
                        title: "价格",
                        placeholder: "0.00",
                        value: $viewModel.price,
                        prefix: "£",
                        suffix: "GBP",
                        isRequired: true
                    )
                    
                    // 分类
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("分类")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Picker("选择分类", selection: $viewModel.category) {
                            Text("请选择分类").tag("")
                            ForEach(viewModel.categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // 位置
                    EnhancedTextField(
                        title: "交易地点",
                        placeholder: "请输入地点或选择Online",
                        text: $viewModel.location,
                        icon: "mappin.circle.fill"
                    )
                    
                    // 联系方式
                    EnhancedTextField(
                        title: "联系方式",
                        placeholder: "请输入联系方式",
                        text: $viewModel.contact,
                        icon: "phone.fill",
                        keyboardType: .phonePad
                    )
                    
                    // 图片选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("商品图片（可选，最多5张）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("选择图片")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primaryLight)
                            .foregroundColor(AppColors.primary)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .onChange(of: selectedItems) { newValue in
                            AsyncTask {
                                viewModel.selectedImages = []
                                for item in newValue {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        viewModel.selectedImages.append(image)
                                    }
                                }
                            }
                        }
                        
                        // 图片预览
                        if !viewModel.selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                                            
                                            Button(action: {
                                                viewModel.selectedImages.remove(at: index)
                                                selectedItems.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 错误提示
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 提交按钮
                    Button(action: {
                        if appState.isAuthenticated {
                            viewModel.createItem { success in
                                if success {
                                    dismiss()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        if viewModel.isLoading || viewModel.isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("发布商品")
                                .fontWeight(.semibold)
                        }
                    }
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
                    .disabled(viewModel.isLoading || viewModel.isUploading)
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
}

