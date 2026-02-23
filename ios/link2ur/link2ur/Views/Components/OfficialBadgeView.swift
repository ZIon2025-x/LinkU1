import SwiftUI

struct OfficialBadgeView: View {
    let badge: String

    init(badge: String = "官方") {
        self.badge = badge
    }

    var body: some View {
        Text(badge)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.black.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 1.0, green: 0.84, blue: 0.0))
            .cornerRadius(4)
    }
}
