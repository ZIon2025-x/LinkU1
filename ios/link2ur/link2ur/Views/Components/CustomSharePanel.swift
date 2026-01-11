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
                                shareToPlatform(platform)
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
        // 获取可用的分享平台
        availablePlatforms = CustomShareHelper.getAvailablePlatforms()
    }
    
    private func shareToPlatform(_ platform: SharePlatform) {
        guard !isSharing else { return }
        
        // 生成分享图功能特殊处理
        if platform == .generateImage {
            generateShareImage()
            return
        }
        
        isSharing = true
        HapticFeedback.selection()
        
        CustomShareHelper.shareToPlatform(
            platform,
            title: title,
            description: description,
            url: url,
            image: image
        )
        
        // 延迟关闭，让用户看到反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSharing = false
            if platform != .more {
                // 除了"更多"选项，其他平台分享后关闭面板
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
                        // 使用自定义logo图片
                        Image(customImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
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
