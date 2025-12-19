import SwiftUI
import PhotosUI
import UIKit

@available(iOS 16.0, *)
struct CreateTaskView: View {
    @StateObject private var viewModel = CreateTaskViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 标题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任务标题 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入任务标题", text: $viewModel.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任务描述 *")
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
                        Text("任务报酬")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        HStack {
                            TextField("0.00", value: $viewModel.price, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker("货币", selection: $viewModel.currency) {
                                Text("GBP").tag("GBP")
                                Text("CNY").tag("CNY")
                                Text("USD").tag("USD")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    // 城市
                    VStack(alignment: .leading, spacing: 8) {
                        Text("所在城市 *")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入城市", text: $viewModel.city)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // 任务类型
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任务类型")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Picker("任务类型", selection: $viewModel.taskType) {
                            Text("普通").tag("normal")
                            Text("紧急").tag("urgent")
                            Text("灵活").tag("flexible")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 图片选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任务图片（可选）")
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
                        .onChange(of: selectedItems) { newItems in
                            AsyncTask {
                                viewModel.selectedImages = []
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        if let image = UIImage(data: data) {
                                            viewModel.selectedImages.append(image)
                                        }
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
                    }
                    
                    // 提交按钮
                    Button(action: {
                        viewModel.createTask { success in
                            if success {
                                dismiss()
                            }
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("发布任务")
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
            .navigationTitle("发布任务")
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

