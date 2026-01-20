import SwiftUI

/// 自适应布局工具 - iPad适配
public struct AdaptiveLayout {
    
    /// 网格项类型
    public enum GridItemType {
        case task          // 任务卡片
        case fleaMarket    // 跳蚤市场商品
        case standard      // 默认
    }
    
    /// 根据设备类型和SizeClass返回合适的网格列数
    /// - Parameters:
    ///   - horizontalSizeClass: 水平SizeClass
    ///   - itemType: 网格项类型
    /// - Returns: 网格列数
    public static func gridColumnCount(
        horizontalSizeClass: UserInterfaceSizeClass?,
        itemType: GridItemType = .standard
    ) -> Int {
        let isPad = DeviceInfo.isPad
        let isRegular = horizontalSizeClass == .regular
        let currentiPadModel: DeviceInfo.iPadModelType = DeviceInfo.iPadModel
        
        if isPad {
            if isRegular {
                // iPad横屏
                switch currentiPadModel {
                case .mini:
                    // iPad Mini: 屏幕较小，减少列数
                    switch itemType {
                    case .task:
                        return 2
                    case .fleaMarket:
                        return 3
                    case .standard:
                        return 2
                    }
                case .pro12_9:
                    // iPad Pro 12.9英寸: 屏幕最大，可以显示更多列
                    switch itemType {
                    case .task:
                        return 4
                    case .fleaMarket:
                        return 5
                    case .standard:
                        return 4
                    }
                case .pro11, .air:
                    // iPad Pro 11英寸和iPad Air: 中等屏幕
                    switch itemType {
                    case .task:
                        return 3
                    case .fleaMarket:
                        return 4
                    case .standard:
                        return 3
                    }
                case .standard, .unknown:
                    // 标准iPad: 默认配置
                    switch itemType {
                    case .task:
                        return 3
                    case .fleaMarket:
                        return 4
                    case .standard:
                        return 3
                    }
                }
            } else {
                // iPad竖屏
                switch currentiPadModel {
                case .mini:
                    // iPad Mini: 屏幕较小，减少列数
                    switch itemType {
                    case .task:
                        return 2
                    case .fleaMarket:
                        return 2
                    case .standard:
                        return 2
                    }
                case .pro12_9:
                    // iPad Pro 12.9英寸: 屏幕最大，可以显示更多列
                    switch itemType {
                    case .task:
                        return 3
                    case .fleaMarket:
                        return 4
                    case .standard:
                        return 3
                    }
                case .pro11, .air:
                    // iPad Pro 11英寸和iPad Air: 中等屏幕
                    switch itemType {
                    case .task:
                        return 2
                    case .fleaMarket:
                        return 3
                    case .standard:
                        return 2
                    }
                case .standard, .unknown:
                    // 标准iPad: 默认配置
                    switch itemType {
                    case .task:
                        return 2
                    case .fleaMarket:
                        return 3
                    case .standard:
                        return 2
                    }
                }
            }
        } else {
            // iPhone
            return 2
        }
    }
    
    /// 创建自适应网格列
    /// - Parameters:
    ///   - horizontalSizeClass: 水平SizeClass
    ///   - itemType: 网格项类型
    ///   - spacing: 列间距
    /// - Returns: GridItem数组
    public static func adaptiveGridColumns(
        horizontalSizeClass: UserInterfaceSizeClass?,
        itemType: GridItemType = .standard,
        spacing: CGFloat = 16 // AppSpacing.md
    ) -> [GridItem] {
        let columnCount = gridColumnCount(horizontalSizeClass: horizontalSizeClass, itemType: itemType)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
    }
    
    /// 计算自适应卡片宽度
    /// - Parameters:
    ///   - screenWidth: 屏幕宽度
    ///   - columnCount: 列数
    ///   - horizontalPadding: 水平内边距
    ///   - columnSpacing: 列间距
    /// - Returns: 卡片宽度
    public static func cardWidth(
        screenWidth: CGFloat,
        columnCount: Int,
        horizontalPadding: CGFloat = 32, // AppSpacing.md * 2
        columnSpacing: CGFloat = 16 // AppSpacing.md
    ) -> CGFloat {
        let totalSpacing = columnSpacing * CGFloat(columnCount - 1)
        let availableWidth = screenWidth - horizontalPadding - totalSpacing
        return availableWidth / CGFloat(columnCount)
    }
    
    /// 获取推荐任务卡片宽度
    /// - Parameter screenWidth: 屏幕宽度
    /// - Returns: 卡片宽度
    public static func recommendedTaskCardWidth(screenWidth: CGFloat) -> CGFloat {
        let isPad = DeviceInfo.isPad
        if isPad {
            let currentiPadModel: DeviceInfo.iPadModelType = DeviceInfo.iPadModel
            let columnCount: Int
            
            // 根据iPad型号确定列数（横屏时）
            switch currentiPadModel {
            case .mini:
                columnCount = 2  // iPad Mini: 屏幕较小，2列
            case .pro12_9:
                columnCount = 4  // iPad Pro 12.9英寸: 屏幕最大，4列
            case .pro11, .air:
                columnCount = 3  // iPad Pro 11英寸和iPad Air: 中等屏幕，3列
            case .standard, .unknown:
                columnCount = 3  // 标准iPad: 默认3列
            }
            
            return cardWidth(
                screenWidth: screenWidth,
                columnCount: columnCount,
                horizontalPadding: 32, // AppSpacing.md * 2
                columnSpacing: 16 // AppSpacing.md
            )
        } else {
            // iPhone: 固定200
            return 200
        }
    }
}

/// View扩展 - 自适应布局
extension View {
    /// 根据设备类型获取网格列数
    /// - Parameter itemType: 网格项类型
    /// - Returns: 网格列数
    public func adaptiveGridColumnCount(itemType: AdaptiveLayout.GridItemType = .standard) -> Int {
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        return AdaptiveLayout.gridColumnCount(
            horizontalSizeClass: horizontalSizeClass,
            itemType: itemType
        )
    }
    
    /// 创建自适应网格列
    /// - Parameters:
    ///   - itemType: 网格项类型
    ///   - spacing: 列间距
    /// - Returns: GridItem数组
    public func adaptiveGridColumns(
        itemType: AdaptiveLayout.GridItemType = .standard,
        spacing: CGFloat = 16 // AppSpacing.md
    ) -> [GridItem] {
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        return AdaptiveLayout.adaptiveGridColumns(
            horizontalSizeClass: horizontalSizeClass,
            itemType: itemType,
            spacing: spacing
        )
    }
}
