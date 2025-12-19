import UIKit
import CoreImage

/// 二维码生成器 - 企业级二维码工具
public struct QRCodeGenerator {
    
    /// 生成二维码图片
    public static func generate(
        content: String,
        size: CGSize = CGSize(width: 200, height: 200),
        correctionLevel: String = "M"
    ) -> UIImage? {
        guard let data = content.data(using: .utf8) else {
            return nil
        }
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        let scaleX = size.width / outputImage.extent.size.width
        let scaleY = size.height / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 生成带颜色的二维码
    public static func generateColored(
        content: String,
        size: CGSize = CGSize(width: 200, height: 200),
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white
    ) -> UIImage? {
        guard let qrImage = generate(content: content, size: size) else {
            return nil
        }
        
        guard let cgImage = qrImage.cgImage else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 应用颜色
        var fgR: CGFloat = 0, fgG: CGFloat = 0, fgB: CGFloat = 0, fgA: CGFloat = 0
        var bgR: CGFloat = 0, bgG: CGFloat = 0, bgB: CGFloat = 0, bgA: CGFloat = 0
        
        foregroundColor.getRed(&fgR, green: &fgG, blue: &fgB, alpha: &fgA)
        backgroundColor.getRed(&bgR, green: &bgG, blue: &bgB, alpha: &bgA)
        
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let alpha = CGFloat(pixelData[i + 3]) / 255.0
            
            if alpha > 0.5 {
                // 前景色
                pixelData[i] = UInt8(fgR * 255)
                pixelData[i + 1] = UInt8(fgG * 255)
                pixelData[i + 2] = UInt8(fgB * 255)
            } else {
                // 背景色
                pixelData[i] = UInt8(bgR * 255)
                pixelData[i + 1] = UInt8(bgG * 255)
                pixelData[i + 2] = UInt8(bgB * 255)
            }
        }
        
        guard let newCGImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: newCGImage)
    }
}

