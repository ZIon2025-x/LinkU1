import SwiftUI

struct FleaMarketDetailView: View {
    let itemId: Int
    @StateObject private var viewModel = FleaMarketDetailViewModel()
    @State private var showPurchaseSheet = false
    @State private var purchaseType: PurchaseType = .direct
    @State private var proposedPrice: Double?
    @State private var purchaseMessage = ""
    
    enum PurchaseType {
        case direct
        case negotiate
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.item == nil {
                ProgressView()
            } else if let item = viewModel.item {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // 商品图片轮播
                        if let images = item.images, !images.isEmpty {
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
                                        .frame(width: 300, height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                            }
                        }
                        
                        // 商品信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(item.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack {
                                Text("¥ \(String(format: "%.2f", item.price))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.error)
                                
                                Text(item.currency)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            // 分类和状态
                            HStack(spacing: 8) {
                                Text(item.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primaryLight)
                                    .foregroundColor(AppColors.primary)
                                    .cornerRadius(6)
                                
                                Text(item.status == "active" ? "在售" : "已下架")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.status == "active" ? AppColors.success.opacity(0.15) : AppColors.textSecondary.opacity(0.15))
                                    .foregroundColor(item.status == "active" ? AppColors.success : AppColors.textSecondary)
                                    .cornerRadius(6)
                            }
                            
                            Divider()
                            
                            // 描述
                            if let description = item.description {
                                Text("商品描述")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // 卖家信息
                            if let seller = item.seller {
                                Divider()
                                
                                HStack {
                                    AsyncImage(url: URL(string: seller.avatar ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    
                                    Text(seller.username ?? seller.email)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Spacer()
                                }
                            }
                            
                            // 统计信息
                            HStack(spacing: 24) {
                                Label("\(item.viewCount)", systemImage: "eye")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
                        
                        // 购买按钮
                        if item.status == "active" {
                            VStack(spacing: AppSpacing.sm) {
                                Button(action: {
                                    purchaseType = .direct
                                    showPurchaseSheet = true
                                }) {
                                    Text("直接购买")
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
                                
                                Button(action: {
                                    purchaseType = .negotiate
                                    showPurchaseSheet = true
                                }) {
                                    Text("议价购买")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .foregroundColor(AppColors.primary)
                                        .background(AppColors.primaryLight)
                                        .cornerRadius(AppCornerRadius.medium)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseSheet(
                item: viewModel.item!,
                purchaseType: purchaseType,
                proposedPrice: $proposedPrice,
                message: $purchaseMessage,
                onPurchase: {
                    if purchaseType == .direct {
                        viewModel.directPurchase(itemId: itemId) { success in
                            if success {
                                showPurchaseSheet = false
                            }
                        }
                    } else {
                        viewModel.requestPurchase(itemId: itemId, proposedPrice: proposedPrice, message: purchaseMessage.isEmpty ? nil : purchaseMessage) { success in
                            if success {
                                showPurchaseSheet = false
                                proposedPrice = nil
                                purchaseMessage = ""
                            }
                        }
                    }
                }
            )
        }
        .onAppear {
            viewModel.loadItem(itemId: itemId)
        }
    }
}

// 购买弹窗
struct PurchaseSheet: View {
    let item: FleaMarketItem
    let purchaseType: FleaMarketDetailView.PurchaseType
    @Binding var proposedPrice: Double?
    @Binding var message: String
    let onPurchase: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                // 商品信息
                HStack {
                    if let images = item.images, let firstImage = images.first {
                        AsyncImage(url: URL(string: firstImage)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                .fill(AppColors.primaryLight)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text("¥ \(String(format: "%.2f", item.price))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.error)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppColors.primaryLight)
                .cornerRadius(AppCornerRadius.medium)
                
                if purchaseType == .negotiate {
                    // 议价金额
                    VStack(alignment: .leading, spacing: 8) {
                        Text("议价金额")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("请输入金额", value: $proposedPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                // 留言
                VStack(alignment: .leading, spacing: 8) {
                    Text("留言（可选）")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextEditor(text: $message)
                        .frame(height: 100)
                        .padding(8)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // 提交按钮
                Button(action: onPurchase) {
                    Text(purchaseType == .direct ? "确认购买" : "提交申请")
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
            .navigationTitle(purchaseType == .direct ? "确认购买" : "议价购买")
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

