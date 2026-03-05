import SwiftUI

enum AxisTheme {
    // MARK: - Colors
    static let gold = Color("AxisGold")
    static let dark = Color("AxisDark")
    #if canImport(UIKit)
    static let cardBackground = Color(uiColor: UIColor.secondarySystemGroupedBackground)
    #else
    static let cardBackground = Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97)
    #endif

    // MARK: - Gradients
    static let goldGradient = LinearGradient(
        colors: [Color(red: 0.808, green: 0.694, blue: 0.337),
                 Color(red: 0.878, green: 0.750, blue: 0.400)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let darkGradient = LinearGradient(
        colors: [Color(red: 0.075, green: 0.09, blue: 0.11),
                 Color(red: 0.12, green: 0.14, blue: 0.16)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Shadows
    static let cardShadow = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 8

    // MARK: - Corner Radius
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 12
    static let chipRadius: CGFloat = 8

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
}
