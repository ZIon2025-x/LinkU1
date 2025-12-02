import SwiftUI

struct MyPostsView: View {
    @StateObject private var viewModel = MyPostsViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "cart.fill",
                    title: "暂无发布",
                    message: "您还没有发布任何商品"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.sm),
                        GridItem(.flexible(), spacing: AppSpacing.sm)
                    ], spacing: AppSpacing.md) {
                        ForEach(viewModel.items) { item in
                            NavigationLink(destination: FleaMarketDetailView(itemId: item.id)) {
                                ItemCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationTitle("我的发布")
        .refreshable {
            if let userId = appState.currentUser?.id {
                viewModel.loadMyItems(userId: String(userId))
            }
        }
        .onAppear {
            if viewModel.items.isEmpty, let userId = appState.currentUser?.id {
                viewModel.loadMyItems(userId: String(userId))
            }
        }
    }
}

