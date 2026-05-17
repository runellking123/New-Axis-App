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

// MARK: - Things 3 / Mobbin palette
// New token system for redesigned surfaces. Keep axisGold/axisAccent intact
// so legacy screens don't break; gradually migrate features to these.
extension Color {
    /// Cobalt blue — the new primary action color across redesigned screens.
    /// Use for: floating + buttons, primary CTAs, in-progress accents, links.
    static let axisCobalt = Color(red: 26.0/255, green: 107.0/255, blue: 251.0/255)
    static let axisCobaltSoft = Color(red: 26.0/255, green: 107.0/255, blue: 251.0/255).opacity(0.10)
    static let axisCobaltTint = Color(red: 234.0/255, green: 241.0/255, blue: 255.0/255)

    /// Paper / cream surfaces for redesigned screens.
    static let axisCream = Color(red: 247.0/255, green: 247.0/255, blue: 242.0/255)
    static let axisPaper = Color.white

    /// Ink — the four-tone text scale that mirrors iOS opacity ramp but with
    /// warmer ink than Apple's pure greys.
    static let axisInk = Color(red: 26.0/255, green: 26.0/255, blue: 31.0/255)
    static let axisInkSoft = Color(red: 74.0/255, green: 74.0/255, blue: 82.0/255)
    static let axisInkMute = Color(red: 138.0/255, green: 138.0/255, blue: 146.0/255)
    static let axisInkFaint = Color(red: 192.0/255, green: 192.0/255, blue: 199.0/255)

    /// Hairline separators (1px-ish, sub-pixel-friendly).
    static let axisHairline = Color.black.opacity(0.06)
    static let axisHairlineStrong = Color.black.opacity(0.10)

    /// Semantic project / area colors used on pills, icon-cells, and accents.
    /// Each color has a `.softX` companion for low-emphasis tinted backgrounds.
    static let axisYellowTone = Color(red: 245.0/255, green: 189.0/255, blue: 46.0/255)
    static let axisYellowSoft = Color(red: 245.0/255, green: 189.0/255, blue: 46.0/255).opacity(0.14)
    static let axisRedTone = Color(red: 231.0/255, green: 76.0/255, blue: 60.0/255)
    static let axisRedSoft = Color(red: 231.0/255, green: 76.0/255, blue: 60.0/255).opacity(0.10)
    static let axisGreenTone = Color(red: 52.0/255, green: 199.0/255, blue: 89.0/255)
    static let axisGreenSoft = Color(red: 52.0/255, green: 199.0/255, blue: 89.0/255).opacity(0.14)
    static let axisPurpleTone = Color(red: 139.0/255, green: 92.0/255, blue: 246.0/255)
    static let axisPurpleSoft = Color(red: 139.0/255, green: 92.0/255, blue: 246.0/255).opacity(0.14)
    static let axisOrangeTone = Color(red: 255.0/255, green: 140.0/255, blue: 66.0/255)
    static let axisOrangeSoft = Color(red: 255.0/255, green: 140.0/255, blue: 66.0/255).opacity(0.14)
    static let axisTealTone = Color(red: 20.0/255, green: 184.0/255, blue: 166.0/255)
    static let axisTealSoft = Color(red: 20.0/255, green: 184.0/255, blue: 166.0/255).opacity(0.14)
    static let axisPinkTone = Color(red: 236.0/255, green: 72.0/255, blue: 153.0/255)
    static let axisPinkSoft = Color(red: 236.0/255, green: 72.0/255, blue: 153.0/255).opacity(0.14)
}
