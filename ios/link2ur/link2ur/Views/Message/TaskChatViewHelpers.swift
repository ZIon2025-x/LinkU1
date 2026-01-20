import SwiftUI

// MARK: - Height Measurement Modifier

/// 测量视图高度的 PreferenceKey
private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 扩展：让视图能够自动测量并报告高度
extension View {
    /// 读取视图高度并绑定到指定的 Binding
    /// 用于动态测量输入区高度（包含 action menu 展开/收起）
    func readHeight(into binding: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeightPreferenceKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            let old = binding.wrappedValue
            // ✅ 修复：加一个阈值避免微小波动
            guard abs(old - height) > 0.5 else { return }
            
            // ✅ 修复：强制禁用这次状态更新的动画，避免高度测量带来隐式动画抖动
            var tx = Transaction()
            tx.animation = nil
            withTransaction(tx) {
                binding.wrappedValue = height
            }
        }
    }
}
