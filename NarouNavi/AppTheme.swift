import SwiftUI

enum AppTheme {
    static let ink = Color(hex: "080A14")
    static let navy = Color(hex: "10162A")
    static let panel = Color(hex: "171E35")
    static let panelSoft = Color(hex: "202942")
    static let gold = Color(hex: "F1C76A")
    static let cyan = Color(hex: "65D7FF")
    static let violet = Color(hex: "9B7CFF")
    static let rose = Color(hex: "FF7AA8")
    static let text = Color(hex: "F7F3E8")
    static let subtext = Color(hex: "A9B0C7")
    static let border = Color.white.opacity(0.10)

    static let background = LinearGradient(
        colors: [ink, Color(hex: "101223"), Color(hex: "071321")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct HeroImageCard: View {
    let imageName: String
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .clipped()

            LinearGradient(colors: [.clear, AppTheme.ink.opacity(0.9)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(badge)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold, in: Capsule())

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.subtext)
                    .lineLimit(2)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.cyan)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .foregroundColor(AppTheme.text)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(13)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}
