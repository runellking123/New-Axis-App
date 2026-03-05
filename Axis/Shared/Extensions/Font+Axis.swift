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
