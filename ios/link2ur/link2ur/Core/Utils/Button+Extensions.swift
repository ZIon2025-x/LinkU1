import SwiftUI

/// Button 扩展 - 企业级按钮工具
/// 注意：ButtonStyle 定义已在 DesignSystem.swift 中，这里只提供便捷方法
extension Button where Label == Text {
    
    /// 创建主要按钮
    public static func primary(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
    }
    
    /// 创建次要按钮
    public static func secondary(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
    }
    
    /// 创建危险按钮
    public static func danger(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(10)
    }
}

