import SwiftUI

/// Sheet iPad适配工具 - 提供统一的Sheet展示方式
public struct SheetAdaptation {
    
    /// Sheet展示类型
    public enum PresentationStyle {
        case sheet          // 标准Sheet（iPhone使用medium/large，iPad使用popover）
        case fullScreen     // 全屏展示（不适用popover）
        case custom         // 自定义展示方式
    }
    
    /// 为View添加iPad适配的Sheet展示方式
    /// - Parameters:
    ///   - view: 要展示的View
    ///   - style: 展示类型
    /// - Returns: 适配后的View
    public static func adaptSheet<T: View>(
        _ view: T,
        style: PresentationStyle = .sheet
    ) -> some View {
        if DeviceInfo.isPad {
            switch style {
            case .sheet:
                // iPad上使用popover（iOS 16.4+），提供更好的用户体验
                if #available(iOS 16.4, *) {
                    return AnyView(view.presentationCompactAdaptation(.popover))
                } else {
                    return AnyView(view)
                }
            case .fullScreen:
                // 全屏展示在iPad上保持全屏
                return AnyView(view)
            case .custom:
                // 自定义展示方式，保持原样
                return AnyView(view)
            }
        } else {
            // iPhone上使用标准的presentationDetents
            switch style {
            case .sheet:
                return AnyView(view.presentationDetents([.medium, .large]))
            case .fullScreen, .custom:
                return AnyView(view)
            }
        }
    }
}

/// View扩展 - Sheet iPad适配
extension View {
    /// 为Sheet添加iPad适配
    /// - Parameter style: 展示类型，默认为.sheet
    /// - Returns: 适配后的View
    public func adaptiveSheetPresentation(style: SheetAdaptation.PresentationStyle = .sheet) -> some View {
        return SheetAdaptation.adaptSheet(self, style: style)
    }
    
    /// 为Sheet添加iPad适配（带拖拽指示器）
    /// - Parameters:
    ///   - style: 展示类型，默认为.sheet
    ///   - showDragIndicator: 是否显示拖拽指示器
    /// - Returns: 适配后的View
    public func adaptiveSheetPresentation(
        style: SheetAdaptation.PresentationStyle = .sheet,
        showDragIndicator: Bool = true
    ) -> some View {
        let adaptedView = SheetAdaptation.adaptSheet(self, style: style)
        
        if showDragIndicator && !DeviceInfo.isPad {
            // 只在iPhone上显示拖拽指示器（iPad的popover不需要）
            return AnyView(adaptedView.presentationDragIndicator(.visible))
        } else {
            return AnyView(adaptedView)
        }
    }
}
