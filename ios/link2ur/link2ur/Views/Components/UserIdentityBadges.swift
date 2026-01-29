import SwiftUI

/// 用户身份标识组件 - 显示VIP、super、达人、学生等标识
struct UserIdentityBadges: View {
    let userLevel: String?
    let isExpert: Bool?
    let isStudentVerified: Bool?
    
    var body: some View {
        HStack(spacing: 6) {
            // VIP标识
            if let level = userLevel, level == "vip" {
                IdentityBadge(
                    text: "VIP",
                    icon: "crown.fill",
                    gradient: [Color.yellow, Color.orange],
                    textColor: .white
                )
            }
            
            // Super标识
            if let level = userLevel, level == "super" {
                IdentityBadge(
                    text: "Super",
                    icon: "flame.fill",
                    gradient: [Color.purple, Color.pink],
                    textColor: .white
                )
            }
            
            // 达人标识
            if isExpert == true {
                IdentityBadge(
                    text: "达人",
                    icon: "star.fill",
                    gradient: [Color.blue, Color.cyan],
                    textColor: .white
                )
            }
            
            // 学生标识
            if isStudentVerified == true {
                IdentityBadge(
                    text: "学生",
                    icon: "graduationcap.fill",
                    gradient: [Color.indigo, Color.blue],
                    textColor: .white
                )
            }
        }
    }
}

/// 单个身份标识徽章
struct IdentityBadge: View {
    let text: String
    let icon: String
    let gradient: [Color]
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradient),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: gradient.first?.opacity(0.3) ?? Color.clear, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        UserIdentityBadges(
            userLevel: "vip",
            isExpert: true,
            isStudentVerified: true
        )
        
        UserIdentityBadges(
            userLevel: "super",
            isExpert: false,
            isStudentVerified: false
        )
        
        UserIdentityBadges(
            userLevel: nil,
            isExpert: true,
            isStudentVerified: true
        )
    }
    .padding()
}
