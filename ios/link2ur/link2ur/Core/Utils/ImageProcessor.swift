import UIKit
import SwiftUI

/// 图片处理工具 - 企业级图片处理
public struct ImageProcessor {
    
    /// 调整图片大小
    public static func resize(_ image: UIImage, to size: CGSize, quality: CGFloat = 1.0) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, quality)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 压缩图片
    public static func compress(_ image: UIImage, quality: CGFloat = 0.8, maxSize: Int = 1024 * 1024) -> Data? {
        var compression: CGFloat = quality
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSize && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    /// 裁剪图片
    public static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// 添加圆角
    public static func roundedCorners(_ image: UIImage, radius: CGFloat) -> UIImage? {
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()
        context?.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
        context?.clip()
        
        image.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 转换为圆形
    public static func circular(_ image: UIImage) -> UIImage? {
        let size = min(image.size.width, image.size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()
        context?.addEllipse(in: rect)
        context?.clip()
        
        image.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 添加水印
    public static func addWatermark(
        _ image: UIImage,
        text: String,
        position: CGPoint,
        attributes: [NSAttributedString.Key: Any]? = nil
    ) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(at: .zero)
        
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2
        ]
        
        let finalAttributes = attributes ?? defaultAttributes
        (text as NSString).draw(at: position, withAttributes: finalAttributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

