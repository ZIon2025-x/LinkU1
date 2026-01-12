//
//  QQShareManager.swift
//  link2ur
//
//  QQ分享管理器 - 使用QQ SDK实现分享功能
//

import Foundation
import UIKit

// 注意：需要先集成 TencentOpenAPI.framework
// 如果SDK未集成，这些代码会编译失败
// 请按照 WECHAT_QQ_SDK_INTEGRATION.md 中的步骤集成SDK

#if canImport(TencentOpenAPI)
import TencentOpenAPI

/// QQ分享管理器
@objc public class QQShareManager: NSObject {
    public static let shared = QQShareManager()
    
    private override init() {
        super.init()
    }
    
    /// 检查QQ是否已安装
    public static func isQQInstalled() -> Bool {
        return QQApiInterface.isQQInstalled()
    }
    
    /// 检查QQ是否支持分享
    public static func isQQSupportApi() -> Bool {
        return QQApiInterface.isQQSupportApi()
    }
    
    /// 分享到QQ好友或QQ空间
    /// - Parameters:
    ///   - title: 标题
    ///   - description: 描述
    ///   - url: 分享链接
    ///   - image: 分享图片（可选）
    ///   - toQZone: 是否分享到QQ空间（false为QQ好友）
    ///   - completion: 完成回调
    public static func share(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        toQZone: Bool = false,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isQQInstalled() else {
            completion(false, "QQ未安装")
            return
        }
        
        guard isQQSupportApi() else {
            completion(false, "QQ版本过低，不支持分享")
            return
        }
        
        // 优化：在后台线程处理图片，避免阻塞主线程
        if let image = image {
            // 在后台线程压缩图片
            DispatchQueue.global(qos: .userInitiated).async {
                guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                    DispatchQueue.main.async {
                        completion(false, "图片压缩失败")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    // 创建网页对象
                    let webpageObject = QQApiNewsObject.object(
                        with: URL(string: url.absoluteString),
                        title: title,
                        description: description,
                        previewImageData: imageData,
                        targetContentType: QQApiURLTargetTypeNews
                    ) as! QQApiNewsObject
                    
                    // 创建分享请求
                    let req = SendMessageToQQReq(content: webpageObject)
                    
                    // 发送分享请求
                    let result: QQApiSendResultCode
                    if toQZone {
                        result = QQApiInterface.sendReq(toQZone: req)
                    } else {
                        result = QQApiInterface.send(req)
                    }
                    
                    Self.handleQQShareResult(result: result, completion: completion)
                }
            }
        } else {
            // 无图片时，使用URL
            let previewImageURL: URL?
            if let defaultImageURL = Bundle.main.url(forResource: "Logo", withExtension: "png") {
                previewImageURL = defaultImageURL
            } else {
                previewImageURL = nil
            }
            
            let webpageObject = QQApiNewsObject.object(
                with: URL(string: url.absoluteString),
                title: title,
                description: description,
                previewImageURL: previewImageURL,
                targetContentType: QQApiURLTargetTypeNews
            ) as! QQApiNewsObject
            
            // 创建分享请求
            let req = SendMessageToQQReq(content: webpageObject)
            
            // 发送分享请求
            let result: QQApiSendResultCode
            if toQZone {
                result = QQApiInterface.sendReq(toQZone: req)
            } else {
                result = QQApiInterface.send(req)
            }
            
            Self.handleQQShareResult(result: result, completion: completion)
        }
    }
    
    /// 处理QQ分享结果
    private static func handleQQShareResult(result: QQApiSendResultCode, completion: @escaping (Bool, String?) -> Void) {
        switch result {
        case EQQAPISENDSUCESS:
            completion(true, nil)
        case EQQAPIQQNOTINSTALLED:
            completion(false, "QQ未安装")
        case EQQAPIQQNOTSUPPORTAPI:
            completion(false, "QQ版本过低，不支持分享")
        case EQQAPIMESSAGETYPEINVALID, EQQAPIMESSAGECONTENTNULL, EQQAPIMESSAGECONTENTINVALID:
            completion(false, "分享内容无效")
        case EQQAPIAPPNOTREGISTED:
            completion(false, "应用未注册")
        case EQQAPIAPPSHAREASYNC:
            // 异步分享，等待回调
            completion(true, nil)
        default:
            completion(false, "分享失败，错误码: \(result.rawValue)")
        }
    }
    
    /// 分享到QQ好友
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
            toQZone: false,
            completion: completion
        )
    }
    
    /// 分享到QQ空间
    public static func shareToQZone(
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
            toQZone: true,
            completion: completion
        )
    }
}

// MARK: - TencentSessionDelegate

extension QQShareManager: TencentSessionDelegate {
    public func tencentDidLogin() {
        // QQ登录成功
    }
    
    public func tencentDidNotLogin(_ cancelled: Bool) {
        // QQ登录失败
    }
    
    public func tencentDidNotNetWork() {
        // 网络错误
    }
}

#else
// SDK未集成时的占位实现
@objc public class QQShareManager: NSObject {
    public static let shared = QQShareManager()
    
    private override init() {
        super.init()
    }
    
    public static func isQQInstalled() -> Bool {
        return false
    }
    
    public static func isQQSupportApi() -> Bool {
        return false
    }
    
    public static func share(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        toQZone: Bool = false,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "QQ SDK未集成")
    }
    
    public static func shareToFriend(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "QQ SDK未集成")
    }
    
    public static func shareToQZone(
        title: String,
        description: String,
        url: URL,
        image: UIImage? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        completion(false, "QQ SDK未集成")
    }
}
#endif
