//
//  Constants.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation
import SwiftUI

struct AppConstants {
    // API配置
    static let apiBaseURL = "https://api.link2ur.com"
    static let wsBaseURL = "wss://api.link2ur.com"
    
    // 应用配置
    static let appName = "Link²Ur"
    static let appVersion = "1.0.0"
    
    // 分页配置
    static let defaultPageSize = 20
    static let maxPageSize = 100
    
    // 图片配置
    static let maxImageSize: Int64 = 5 * 1024 * 1024 // 5MB
    static let maxImagesPerTask = 5
    
    // 网络配置
    static let requestTimeout: TimeInterval = 30
    static let maxRetryAttempts = 3
}

struct AppColors {
    static let primary = Color(hex: "#1890ff")
    static let secondary = Color(hex: "#52c41a")
    static let success = Color(hex: "#52c41a")
    static let warning = Color(hex: "#faad14")
    static let error = Color(hex: "#f5222d")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

