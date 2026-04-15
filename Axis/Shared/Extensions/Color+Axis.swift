import SwiftUI

// Note: Color.axisGold and Color.axisDark are auto-generated from Assets.xcassets
// by Xcode's GeneratedAssetSymbols. No need to declare them manually.

extension Color {
    static let axisGoldLight = Color(red: 0.878, green: 0.750, blue: 0.400)
    static let axisGoldDark = Color(red: 0.808, green: 0.694, blue: 0.337)
}

// MARK: - Semantic Color Roles
// Use these role-based names instead of `axisGold` directly so a single screen
// does not over-index on one color. Rule of thumb: one `.axisAccent` per screen,
// max two. Everything else stays on surface/primary/secondary.
extension Color {
    /// The ONE primary accent on a screen — reserve for the single most important
    /// call to action, status indicator, or the actively-selected item.
    static var axisAccent: Color { .axisGold }

    /// Use for success states / positive confirmation.
    static var axisSuccess: Color { Color.green }

    /// Use for warning / attention needed (but not error).
    static var axisWarning: Color { Color.orange }

    /// Use for errors / destructive actions.
    static var axisDanger: Color { Color.red }

    /// Informational state (neutral info, links).
    static var axisInfo: Color { Color.blue }

    /// Elevated surface (cards). Platform-aware.
    #if canImport(UIKit)
    static var axisSurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var axisBackground: Color { Color(uiColor: .systemGroupedBackground) }
    #else
    static var axisSurface: Color { Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97) }
    static var axisBackground: Color { Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98) }
    #endif

    /// Subtle divider color.
    static var axisDivider: Color { Color.primary.opacity(0.08) }
}
