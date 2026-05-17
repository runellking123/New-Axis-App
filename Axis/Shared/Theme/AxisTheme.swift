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

// MARK: - Things-style hero header
// A circular colored icon-cell + 28pt bold title + small subtitle. Used as
// the top-of-screen header on redesigned tabs (Today / Upcoming / Inbox etc.)
// in place of bare navigationTitle("…").
struct ThingsIconCell: View {
    let systemImage: String
    var color: Color = .axisCobalt
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct ThingsHeroHeader: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var color: Color = .axisCobalt

    var body: some View {
        HStack(alignment: .top, spacing: AxisSpacing.md) {
            ThingsIconCell(systemImage: icon, color: color)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.axisInk)
                    .tracking(-0.4)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.axisInkMute)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AxisSpacing.lg)
        .padding(.vertical, AxisSpacing.sm)
    }
}

// MARK: - Things-style flat row card
// Paper background, hairline border, optional subtle shadow. Replaces
// `.ultraThinMaterial`-style elevated cards on Things-treated screens.
struct ThingsCardModifier: ViewModifier {
    var padding: CGFloat = AxisSpacing.md
    var radius: CGFloat = 14
    var elevated: Bool = true
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.axisPaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.axisHairline, lineWidth: 0.5)
            )
            .shadow(color: elevated ? Color.black.opacity(0.04) : .clear,
                    radius: elevated ? 4 : 0, y: elevated ? 1 : 0)
    }
}

extension View {
    /// Things-style paper card with hairline border. Use on cream backgrounds.
    func thingsCard(padding: CGFloat = AxisSpacing.md,
                    radius: CGFloat = 14,
                    elevated: Bool = true) -> some View {
        modifier(ThingsCardModifier(padding: padding, radius: radius, elevated: elevated))
    }
}

// MARK: - Magic Plus floating action button
// Cobalt-blue floating + button — Things 3 signature. Sits in the bottom-right
// of any redesigned screen. Tap fires `action`. Long-press on a real device
// would let you drag-and-drop where the new item lands (not implemented here).
struct MagicPlusButton: View {
    var color: Color = .axisCobalt
    var systemImage: String = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .shadow(color: color.opacity(0.32), radius: 8, y: 4)
                    .shadow(color: color.opacity(0.20), radius: 22, y: 12)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(MagicPlusPressStyle())
        .accessibilityLabel("Add")
    }
}

private struct MagicPlusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Time-of-day sky gradient
// Subtle background gradient behind hero headers that shifts through the day.
// Dawn (peach) → Day (soft blue) → Dusk (lavender) → Night (deep indigo → cream).
enum TimeOfDay {
    case dawn, day, dusk, night

    static func current(at date: Date = Date()) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<10: return .dawn
        case 10..<17: return .day
        case 17..<21: return .dusk
        default: return .night
        }
    }

    /// The greeting word for this time of day.
    var greeting: String {
        switch self {
        case .dawn: return "Good morning"
        case .day:  return "Hey"
        case .dusk: return "Good evening"
        case .night: return "Wind down"
        }
    }

    var icon: String {
        switch self {
        case .dawn: return "sun.horizon.fill"
        case .day:  return "sun.max.fill"
        case .dusk: return "moon.haze.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .dawn: return .axisOrangeTone
        case .day:  return .axisCobalt
        case .dusk: return .axisPurpleTone
        case .night: return Color(red: 0.35, green: 0.42, blue: 1.0)
        }
    }

    /// Linear gradient for the background behind the greeting / hero header.
    /// Fades to paper at the bottom so content below sits on a clean surface.
    var skyGradient: LinearGradient {
        switch self {
        case .dawn:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.89, blue: 0.84),
                    Color(red: 1.0, green: 0.96, blue: 0.91),
                    Color.axisPaper
                ],
                startPoint: .top, endPoint: .bottom)
        case .day:
            return LinearGradient(
                colors: [
                    Color(red: 0.87, green: 0.93, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color.axisPaper
                ],
                startPoint: .top, endPoint: .bottom)
        case .dusk:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.83, blue: 0.69),
                    Color(red: 0.95, green: 0.88, blue: 1.0),
                    Color.axisPaper
                ],
                startPoint: .top, endPoint: .bottom)
        case .night:
            return LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.30, green: 0.27, blue: 0.47),
                    Color.axisPaper
                ],
                startPoint: .top, endPoint: .bottom)
        }
    }

    /// True when the gradient is dark enough that overlaid text should be white.
    var prefersLightForeground: Bool {
        self == .night
    }
}
