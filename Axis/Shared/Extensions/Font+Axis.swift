import SwiftUI

extension Font {
    static func axisSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func axisRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let axisTitle = Font.system(size: 28, weight: .bold, design: .serif)
    static let axisHeadline = Font.system(size: 20, weight: .semibold, design: .default)
    static let axisBody = Font.system(size: 16, weight: .regular, design: .default)
    static let axisCaption = Font.system(size: 12, weight: .medium, design: .default)
}

// MARK: - Semantic / Dynamic Type-aware fonts
// Prefer these over ad-hoc .font(.system(size: X)) so Dynamic Type works.
// Each role uses a SwiftUI TextStyle so the OS scales them with the user's
// accessibility font setting. Use the raw `axisTitle` etc. only for hero
// elements where you genuinely want a fixed design size.
extension Font {
    /// Hero display title (serif). Scales with .largeTitle.
    static let axisDisplay = Font.system(.largeTitle, design: .serif).weight(.bold)
    /// Screen title (serif). Scales with .title.
    static let axisScreenTitle = Font.system(.title, design: .serif).weight(.bold)
    /// Section header (default). Scales with .title3.
    static let axisSectionTitle = Font.system(.title3, design: .default).weight(.semibold)
    /// Primary body copy. Scales with .body.
    static let axisBodyDynamic = Font.system(.body, design: .default)
    /// Secondary/supporting text. Scales with .subheadline.
    static let axisSubheadline = Font.system(.subheadline, design: .default)
    /// Metadata, timestamps. Scales with .caption.
    static let axisMeta = Font.system(.caption, design: .default).weight(.medium)
    /// Monospaced numeric — stats, timers, counts. Tabular numerals.
    static let axisNumeric = Font.system(.title2, design: .rounded).weight(.semibold).monospacedDigit()
}
