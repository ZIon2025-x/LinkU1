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
            ZStack(alignment: .bottom) {
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
                
                // 底部指示器 - 悬浮在 Banner 上方，更现代的设计
                if banners.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<banners.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: index == currentIndex ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                }
            }
            .onAppear {
                setupAutoScroll()
            }
            .onDisappear {
                stopAutoScroll()
            }
            .onChange(of: currentIndex) { _ in
                resetAutoScroll()
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
    @State private var navigateToInternal = false
    @State private var navigateToExternal = false
    
    var body: some View {
        Group {
            if let linkUrl = banner.linkUrl, !linkUrl.isEmpty {
                bannerImage
                    .onTapGesture {
                        if banner.linkType == "external" {
                            navigateToExternal = true
                        } else {
                            navigateToInternal = true
                        }
                    }
                    .background(
                        Group {
                            NavigationLink(
                                destination: InternalLinkView(linkUrl: linkUrl),
                                isActive: $navigateToInternal
                            ) { EmptyView() }
                            .hidden()
                            
                            NavigationLink(
                                destination: WebView(urlString: linkUrl)
                                    .navigationTitle("Link2Ur")
                                    .navigationBarTitleDisplayMode(.inline),
                                isActive: $navigateToExternal
                            ) { EmptyView() }
                            .hidden()
                        }
                    )
            } else {
                bannerImage
            }
        }
    }
    
    // Banner 图片视图
    private var bannerImage: some View {
        ZStack(alignment: .bottomLeading) {
            // 图片 - 支持本地图片和远程图片
            Group {
                if banner.imageUrl.hasPrefix("local:") {
                    // 本地图片（从Assets加载）
                    let imageName = String(banner.imageUrl.dropFirst(6)) // 去掉 "local:" 前缀
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        // 如果是跳蚤市场Banner，向上偏移显示更多顶部内容
                        .offset(y: banner.linkUrl == "/flea-market" ? -50 : 0)
                } else {
                    // 远程图片
                    AsyncImageView(
                        urlString: banner.imageUrl,
                        placeholder: Image(systemName: "photo.fill")
                    )
                    .offset(y: banner.linkUrl == "/flea-market" ? -50 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            
            // 底部内容遮罩（更柔和的渐变，增强沉浸感）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.2),
                    Color.clear
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            
            // 文字信息（使用更精致的排版）
            if !banner.title.isEmpty || banner.subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if !banner.title.isEmpty {
                        Text(banner.title)
                            .font(AppTypography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    if let subtitle = banner.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24) // 为指示器留出更多空间
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
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
            } else if linkUrl.contains("/flea-market") {
                // 检查是否是商品详情页（包含item ID）
                if let itemId = extractId(from: linkUrl, prefix: "/flea-market/items/") {
                    FleaMarketDetailView(itemId: String(itemId))
                } else if let itemId = extractId(from: linkUrl, prefix: "/flea-market/") {
                    // 支持 /flea-market/{itemId} 格式
                    FleaMarketDetailView(itemId: String(itemId))
                } else {
                    // 跳转到跳蚤市场列表页
                    FleaMarketView()
                }
            } else if linkUrl.contains("/activities/") {
                if let activityId = extractId(from: linkUrl, prefix: "/activities/") {
                    ActivityDetailView(activityId: activityId)
                } else {
                    ActivityListView()
                }
            } else if linkUrl.contains("/student-verification") {
                // 学生认证页面
                StudentVerificationView()
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
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if the webview has no content yet (avoid reload on every SwiftUI update)
    }
}
