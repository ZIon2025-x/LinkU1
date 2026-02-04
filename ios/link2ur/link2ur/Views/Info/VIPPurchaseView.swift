import SwiftUI
import StoreKit

struct VIPPurchaseView: View {
    @StateObject private var iapService = IAPService.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 标题
                VStack(spacing: AppSpacing.sm) {
                    Text(LocalizationKey.vipBecomeVip.localized)
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.vipSelectPackage.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.md)
                
                // 产品列表
                if iapService.isLoading {
                    ProgressView()
                        .padding(AppSpacing.xl)
                } else if iapService.products.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(LocalizationKey.vipNoProducts.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(LocalizationKey.vipTryLaterContact.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.xl)
                } else {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(iapService.products) { product in
                            VIPProductRow(
                                product: product,
                                isSelected: selectedProduct?.id == product.id,
                                isPurchased: iapService.purchasedProducts.contains(product.id)
                            ) {
                                if !iapService.purchasedProducts.contains(product.id) {
                                    selectedProduct = product
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // 购买按钮
                if !iapService.products.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Button(action: {
                            purchaseSelectedProduct()
                        }) {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(selectedProduct == nil ? LocalizationKey.vipPleaseSelectPackage.localized : LocalizationKey.vipBuyNow.localized)
                                        .font(AppTypography.bodyBold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                selectedProduct == nil || isPurchasing
                                    ? AppColors.primary.opacity(0.5)
                                    : AppColors.primary
                            )
                            .cornerRadius(AppCornerRadius.large)
                        }
                        .disabled(selectedProduct == nil || isPurchasing || iapService.purchasedProducts.contains(selectedProduct?.id ?? ""))
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 恢复购买按钮
                        Button(action: {
                            restorePurchases()
                        }) {
                            Text(LocalizationKey.vipRestorePurchase.localized)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.bottom, AppSpacing.md)
                    }
                }
                
                // 错误消息
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, AppSpacing.md)
                }
                
                // 说明文字
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(LocalizationKey.vipPurchaseInstructions.localized)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(LocalizationKey.vipSubscriptionAutoRenew.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(LocalizationKey.vipManageSubscription.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(LocalizationKey.vipPurchaseEffective.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .padding(.horizontal, AppSpacing.md)
                
                // 隐私政策与服务条款（Guideline 3.1.2 - 订阅应用须在应用内提供可用的隐私政策与 Terms of Use 链接）
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    NavigationLink(destination: PrivacyWebView()) {
                        HStack {
                            Text(LocalizationKey.infoPrivacyPolicy.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    NavigationLink(destination: TermsWebView()) {
                        HStack {
                            Text(LocalizationKey.infoTermsOfService.localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .cornerRadius(AppCornerRadius.medium)
                .padding(.horizontal, AppSpacing.md)
                
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .navigationTitle(LocalizationKey.vipPurchaseTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(LocalizationKey.vipPurchaseSuccess.localized, isPresented: $showSuccessAlert) {
            Button(LocalizationKey.commonConfirm.localized) {
                dismiss()
                appState.checkLoginStatus()
            }
        } message: {
            Text(LocalizationKey.vipCongratulations.localized)
        }
        .task {
            await iapService.loadProducts()
            await iapService.updatePurchasedProducts()
        }
    }
    
    private func purchaseSelectedProduct() {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                _ = try await iapService.purchase(product)
                
                // 购买成功
                await MainActor.run {
                    isPurchasing = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    
                    if let iapError = error as? IAPError {
                        if iapError != .userCancelled {
                            errorMessage = iapError.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func restorePurchases() {
        _Concurrency.Task {
            do {
                try await iapService.restorePurchases()
                await MainActor.run {
                    errorMessage = nil
                    // 刷新用户信息
                    appState.checkLoginStatus()
                }
            } catch {
                await MainActor.run {
                    errorMessage = LocalizationKey.vipRestoreFailed.localized(error.localizedDescription)
                }
            }
        }
    }
}

struct VIPProductRow: View {
    let product: Product
    let isSelected: Bool
    let isPurchased: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // 选择指示器
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppColors.primary : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // 产品信息
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(product.displayName)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 价格
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Text(product.displayPrice)
                        .font(AppTypography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                    
                    if isPurchased {
                        Text(LocalizationKey.vipPurchased.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(
                isSelected
                    ? AppColors.primary.opacity(0.1)
                    : AppColors.cardBackground
            )
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(
                        isSelected ? AppColors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .disabled(isPurchased)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        VIPPurchaseView()
            .environmentObject(AppState())
    }
}
