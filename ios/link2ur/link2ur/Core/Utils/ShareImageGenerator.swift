import UIKit
import SwiftUI

/// 分享图生成器 - 生成包含任务/活动信息的分享卡片
public class ShareImageGenerator {
    
    /// 获取当前用户语言
    private static var currentLanguage: String {
        LocalizationHelper.currentLanguage
    }
    
    /// 判断是否为中文
    private static var isChinese: Bool {
        currentLanguage.hasPrefix("zh")
    }
    
    /// 获取二维码提示文字（双语）
    private static var qrCodeHintText: String {
        isChinese ? "扫描二维码查看详情" : "Scan QR code for details"
    }
    
    /// 获取底部品牌文字（双语）
    private static var footerBrandText: String {
        isChinese ? "Link²Ur - 链接你的世界" : "Link²Ur - Link Your World"
    }
    
    /// 生成任务分享图
    /// - Parameters:
    ///   - task: 任务信息
    ///   - image: 任务图片（可选）
    ///   - url: 分享链接
    /// - Returns: 生成的分享图
    public static func generateTaskShareImage(
        title: String,
        description: String,
        taskType: String? = nil,
        location: String? = nil,
        reward: String? = nil,
        image: UIImage? = nil,
        url: URL
    ) -> UIImage? {
        let cardWidth: CGFloat = 800
        // 动态计算高度：根据是否有图片调整（减小总高度）
        // 限制最大高度，避免描述过长导致图片太长
        let baseHeight: CGFloat = 1000
        let imageHeight: CGFloat = image != nil ? 400 : 0
        let maxCardHeight: CGFloat = image != nil ? 1400 : 1200 // 最大高度限制
        let cardHeight: CGFloat = min(baseHeight + imageHeight, maxCardHeight)
        let padding: CGFloat = 36
        let cornerRadius: CGFloat = 24
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cardWidth, height: cardHeight), false, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 绘制渐变背景（从浅蓝到白色，带径向渐变装饰）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // 主渐变背景
        let mainColors = [
            UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
        ]
        guard let mainGradient = CGGradient(colorsSpace: colorSpace, colors: mainColors as CFArray, locations: [0.0, 0.5, 1.0]) else {
            return nil
        }
        context.drawLinearGradient(
            mainGradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: cardHeight),
            options: []
        )
        
        // 添加装饰性径向渐变（右上角）
        let radialColors = [
            UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor
        ]
        guard let radialGradient = CGGradient(colorsSpace: colorSpace, colors: radialColors as CFArray, locations: [0.0, 1.0]) else {
            return nil
        }
        let radialCenter = CGPoint(x: cardWidth * 0.85, y: cardHeight * 0.15)
        let radialRadius: CGFloat = cardWidth * 0.4
        context.drawRadialGradient(
            radialGradient,
            startCenter: radialCenter,
            startRadius: 0,
            endCenter: radialCenter,
            endRadius: radialRadius,
            options: []
        )
        
        // 添加左下角装饰渐变
        let bottomRadialCenter = CGPoint(x: cardWidth * 0.15, y: cardHeight * 0.85)
        context.drawRadialGradient(
            radialGradient,
            startCenter: bottomRadialCenter,
            startRadius: 0,
            endCenter: bottomRadialCenter,
            endRadius: radialRadius * 0.6,
            options: []
        )
        
        var currentY: CGFloat = padding + 20
        
        // 1. 顶部装饰区域（渐变条 + 装饰点）
        let topBarHeight: CGFloat = 6
        let topBarWidth: CGFloat = 140
        let topBarRect = CGRect(x: padding, y: currentY, width: topBarWidth, height: topBarHeight)
        
        // 绘制渐变装饰条
        let barGradientColors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        ]
        guard let barGradient = CGGradient(colorsSpace: colorSpace, colors: barGradientColors as CFArray, locations: [0.0, 1.0]) else {
            return nil
        }
        let barPath = UIBezierPath(roundedRect: topBarRect, cornerRadius: topBarHeight / 2)
        context.addPath(barPath.cgPath)
        context.clip()
        context.drawLinearGradient(
            barGradient,
            start: CGPoint(x: topBarRect.minX, y: topBarRect.midY),
            end: CGPoint(x: topBarRect.maxX, y: topBarRect.midY),
            options: []
        )
        context.resetClip()
        
        // 添加装饰点
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 12
        var dotX = topBarRect.maxX + 20
        for i in 0..<3 {
            let dotRect = CGRect(x: dotX, y: currentY + (topBarHeight - dotSize) / 2, width: dotSize, height: dotSize)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            let alpha = 1.0 - Double(i) * 0.3
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(alpha).cgColor)
            context.addPath(dotPath.cgPath)
            context.fillPath()
            dotX += dotSize + dotSpacing
        }
        
        currentY += topBarHeight + padding * 1.8
        
        // 2. Logo/App 名称区域（带背景卡片）
        let logoCardHeight: CGFloat = 100
        let logoCardRect = CGRect(
            x: padding,
            y: currentY,
            width: cardWidth - padding * 2,
            height: logoCardHeight
        )
        
        // 绘制卡片背景（带渐变和阴影效果）
        let logoCardPath = UIBezierPath(roundedRect: logoCardRect, cornerRadius: 24)
        
        // 卡片渐变背景
        let cardGradientColors = [
            UIColor.white.cgColor,
            UIColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0).cgColor
        ]
        guard let cardGradient = CGGradient(colorsSpace: colorSpace, colors: cardGradientColors as CFArray, locations: [0.0, 1.0]) else {
            return nil
        }
        context.addPath(logoCardPath.cgPath)
        context.clip()
        context.drawLinearGradient(
            cardGradient,
            start: CGPoint(x: logoCardRect.minX, y: logoCardRect.minY),
            end: CGPoint(x: logoCardRect.minX, y: logoCardRect.maxY),
            options: []
        )
        context.resetClip()
        
        // 添加边框
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1.5)
        context.addPath(logoCardPath.cgPath)
        context.strokePath()
        
        // 添加阴影
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 20, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        context.setFillColor(UIColor.clear.cgColor)
        context.addPath(logoCardPath.cgPath)
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // 加载并绘制 Logo（带渐变背景圆圈）
        if let logoImage = UIImage(named: "Logo") {
            let logoSize: CGFloat = 50
            let logoBgSize: CGFloat = logoSize + 10
            let logoBgRect = CGRect(
                x: logoCardRect.minX + 28,
                y: logoCardRect.midY - logoBgSize / 2,
                width: logoBgSize,
                height: logoBgSize
            )
            let logoRect = CGRect(
                x: logoBgRect.midX - logoSize / 2,
                y: logoBgRect.midY - logoSize / 2,
                width: logoSize,
                height: logoSize
            )
            
            // 绘制渐变圆形背景
            let logoBgGradientColors = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor
            ]
            guard let logoBgGradient = CGGradient(colorsSpace: colorSpace, colors: logoBgGradientColors as CFArray, locations: [0.0, 1.0]) else {
                return nil
            }
            let logoBgPath = UIBezierPath(ovalIn: logoBgRect)
            context.addPath(logoBgPath.cgPath)
            context.clip()
            context.drawRadialGradient(
                logoBgGradient,
                startCenter: CGPoint(x: logoBgRect.midX, y: logoBgRect.midY),
                startRadius: 0,
                endCenter: CGPoint(x: logoBgRect.midX, y: logoBgRect.midY),
                endRadius: logoBgSize / 2,
                options: []
            )
            context.resetClip()
            
            // 绘制 Logo（带圆角裁剪）
            let logoClipPath = UIBezierPath(ovalIn: logoRect)
            context.addPath(logoClipPath.cgPath)
            context.clip()
            logoImage.draw(in: logoRect)
            context.resetClip()
        }
        
        // App 名称（在 Logo 右侧，带渐变文字效果）
        let appName = "Link²Ur"
        
        // 绘制文字阴影（增强立体感）
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.systemBlue.withAlphaComponent(0.3)
        ]
        let appNameSize = (appName as NSString).size(withAttributes: shadowAttributes)
        let shadowRect = CGRect(
            x: logoCardRect.minX + 95 + 1.5,
            y: logoCardRect.midY - appNameSize.height / 2 + 1.5,
            width: appNameSize.width,
            height: appNameSize.height
        )
        (appName as NSString).draw(in: shadowRect, withAttributes: shadowAttributes)
        
        // 绘制主文字（带渐变）
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.systemBlue
        ]
        let appNameRect = CGRect(
            x: logoCardRect.minX + 95,
            y: logoCardRect.midY - appNameSize.height / 2,
            width: appNameSize.width,
            height: appNameSize.height
        )
        (appName as NSString).draw(in: appNameRect, withAttributes: appNameAttributes)
        currentY += logoCardRect.height + padding * 1.5
        
        // 3. 图片区域（如果有）- 带阴影和边框
        if let image = image {
            let imageHeight: CGFloat = 400
            let imageRect = CGRect(x: padding, y: currentY, width: cardWidth - padding * 2, height: imageHeight)
            
            // 绘制阴影
            let shadowRect = imageRect.offsetBy(dx: 0, dy: 6)
            let shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: cornerRadius)
            context.setFillColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            context.addPath(shadowPath.cgPath)
            context.fillPath()
            
            // 绘制圆角矩形背景（白色边框）
            let borderPath = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius)
            context.setFillColor(UIColor.white.cgColor)
            context.setLineWidth(4)
            context.setStrokeColor(UIColor.white.cgColor)
            context.addPath(borderPath.cgPath)
            context.fillPath()
            context.strokePath()
            
            // 绘制图片（带内边距）
            let imageInset: CGFloat = 4
            let imageContentRect = imageRect.insetBy(dx: imageInset, dy: imageInset)
            let imageContentPath = UIBezierPath(roundedRect: imageContentRect, cornerRadius: cornerRadius - imageInset)
            context.addPath(imageContentPath.cgPath)
            context.clip()
            
            let scaledImage = image.scaledToFill(size: imageContentRect.size)
            scaledImage?.draw(in: imageContentRect)
            
            context.resetClip()
            currentY += imageHeight + padding * 1.5
        }
        
        // 4. 标题（更大更醒目）
        let titleMaxHeight: CGFloat = image != nil ? 80 : 100
        let titleRect = CGRect(x: padding, y: currentY, width: cardWidth - padding * 2, height: titleMaxHeight)
        let titleFontSize: CGFloat = image != nil ? 32 : 36
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: titleFontSize, weight: .bold),
            .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 6
                style.alignment = .left
                return style
            }()
        ]
        let titleText = title
        let titleSize = (titleText as NSString).boundingRect(
            with: CGSize(width: titleRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: titleAttributes,
            context: nil
        )
        let actualTitleRect = CGRect(
            x: titleRect.origin.x,
            y: titleRect.origin.y,
            width: titleRect.width,
            height: min(titleSize.height, titleMaxHeight)
        )
        (titleText as NSString).draw(in: actualTitleRect, withAttributes: titleAttributes)
        currentY += actualTitleRect.height + (image != nil ? padding * 0.8 : padding * 1.2)
        
        // 5. 描述（优化样式，限制最大高度和字符数）
        let descriptionMaxHeight: CGFloat = image != nil ? 100 : 130
        let descriptionRect = CGRect(x: padding, y: currentY, width: cardWidth - padding * 2, height: descriptionMaxHeight)
        let descriptionFontSize: CGFloat = image != nil ? 22 : 24
        // 限制字符数，避免描述过长
        let descriptionMaxChars = image != nil ? 120 : 150
        let descriptionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: descriptionFontSize, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 5
                style.alignment = .left
                style.lineBreakMode = .byTruncatingTail // 超出部分截断
                return style
            }()
        ]
        // 截断描述文本
        let truncatedDescription = description.count > descriptionMaxChars 
            ? String(description.prefix(descriptionMaxChars)) + "..."
            : description
        let descriptionText = truncatedDescription
        let descriptionSize = (descriptionText as NSString).boundingRect(
            with: CGSize(width: descriptionRect.width, height: descriptionMaxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: descriptionAttributes,
            context: nil
        )
        let actualDescriptionRect = CGRect(
            x: descriptionRect.origin.x,
            y: descriptionRect.origin.y,
            width: descriptionRect.width,
            height: min(descriptionSize.height, descriptionMaxHeight)
        )
        (descriptionText as NSString).draw(in: actualDescriptionRect, withAttributes: descriptionAttributes)
        currentY += actualDescriptionRect.height + (image != nil ? padding * 1.0 : padding * 1.5)
        
        // 6. 任务信息卡片（任务类型、地点、金额）- 带渐变背景和图标
        if let taskType = taskType, let location = location, let reward = reward {
            let infoCardHeight: CGFloat = image != nil ? 85 : 100
            let infoCardRect = CGRect(x: padding, y: currentY, width: cardWidth - padding * 2, height: infoCardHeight)
            
            // 绘制信息卡片渐变背景
            let infoCardPath = UIBezierPath(roundedRect: infoCardRect, cornerRadius: 20)
            let infoCardGradientColors = [
                UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1.0).cgColor
            ]
            guard let infoCardGradient = CGGradient(colorsSpace: colorSpace, colors: infoCardGradientColors as CFArray, locations: [0.0, 1.0]) else {
                return nil
            }
            context.addPath(infoCardPath.cgPath)
            context.clip()
            context.drawLinearGradient(
                infoCardGradient,
                start: CGPoint(x: infoCardRect.minX, y: infoCardRect.minY),
                end: CGPoint(x: infoCardRect.minX, y: infoCardRect.maxY),
                options: []
            )
            context.resetClip()
            
            // 绘制装饰边框
            context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(2.5)
            context.addPath(infoCardPath.cgPath)
            context.strokePath()
            
            // 添加内部装饰线
            let innerLineY = infoCardRect.midY
            let innerLinePath = UIBezierPath()
            innerLinePath.move(to: CGPoint(x: infoCardRect.minX + 30, y: innerLineY))
            innerLinePath.addLine(to: CGPoint(x: infoCardRect.maxX - 30, y: innerLineY))
            context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
            context.setLineWidth(1)
            context.addPath(innerLinePath.cgPath)
            context.strokePath()
            
            // 绘制信息文本（带图标装饰）
            let infoFontSize: CGFloat = image != nil ? 20 : 22
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: infoFontSize, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]
            
            // 使用分隔符（双语通用）
            let separator = "  •  "
            let infoText = "\(taskType)\(separator)\(location)\(separator)\(reward)"
            let infoSize = (infoText as NSString).size(withAttributes: infoAttributes)
            let infoRect = CGRect(
                x: infoCardRect.midX - infoSize.width / 2,
                y: infoCardRect.midY - infoSize.height / 2,
                width: infoSize.width,
                height: infoSize.height
            )
            (infoText as NSString).draw(in: infoRect, withAttributes: infoAttributes)
            currentY += infoCardHeight + (image != nil ? padding * 1.5 : padding * 2.2)
        }
        
        // 7. 二维码区域（带背景卡片）- 优化间距
        let qrCodeSize: CGFloat = image != nil ? 160 : 180
        let qrCardPadding: CGFloat = image != nil ? 20 : 26
        let qrCardWidth = qrCodeSize + qrCardPadding * 2
        let qrCardHeight = qrCodeSize + qrCardPadding * 2 + (image != nil ? 50 : 65)
        let qrCardRect = CGRect(
            x: (cardWidth - qrCardWidth) / 2,
            y: currentY,
            width: qrCardWidth,
            height: qrCardHeight
        )
        
        // 绘制二维码卡片背景（带渐变）
        let qrCardPath = UIBezierPath(roundedRect: qrCardRect, cornerRadius: 32)
        
        // 卡片渐变背景
        let qrCardGradientColors = [
            UIColor.white.cgColor,
            UIColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0).cgColor
        ]
        guard let qrCardGradient = CGGradient(colorsSpace: colorSpace, colors: qrCardGradientColors as CFArray, locations: [0.0, 1.0]) else {
            return nil
        }
        context.addPath(qrCardPath.cgPath)
        context.clip()
        context.drawLinearGradient(
            qrCardGradient,
            start: CGPoint(x: qrCardRect.minX, y: qrCardRect.minY),
            end: CGPoint(x: qrCardRect.minX, y: qrCardRect.maxY),
            options: []
        )
        context.resetClip()
        
        // 添加装饰边框
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(2)
        context.addPath(qrCardPath.cgPath)
        context.strokePath()
        
        // 添加阴影
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 24, color: UIColor.black.withAlphaComponent(0.15).cgColor)
        context.setFillColor(UIColor.clear.cgColor)
        context.addPath(qrCardPath.cgPath)
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // 生成二维码（带装饰边框和背景）
        let qrCodeRect = CGRect(
            x: qrCardRect.midX - qrCodeSize / 2,
            y: qrCardRect.minY + qrCardPadding,
            width: qrCodeSize,
            height: qrCodeSize
        )
        
        // 绘制二维码外圈装饰
        let qrOuterRect = qrCodeRect.insetBy(dx: -12, dy: -12)
        let qrOuterPath = UIBezierPath(roundedRect: qrOuterRect, cornerRadius: 20)
        
        // 外圈渐变背景
        let qrOuterGradientColors = [
            UIColor.systemBlue.withAlphaComponent(0.1).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.05).cgColor
        ]
        guard let qrOuterGradient = CGGradient(colorsSpace: colorSpace, colors: qrOuterGradientColors as CFArray, locations: [0.0, 1.0]) else {
            return nil
        }
        context.addPath(qrOuterPath.cgPath)
        context.clip()
        context.drawRadialGradient(
            qrOuterGradient,
            startCenter: CGPoint(x: qrOuterRect.midX, y: qrOuterRect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: qrOuterRect.midX, y: qrOuterRect.midY),
            endRadius: qrOuterRect.width / 2,
            options: []
        )
        context.resetClip()
        
        // 绘制二维码白色背景（带圆角）
        let qrBgPath = UIBezierPath(roundedRect: qrCodeRect.insetBy(dx: -6, dy: -6), cornerRadius: 18)
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(qrBgPath.cgPath)
        context.fillPath()
        
        // 绘制二维码边框
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(3)
        context.addPath(qrBgPath.cgPath)
        context.strokePath()
        
        // 生成并绘制二维码
        if let qrImage = QRCodeGenerator.generate(
            content: url.absoluteString,
            size: CGSize(width: qrCodeSize, height: qrCodeSize)
        ) {
            // 绘制二维码（带圆角裁剪）
            let qrClipPath = UIBezierPath(roundedRect: qrCodeRect, cornerRadius: 12)
            context.addPath(qrClipPath.cgPath)
            context.clip()
            qrImage.draw(in: qrCodeRect)
            context.resetClip()
        }
        
        // 二维码下方提示文字（带图标装饰）- 双语支持
        let qrHintText = Self.qrCodeHintText
        let qrHintFontSize: CGFloat = image != nil ? 20 : 22
        let qrHintAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: qrHintFontSize, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ]
        let qrHintSize = (qrHintText as NSString).size(withAttributes: qrHintAttributes)
        let qrHintRect = CGRect(
            x: qrCardRect.midX - qrHintSize.width / 2,
            y: qrCodeRect.maxY + (image != nil ? 12 : 16),
            width: qrHintSize.width,
            height: qrHintSize.height
        )
        
        // 绘制文字阴影
        let qrHintShadowRect = qrHintRect.offsetBy(dx: 0, dy: 1)
        let qrHintShadowAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: qrHintFontSize, weight: .semibold),
            .foregroundColor: UIColor.systemBlue.withAlphaComponent(0.2)
        ]
        (qrHintText as NSString).draw(in: qrHintShadowRect, withAttributes: qrHintShadowAttributes)
        (qrHintText as NSString).draw(in: qrHintRect, withAttributes: qrHintAttributes)
        
        // 8. 底部品牌信息（带装饰线）
        let footerY = cardHeight - padding - 40
        
        // 绘制装饰分隔线
        let dividerWidth: CGFloat = 160
        let dividerRect = CGRect(
            x: cardWidth / 2 - dividerWidth / 2,
            y: footerY - 24,
            width: dividerWidth,
            height: 1.5
        )
        let dividerPath = UIBezierPath(roundedRect: dividerRect, cornerRadius: 1)
        let dividerGradientColors = [
            UIColor.clear.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.3).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        guard let dividerGradient = CGGradient(colorsSpace: colorSpace, colors: dividerGradientColors as CFArray, locations: [0.0, 0.3, 0.7, 1.0]) else {
            return nil
        }
        context.addPath(dividerPath.cgPath)
        context.clip()
        context.drawLinearGradient(
            dividerGradient,
            start: CGPoint(x: dividerRect.minX, y: dividerRect.midY),
            end: CGPoint(x: dividerRect.maxX, y: dividerRect.midY),
            options: []
        )
        context.resetClip()
        
        // 绘制品牌文字 - 双语支持
        let footerText = Self.footerBrandText
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .light),
            .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        ]
        let footerSize = (footerText as NSString).size(withAttributes: footerAttributes)
        let footerRect = CGRect(
            x: cardWidth / 2 - footerSize.width / 2,
            y: footerY,
            width: footerSize.width,
            height: footerSize.height
        )
        (footerText as NSString).draw(in: footerRect, withAttributes: footerAttributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 生成活动分享图
    public static func generateActivityShareImage(
        title: String,
        description: String,
        location: String? = nil,
        price: String? = nil,
        image: UIImage? = nil,
        url: URL
    ) -> UIImage? {
        return generateTaskShareImage(
            title: title,
            description: description,
            taskType: nil,
            location: location,
            reward: price,
            image: image,
            url: url
        )
    }
}

// MARK: - UIImage 扩展：图片缩放
extension UIImage {
    /// 缩放图片以填充指定尺寸
    func scaledToFill(size: CGSize) -> UIImage? {
        let scale = max(size.width / self.size.width, size.height / self.size.height)
        let scaledSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        self.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
