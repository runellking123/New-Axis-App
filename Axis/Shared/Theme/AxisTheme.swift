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

// MARK: - Design System Tokens
// Semantic spacing scale — use these instead of magic numbers so the app
// breathes consistently. 4pt grid. Multiples of 4 keep things aligned.
enum AxisSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// Corner radius tokens.
enum AxisRadius {
    static let chip: CGFloat = 8
    static let button: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - Button Styles
// Use `.buttonStyle(.axisPrimary)` for the ONE main action on a screen.
// Use `.axisSecondary` for supporting actions. Use `.axisGhost` for tertiary.
// Reserving gold for primary only prevents the "everything is gold" visual fatigue.
struct AxisPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.black)
            .padding(.vertical, AxisSpacing.md)
            .padding(.horizontal, AxisSpacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                    .fill(AxisTheme.goldGradient)
            )
            .shadow(color: AxisTheme.cardShadow, radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 3)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AxisSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.axisGold)
            .padding(.vertical, AxisSpacing.md)
            .padding(.horizontal, AxisSpacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                    .fill(Color.axisGold.opacity(configuration.isPressed ? 0.2 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous)
                    .strokeBorder(Color.axisGold.opacity(0.4), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct AxisGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, AxisSpacing.sm)
            .padding(.horizontal, AxisSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AxisRadius.chip, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.0))
            )
    }
}

extension ButtonStyle where Self == AxisPrimaryButtonStyle {
    static var axisPrimary: AxisPrimaryButtonStyle { AxisPrimaryButtonStyle() }
    static func axisPrimary(fullWidth: Bool) -> AxisPrimaryButtonStyle { AxisPrimaryButtonStyle(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == AxisSecondaryButtonStyle {
    static var axisSecondary: AxisSecondaryButtonStyle { AxisSecondaryButtonStyle() }
    static func axisSecondary(fullWidth: Bool) -> AxisSecondaryButtonStyle { AxisSecondaryButtonStyle(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == AxisGhostButtonStyle {
    static var axisGhost: AxisGhostButtonStyle { AxisGhostButtonStyle() }
}

// MARK: - Card Modifier
// Standard elevated card surface. Use instead of hand-rolling
// .background(.ultraThinMaterial) + clip + shadow across dozens of files.
struct AxisCardModifier: ViewModifier {
    var padding: CGFloat = AxisSpacing.lg
    var material: Material = .ultraThinMaterial
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
            .shadow(color: AxisTheme.cardShadow, radius: AxisTheme.cardShadowRadius, y: 2)
    }
}

struct AxisAccentCardModifier: ViewModifier {
    var padding: CGFloat = AxisSpacing.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                    .fill(Color.axisGold.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous)
                    .strokeBorder(Color.axisGold.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    /// Neutral elevated card. Use for most content blocks.
    func axisCard(padding: CGFloat = AxisSpacing.lg) -> some View {
        modifier(AxisCardModifier(padding: padding))
    }

    /// Highlighted card — reserve for the ONE most actionable item on a screen.
    func axisAccentCard(padding: CGFloat = AxisSpacing.lg) -> some View {
        modifier(AxisAccentCardModifier(padding: padding))
    }
}

// MARK: - Section Header
// Consistent section headers across the app. Replaces ad-hoc
// `Text("Title").font(.headline).padding(.horizontal)` patterns.
struct AxisSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<T: View>(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: AxisSpacing.sm)
            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, AxisSpacing.lg)
        .padding(.vertical, AxisSpacing.sm)
    }
}

// MARK: - Empty State
// Use on any list/screen that might be empty. Consistent shape across
// QuickNotes, Budget, Trends, Clipboard, Balance, etc.
struct AxisEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AxisSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            VStack(spacing: AxisSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.axisSecondary(fullWidth: false))
            }
        }
        .padding(AxisSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
