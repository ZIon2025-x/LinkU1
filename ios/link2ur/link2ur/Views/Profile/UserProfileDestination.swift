import SwiftUI

/// 根据用户信息决定跳转目标：官方账号跳转到关于我们页面，普通用户跳转到用户资料页面
@ViewBuilder
func userProfileDestination(userId: String, isAdmin: Bool? = nil) -> some View {
    if isAdmin == true {
        AboutView()
    } else {
        UserProfileView(userId: userId)
    }
}

/// 根据 User 对象决定跳转目标
@ViewBuilder
func userProfileDestination(user: User) -> some View {
    userProfileDestination(userId: user.id, isAdmin: user.isAdmin)
}
