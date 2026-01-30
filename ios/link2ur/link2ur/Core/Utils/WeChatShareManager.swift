//
//  WeChatShareManager.swift
//  link2ur
//
//  微信分享管理器 - 使用微信SDK实现分享功能
//

import Foundation
import UIKit

// 注意：需要先集成 WechatOpenSDK.framework
// 如果SDK未集成，这些代码会编译失败
// 请按照 WECHAT_QQ_SDK_INTEGRATION.md 中的步骤集成SDK

#if canImport(WechatOpenSDK)
import WechatOpenSDK

/// 微信分享管理器
@objc public class WeChatShareManager: NSObject {
    public static let shared = WeChatShareManager()
    
    private override init() {
        super.init()
    }
    
    /// 检查微信是否已安装
    public static func isWeChatInstalled() -> Bool {
        return WXApi.isWXAppInstalled()
    }
    
    /// 检查微信是否支持分享
    public static func isWeChatSupportApi() -> Bool {
        return WXApi.isWXAppSupportApi()
    }
    
    /// 分享到微信好友或朋友圈
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述
    ///   - url: 分享链接
    ///   - image: 分享图片（可选）
    ///   - scene: 分享场景（0: 好友, 1: 朋友圈）
    ///   - completion: 完成回调
    public static func share(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        scene: Int32,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isWeChatInstalled() else {
            completion(false, "微信未安装")
            return
        }
        
        guard isWeChatSupportApi() else {
            completion(false, "微信版本过低，不支持分享")
            return
        }
        
        // 优化：在后台线程处理图片，避免阻塞主线程
        if let image = image {
            // 在后台线程压缩图片
            DispatchQueue.global(qos: .userInitiated).async {
                // 压缩主图片（用于分享）
                let compressedImageData = image.jpegData(compressionQuality: 0.85)
                
                // 生成缩略图
                let thumbImage = Self.resizeImage(image, to: CGSize(width: 150, height: 150))
                
                DispatchQueue.main.async {
                    // 创建分享请求
                    let req = SendMessageToWXReq()
                    req.scene = scene
                    
                    // 创建图片对象
                    let imageObject = WXImageObject()
                    imageObject.imageData = compressedImageData
                    
                    // 创建媒体消息对象
                    let message = WXMediaMessage()
                    message.title = title
                    message.description = description
                    message.mediaObject = imageObject
                    message.thumbImage = thumbImage
                    
                    req.bText = false
                    req.message = message
                    
                    // 发送分享请求
                    WXApi.send(req) { success in
                        DispatchQueue.main.async {
                            if success {
                                completion(true, nil)
                            } else {
                                completion(false, "分享失败")
                            }
                        }
                    }
                }
            }
        } else {
            // 创建分享请求
            let req = SendMessageToWXReq()
            req.scene = scene
            
            // 创建网页对象
            let webpageObject = WXWebpageObject()
            webpageObject.webpageUrl = url.absoluteString
            
            // 创建媒体消息对象
            let message = WXMediaMessage()
            message.title = title
            message.description = description
            message.mediaObject = webpageObject
            
            // 如果有默认图片，设置缩略图（在后台线程处理）
            if let defaultImage = UIImage(named: "Logo") {
                DispatchQueue.global(qos: .userInitiated).async {
                    let thumbImage = Self.resizeImage(defaultImage, to: CGSize(width: 150, height: 150))
                    DispatchQueue.main.async {
                        message.thumbImage = thumbImage
                        req.bText = false
                        req.message = message
                        
                        // 发送分享请求
                        WXApi.send(req) { success in
                            DispatchQueue.main.async {
                                if success {
                                    completion(true, nil)
                                } else {
                                    completion(false, "分享失败")
                                }
                            }
                        }
                    }
                }
            } else {
                req.bText = false
                req.message = message
                
                // 发送分享请求
                WXApi.send(req) { success in
                    DispatchQueue.main.async {
                        if success {
                            completion(true, nil)
                        } else {
                            completion(false, "分享失败")
                        }
                    }
                }
            }
        }
    }
    
    /// 分享到微信好友
    public static func shareToFriend(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        share(
            title: title,
            description: description,
            url: url,
            image: image,
            scene: 0, // WXSceneSession
            completion: completion
        )
    }
    
    /// 分享到朋友圈
    public static func shareToMoments(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        share(
            title: title,
            description: description,
            url: url,
            image: image,
            scene: 1, // WXSceneTimeline
            completion: completion
        )
    }
    
    /// 调整图片大小（用于缩略图）- 优化版本
    private static func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        // 使用 UIGraphicsImageRenderer，更高效且自动管理内存
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - WXApiDelegate

extension WeChatShareManager: WXApiDelegate {
    public func onReq(_ req: BaseReq!) {
        // 处理微信请求
    }
    
    public func onResp(_ resp: BaseResp!) {
        // 处理微信响应
        if let _ = resp as? SendMessageToWXResp {
        }
    }
}

#else
// SDK未集成时的占位实现
@objc public class WeChatShareManager: NSObject {
    public static let shared = WeChatShareManager()
    
    private override init() {
        super.init()
    }
    
    public static func isWeChatInstalled() -> Bool {
        return false
    }
    
    public static func isWeChatSupportApi() -> Bool {
        return false
    }
    
    public static func share(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        scene: Int,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "微信SDK未集成")
    }
    
    public static func shareToFriend(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "微信SDK未集成")
    }
    
    public static func shareToMoments(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "微信SDK未集成")
    }
}
#endif
