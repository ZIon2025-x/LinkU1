import SwiftUI
import PhotosUI

struct CreateFleaMarketItemView: View {
    @StateObject private var viewModel = CreateFleaMarketItemViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("商品标题 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入商品标题", text: $viewModel.title)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("商品描述 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextEditor(text: $viewModel.description)
                            .frame(height: 120)
                            .padding(8)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // 价格
                    VStack(alignment: .leading, spacing: 8) {
                        Text("价格 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack {
                            TextField("0.00", value: $viewModel.price, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            Text("GBP")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    // 分类
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类（可选）")
                            .font(.subheadline)
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
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // 位置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("交易地点（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入地点或选择Online", text: $viewModel.location)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // 联系方式
                    VStack(alignment: .leading, spacing: 8) {
                        Text("联系方式（可选）")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入联系方式", text: $viewModel.contact)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
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
                        .onChange(of: selectedItems) { items in
                            Task {
                                viewModel.selectedImages = []
                                for item in items {
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
                        viewModel.createItem { success in
                            if success {
                                dismiss()
                            }
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
            }
            .background(AppColors.background)
            .navigationTitle("发布商品")
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

