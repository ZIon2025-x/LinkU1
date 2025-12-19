import SwiftUI

struct WalletView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            EmptyStateView(
                icon: "wallet.pass.fill",
                title: "钱包功能",
                message: "钱包功能开发中，敬请期待..."
            )
        }
        .navigationTitle("我的钱包")
    }
}

