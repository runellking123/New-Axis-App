import SwiftUI

// MARK: - Hero Header
// Rich banner for the top of a screen: gradient (or image) background with an
// eyebrow / title / subtitle stack and an optional trailing accessory slot.
// Static — pairs well with AxisStretchyHeader for scroll-collapsing screens.

struct AxisHeroHeader<Trailing: View>: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var gradient: LinearGradient = AxisTheme.darkGradient
    var imageURL: URL? = nil
    var height: CGFloat? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: AxisSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.axisGoldLight)
                }
                Text(title)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(AxisSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background {
            ZStack {
                gradient
                if let imageURL {
                    AxisRemoteImage(url: imageURL) { Color.clear }
                    Color.black.opacity(0.4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
        .shadow(color: AxisTheme.cardShadow, radius: 10, y: 4)
    }
}

extension AxisHeroHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil,
         gradient: LinearGradient = AxisTheme.darkGradient, imageURL: URL? = nil,
         height: CGFloat? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, gradient: gradient,
                  imageURL: imageURL, height: height) { EmptyView() }
    }
}

// MARK: - Stretchy Header
// Scroll-aware header that stretches on pull-down and parallax-scrolls away.
// Place it as the first element inside a ScrollView, and add
// `.coordinateSpace(name: AxisStretchyHeader.coordinateSpace)` to that ScrollView.

struct AxisStretchyHeader<Content: View>: View {
    static var coordinateSpace: String { "axisStretchyScroll" }

    var height: CGFloat = 240
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(Self.coordinateSpace)).minY
            let stretch = max(0, minY)
            content()
                .frame(width: geo.size.width, height: height + stretch)
                .offset(y: -stretch)
        }
        .frame(height: height)
    }
}

#Preview("Hero — gradient") {
    AxisHeroHeader(
        eyebrow: "Good morning",
        title: "Runell",
        subtitle: "5 day streak · 3 meetings today"
    ) {
        AxisRingChart(progress: 0.7, lineWidth: 6, tint: .green) {
            Text("7")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
    }
    .padding()
}
