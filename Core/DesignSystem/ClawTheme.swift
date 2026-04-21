import SwiftUI

enum ClawPalette {
    static let background = Color(red: 0.06, green: 0.08, blue: 0.11)
    static let panel = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let elevated = Color(red: 0.13, green: 0.15, blue: 0.20)
    static let stroke = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.62)
    static let accent = Color(red: 0.29, green: 0.64, blue: 1.0)
    static let accentSoft = Color(red: 0.29, green: 0.64, blue: 1.0).opacity(0.14)
    static let success = Color(red: 0.30, green: 0.82, blue: 0.55)
    static let warning = Color(red: 0.98, green: 0.73, blue: 0.26)
    static let danger = Color(red: 1.0, green: 0.40, blue: 0.40)
}

enum ClawSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

enum ClawRadius {
    static let card: CGFloat = 22
    static let bubble: CGFloat = 18
    static let pill: CGFloat = 12
}

struct ClawCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.55))
            .background(ClawPalette.panel.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: ClawRadius.card, style: .continuous)
                    .stroke(ClawPalette.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ClawRadius.card, style: .continuous))
    }
}

extension View {
    func clawCard() -> some View {
        modifier(ClawCardModifier())
    }
}
