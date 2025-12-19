import SwiftUI

// MARK: - 广告轮播组件

struct BannerCarouselView: View {
    let banners: [Banner]
    @State private var currentIndex: Int = 0
    
    // 自动轮播定时器
    @State private var timer: Timer?
    
    private let cardHeight: CGFloat = 180 // 增加高度，更突出
    
    var body: some View {
        if banners.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                // 轮播内容
                TabView(selection: $currentIndex) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        BannerCard(banner: banners[index])
                            .padding(.horizontal, AppSpacing.md)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: cardHeight)
                .onAppear {
                    setupAutoScroll()
                }
                .onDisappear {
                    stopAutoScroll()
                }
                .onChange(of: currentIndex) { _ in
                    resetAutoScroll()
                }
                
                // 底部指示器 - 更现代的设计
                if banners.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<banners.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? AppColors.primary : AppColors.textTertiary.opacity(0.25))
                                .frame(width: index == currentIndex ? 24 : 6, height: 6)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // 设置自动轮播
    private func setupAutoScroll() {
        guard banners.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % banners.count
            }
        }
    }
    
    // 停止自动轮播
    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
    
    // 重置自动轮播
    private func resetAutoScroll() {
        stopAutoScroll()
        setupAutoScroll()
    }
}

// MARK: - 广告卡片

struct BannerCard: View {
    let banner: Banner
    
    var body: some View {
        Group {
            if let linkUrl = banner.linkUrl, !linkUrl.isEmpty {
                // 有链接时，使用 NavigationLink
                NavigationLink(destination: bannerDestination(linkUrl: linkUrl)) {
                    bannerImage
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 无链接时，直接显示图片（不可点击）
                bannerImage
            }
        }
    }
    
    // Banner 图片视图
    private var bannerImage: some View {
        ZStack(alignment: .bottomLeading) {
            // 图片
            AsyncImageView(
                urlString: banner.imageUrl,
                placeholder: Image(systemName: "photo.fill")
            )
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            
            // 渐变遮罩（底部，用于文字可读性）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .bottom)
            
            // 文字信息（如果有标题或副标题）
            if !banner.title.isEmpty || banner.subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if !banner.title.isEmpty {
                        Text(banner.title)
                            .font(AppTypography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .lineLimit(2)
                    }
                    if let subtitle = banner.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppTypography.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // 根据链接类型决定跳转目标
    @ViewBuilder
    private func bannerDestination(linkUrl: String) -> some View {
        if banner.linkType == "external" {
            // 外部链接 - 可以打开Safari或WebView
            WebView(urlString: linkUrl)
        } else {
            // 内部链接 - 根据路径跳转
            InternalLinkView(linkUrl: linkUrl)
        }
    }
}

// MARK: - 内部链接视图（根据URL路径跳转到不同页面）

struct InternalLinkView: View {
    let linkUrl: String
    
    var body: some View {
        Group {
            // 根据URL路径判断跳转到哪个页面
            if linkUrl.contains("/tasks/") {
                if let taskId = extractId(from: linkUrl, prefix: "/tasks/") {
                    TaskDetailView(taskId: taskId)
                } else {
                    TasksView()
                }
            } else if linkUrl.contains("/forum/") {
                if let postId = extractId(from: linkUrl, prefix: "/forum/posts/") {
                    ForumPostDetailView(postId: postId)
                } else {
                    ForumView()
                }
            } else if linkUrl.contains("/leaderboard/") {
                if let leaderboardId = extractId(from: linkUrl, prefix: "/leaderboard/") {
                    LeaderboardDetailView(leaderboardId: leaderboardId)
                } else {
                    LeaderboardView()
                }
            } else if linkUrl.contains("/flea-market/") {
                if let itemId = extractId(from: linkUrl, prefix: "/flea-market/items/") {
                    FleaMarketDetailView(itemId: String(itemId))
                } else {
                    FleaMarketView()
                }
            } else if linkUrl.contains("/activities/") {
                if let activityId = extractId(from: linkUrl, prefix: "/activities/") {
                    ActivityDetailView(activityId: activityId)
                } else {
                    ActivityListView()
                }
            } else {
                // 默认跳转到首页
                HomeView()
            }
        }
    }
    
    private func extractId(from url: String, prefix: String) -> Int? {
        guard let range = url.range(of: prefix) else { return nil }
        let afterPrefix = String(url[range.upperBound...])
        let idString = afterPrefix.components(separatedBy: "/").first ?? afterPrefix.components(separatedBy: "?").first
        return Int(idString ?? "")
    }
}

// MARK: - WebView（用于显示外部链接）

import WebKit

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
}
