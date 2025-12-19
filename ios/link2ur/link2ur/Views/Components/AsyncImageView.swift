import SwiftUI
import Foundation

// MARK: - 优化的异步图片组件

/// 优化的异步图片视图，带错误处理和占位符
struct AsyncImageView: View {
    let urlString: String?
    let placeholder: Image
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: ContentMode
    let cornerRadius: CGFloat
    
    init(
        urlString: String?,
        placeholder: Image = Image(systemName: "photo"),
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = 0
    ) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let urlString = urlString, !urlString.isEmpty {
                if let url = urlString.toImageURL() {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            // 加载中
                            placeholder
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: width, height: height)
                                .background(AppColors.cardBackground)
                                .cornerRadius(cornerRadius)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                )
                        case .success(let image):
                            // 加载成功
                            image
                                .resizable()
                                .aspectRatio(contentMode: contentMode)
                                .frame(width: width, height: height)
                                .cornerRadius(cornerRadius)
                        case .failure(let error):
                            // 加载失败
                            placeholder
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: width, height: height)
                                .background(AppColors.cardBackground)
                                .cornerRadius(cornerRadius)
                                .onAppear {
                                    Logger.debug("图片加载失败: \(url.absoluteString), 错误: \(error.localizedDescription)", category: .ui)
                                }
                        @unknown default:
                            placeholder
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: width, height: height)
                                .background(AppColors.cardBackground)
                                .cornerRadius(cornerRadius)
                        }
                    }
                } else {
                    // URL 转换失败
                    placeholder
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: width, height: height)
                        .background(AppColors.cardBackground)
                        .cornerRadius(cornerRadius)
                        .onAppear {
                            Logger.debug("URL 转换失败: \(urlString)", category: .ui)
                        }
                }
            } else {
                // URL 为空或无效
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: width, height: height)
                    .background(AppColors.cardBackground)
                    .cornerRadius(cornerRadius)
            }
        }
    }
}

/// 圆形头像视图
struct AvatarView: View {
    let urlString: String?
    let size: CGFloat
    let placeholder: Image
    let avatarType: AvatarType?
    
    /// 头像类型（用于明确指定使用哪种本地头像）
    enum AvatarType {
        case anonymous  // 匿名头像
        case service    // 客服头像
        case user(Int?) // 用户头像（1-5，nil 表示使用默认）
    }
    
    init(
        urlString: String? = nil,
        size: CGFloat = 40,
        placeholder: Image? = nil,
        avatarType: AvatarType? = nil
    ) {
        self.urlString = urlString
        self.size = size
        self.avatarType = avatarType
        // 如果没有提供 placeholder，使用本地默认头像
        self.placeholder = placeholder ?? Image("DefaultAvatar")
    }
    
    /// 解析 avatar 字符串，判断应该使用哪种头像
    private func parseAvatarString(_ avatar: String?) -> (isLocal: Bool, imageName: String?) {
        guard let avatar = avatar, !avatar.isEmpty else {
            return (isLocal: true, "DefaultAvatar")
        }
        
        // 检查是否是本地头像标识（直接匹配）
        if avatar == "any" {
            return (isLocal: true, "any")
        } else if avatar == "service" {
            return (isLocal: true, "service")
        } else if avatar == "avatar1" || avatar == "avatar2" || avatar == "avatar3" || avatar == "avatar4" || avatar == "avatar5" {
            return (isLocal: true, avatar)
        }
        
        // 检查是否是路径格式的本地头像（如 /static/avatar1.png）
        if avatar.hasPrefix("/static/") {
            let fileName = String(avatar.dropFirst(8)) // 去掉 "/static/" 前缀
            let nameWithoutExt = fileName.replacingOccurrences(of: ".png", with: "").replacingOccurrences(of: ".jpg", with: "")
            
            // 检查是否是本地头像
            if nameWithoutExt == "any" || nameWithoutExt == "service" {
                return (isLocal: true, nameWithoutExt)
            } else if nameWithoutExt.hasPrefix("avatar") {
                let indexStr = String(nameWithoutExt.dropFirst(6)) // 去掉 "avatar" 前缀
                if let index = Int(indexStr), index >= 1 && index <= 5 {
                    return (isLocal: true, nameWithoutExt)
                }
            }
        }
        
        // 检查是否以 "avatar" 开头（如 avatar1, avatar2 等）
        if avatar.hasPrefix("avatar") {
            let indexStr = String(avatar.dropFirst(6)) // 去掉 "avatar" 前缀
            if let index = Int(indexStr), index >= 1 && index <= 5 {
                return (isLocal: true, avatar)
            }
        }
        
        // 如果是完整 URL（http/https），从服务器加载
        if avatar.hasPrefix("http://") || avatar.hasPrefix("https://") {
            return (isLocal: false, nil)
        }
        
        // 如果是相对路径（以 / 开头），从服务器加载
        if avatar.hasPrefix("/") {
            return (isLocal: false, nil)
        }
        
        // 其他情况，尝试作为本地图片名称
        return (isLocal: true, avatar)
    }
    
    /// 根据 avatarType 获取图片名称
    private func getImageName(from avatarType: AvatarType) -> String {
        switch avatarType {
        case .anonymous:
            return "any"
        case .service:
            return "service"
        case .user(let index):
            if let index = index, index >= 1 && index <= 5 {
                return "avatar\(index)"
            } else {
                return "DefaultAvatar"
            }
        }
    }
    
    var body: some View {
        Group {
            // 如果明确指定了 avatarType，优先使用
            if let avatarType = avatarType {
                Image(getImageName(from: avatarType))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            // 否则解析 urlString
            else {
                avatarContent
            }
        }
    }
    
    /// 根据 urlString 渲染头像内容
    @ViewBuilder
    private var avatarContent: some View {
        let (isLocal, imageName) = parseAvatarString(urlString)
        
        if isLocal, let imageName = imageName {
            // 使用本地头像
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let urlString = urlString, !urlString.isEmpty {
            // 从服务器加载
            AsyncImageView(
                urlString: urlString,
                placeholder: placeholder,
                width: size,
                height: size,
                contentMode: .fill,
                cornerRadius: size / 2
            )
            .clipShape(Circle())
            .onAppear {
                Logger.debug("AvatarView 从服务器加载，urlString: \(urlString)", category: .ui)
                if let fullURL = urlString.toImageURL() {
                    Logger.debug("AvatarView 转换后的完整 URL: \(fullURL.absoluteString)", category: .ui)
                }
            }
        } else {
            // 使用默认头像
            placeholder
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }
}
