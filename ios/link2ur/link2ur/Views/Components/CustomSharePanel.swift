import SwiftUI

/// 自定义分享面板组件（类似小红书）
struct CustomSharePanel: View {
    let title: String
    let description: String
    let url: URL
    let image: UIImage?
    let taskType: String?
    let location: String?
    let reward: String?
    let onDismiss: () -> Void
    
    @State private var availablePlatforms: [SharePlatform] = []
    @State private var isSharing = false
    @State private var generatedShareImage: UIImage?
    @State private var isGeneratingImage = false
    @State private var showImageShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(LocalizationKey.shareShareTo.localized)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            
            Divider()
            
            // 分享平台网格
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.lg) {
                    ForEach(availablePlatforms, id: \.self) { platform in
                        SharePlatformButton(
                            platform: platform,
                            isInstalled: CustomShareHelper.isAppInstalled(platform),
                            onTap: {
                                // 使用主线程执行，确保UI响应流畅
                                DispatchQueue.main.async {
                                    shareToPlatform(platform)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            
        }
        .background(AppColors.background)
        .onAppear {
            loadAvailablePlatforms()
        }
        .sheet(isPresented: $showImageShareSheet) {
            if let shareImage = generatedShareImage {
                ImageShareSheet(image: shareImage, onDismiss: {
                    showImageShareSheet = false
                })
            }
        }
        .overlay {
            if isGeneratingImage {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(LocalizationKey.shareGeneratingImage.localized)
                            .font(AppTypography.body)
                            .foregroundColor(.white)
                    }
                    .padding(AppSpacing.lg)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(AppCornerRadius.large)
                }
            }
        }
    }
    
    private func loadAvailablePlatforms() {
        // 优化：在后台线程加载平台列表，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            let platforms = CustomShareHelper.getAvailablePlatforms()
            DispatchQueue.main.async {
                availablePlatforms = platforms
            }
        }
    }
    
    private func shareToPlatform(_ platform: SharePlatform) {
        // 防止重复点击
        guard !isSharing else { return }
        
        // 生成分享图功能特殊处理
        if platform == .generateImage {
            generateShareImage()
            return
        }
        
        isSharing = true
        HapticFeedback.selection()
        
        // 对于"更多"选项，先关闭面板，然后显示系统分享面板
        if platform == .more {
            // 立即关闭面板，给用户反馈
            onDismiss()
            
            // 延迟显示系统分享面板，确保sheet完全关闭
            // 使用稍长的延迟，确保动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                CustomShareHelper.shareToPlatform(
                    platform,
                    title: title,
                    description: description,
                    url: url,
                    image: image
                )
                // 延迟重置状态，避免在分享面板显示前被重置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSharing = false
                }
            }
        } else {
            // 其他平台：立即执行分享，然后关闭面板
            CustomShareHelper.shareToPlatform(
                platform,
                title: title,
                description: description,
                url: url,
                image: image
            )
            
            // 延迟关闭，让用户看到反馈
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSharing = false
                onDismiss()
            }
        }
    }
    
    private func generateShareImage() {
        isGeneratingImage = true
        HapticFeedback.selection()
        
        // 在后台线程生成图片
        DispatchQueue.global(qos: .userInitiated).async {
            let shareImage = ShareImageGenerator.generateTaskShareImage(
                title: title,
                description: description,
                taskType: taskType,
                location: location,
                reward: reward,
                image: image,
                url: url
            )
            
            DispatchQueue.main.async {
                isGeneratingImage = false
                if let shareImage = shareImage {
                    generatedShareImage = shareImage
                    showImageShareSheet = true
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
    }
}

/// 分享平台按钮
struct SharePlatformButton: View {
    let platform: SharePlatform
    let isInstalled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.xs) {
                // 图标
                ZStack {
                    Circle()
                        .fill(platform.color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    // 优先使用真实logo，如果没有则使用系统图标
                    if let customImageName = getCustomImageName(for: platform),
                       UIImage(named: customImageName) != nil {
                        // 使用自定义logo图片，根据平台调整大小
                        Image(customImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: getLogoSize(for: platform).width, 
                                   height: getLogoSize(for: platform).height)
                    } else {
                        // 使用系统图标作为后备
                        Image(systemName: getSystemIconName(for: platform))
                            .font(.system(size: 28))
                            .foregroundColor(platform.color)
                    }
                }
                
                // 平台名称
                Text(platform.displayName)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80, height: 90)
            .opacity(isInstalled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// 获取自定义图片资源名称（如果存在）
    private func getCustomImageName(for platform: SharePlatform) -> String? {
        switch platform {
        case .wechat:
            return "WeChatLogo"
        case .wechatMoments:
            return "WeChatMomentsLogo"
        case .qq:
            return "QQLogo"
        case .qzone:
            return "QZoneLogo"
        case .instagram:
            return "InstagramLogo"
        case .facebook:
            return "FacebookLogo"
        case .twitter:
            return "XLogo"
        case .weibo:
            return "WeiboLogo"
        default:
            return nil
        }
    }
    
    /// 获取不同平台的logo显示大小（根据实际logo设计调整）
    private func getLogoSize(for platform: SharePlatform) -> CGSize {
        switch platform {
        case .wechat:
            // 微信logo通常较小，需要放大一些
            return CGSize(width: 48, height: 48)
        case .wechatMoments:
            // 朋友圈保持原大小
            return CGSize(width: 40, height: 40)
        case .qq, .qzone:
            // QQ logo也需要放大
            return CGSize(width: 48, height: 48)
        case .instagram:
            // Instagram logo需要放大
            return CGSize(width: 48, height: 48)
        case .facebook:
            // Facebook logo需要放大
            return CGSize(width: 48, height: 48)
        case .weibo:
            // 微博logo需要放大
            return CGSize(width: 48, height: 48)
        case .twitter:
            // X logo太大，需要缩小
            return CGSize(width: 32, height: 32)
        default:
            // 默认大小
            return CGSize(width: 40, height: 40)
        }
    }
    
    private func getSystemIconName(for platform: SharePlatform) -> String {
        switch platform {
        case .wechat, .wechatMoments:
            return "message.fill"
        case .qq, .qzone:
            return "message.fill"
        case .instagram:
            return "camera.fill"
        case .facebook:
            return "person.2.fill"
        case .twitter:
            return "bird.fill"
        case .weibo:
            return "message.fill"
        case .sms:
            return "message.fill"
        case .copyLink:
            return "link"
        case .generateImage:
            return "photo"
        case .more:
            return "square.and.arrow.up"
        }
    }
}
