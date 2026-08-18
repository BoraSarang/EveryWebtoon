import SwiftUI

struct PlatformBadge: View {
    let platform: Platform

    var body: some View {
        Text(platform == .naver ? "N" : "K")
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(platform == .naver ? .white : .black)
            .frame(width: 20, height: 16)
            .background(badgeColor)
            .cornerRadius(4)
            .shadow(radius: 1)
    }

    private var badgeColor: Color {
        switch platform {
        case .naver: return Color(.displayP3, red: 0.11, green: 0.78, blue: 0)
        case .kakao: return Color(.displayP3, red: 0.98, green: 0.88, blue: 0)
        }
    }
}
