import SwiftUI

// MARK: - Fallback palette
// Deterministic gradient from a string seed so a given source/place always
// gets the same tile color, even when no image is available.

enum AxisImagePalette {
    private static let palettes: [[Color]] = [
        [Color(red: 0.36, green: 0.42, blue: 0.75), Color(red: 0.45, green: 0.30, blue: 0.62)],
        [Color(red: 0.16, green: 0.49, blue: 0.52), Color(red: 0.10, green: 0.34, blue: 0.42)],
        [Color(red: 0.74, green: 0.42, blue: 0.24), Color(red: 0.58, green: 0.24, blue: 0.27)],
        [Color(red: 0.20, green: 0.34, blue: 0.51), Color(red: 0.14, green: 0.21, blue: 0.36)],
        [Color(red: 0.42, green: 0.49, blue: 0.24), Color(red: 0.24, green: 0.35, blue: 0.27)],
        [Color(red: 0.55, green: 0.31, blue: 0.51), Color(red: 0.33, green: 0.20, blue: 0.42)],
        [Color(red: 0.21, green: 0.45, blue: 0.44), Color(red: 0.13, green: 0.28, blue: 0.34)],
    ]

    static func gradient(for seed: String) -> LinearGradient {
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let colors = palettes[sum % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Fallback tile
// Shown when there is no image URL or the image fails to load.

struct AxisFallbackTile: View {
    let seed: String
    var icon: String = "photo"

    var body: some View {
        ZStack {
            AxisImagePalette.gradient(for: seed)
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Remote image
// AsyncImage wrapper with a shimmering skeleton while loading and a graceful
// fallback on missing/failed URLs. Crossfades in on success.

struct AxisRemoteImage<Fallback: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .shimmer()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    fallback()
                @unknown default:
                    fallback()
                }
            }
        } else {
            fallback()
        }
    }
}

extension AxisRemoteImage where Fallback == AxisFallbackTile {
    init(url: URL?, contentMode: ContentMode = .fill, seed: String, icon: String = "photo") {
        self.init(url: url, contentMode: contentMode) {
            AxisFallbackTile(seed: seed, icon: icon)
        }
    }
}

// MARK: - Cover card
// Large hero card with a full-bleed cover image, a dark scrim, and overlaid
// eyebrow / title / meta text. The "featured story" treatment.

struct AxisCoverCard: View {
    let imageURL: URL?
    var eyebrow: String? = nil
    let title: String
    var meta: String? = nil
    var seed: String = ""
    var icon: String = "photo"
    var height: CGFloat = 210

    private var resolvedSeed: String { seed.isEmpty ? title : seed }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AxisRemoteImage(url: imageURL, seed: resolvedSeed, icon: icon)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.axisGoldLight)
                }
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                if let meta {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(AxisSpacing.lg)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
        .shadow(color: AxisTheme.cardShadow, radius: AxisTheme.cardShadowRadius, y: 3)
    }
}

// MARK: - Thumbnail card
// Horizontal row with a leading square thumbnail. The standard list cell for
// image-bearing content (news, places, contacts).

struct AxisThumbnailCard: View {
    let imageURL: URL?
    var eyebrow: String? = nil
    let title: String
    var meta: String? = nil
    var seed: String = ""
    var icon: String = "photo"
    var thumbnailSize: CGFloat = 84

    private var resolvedSeed: String { seed.isEmpty ? title : seed }

    var body: some View {
        HStack(spacing: AxisSpacing.md) {
            AxisRemoteImage(url: imageURL, seed: resolvedSeed, icon: icon)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: AxisRadius.button, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.axisAccent)
                        .lineLimit(1)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                if let meta {
                    Text(meta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AxisSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AxisRadius.card, style: .continuous))
        .shadow(color: AxisTheme.cardShadow, radius: 4, y: 1)
    }
}

#Preview("Cover") {
    AxisCoverCard(
        imageURL: nil,
        eyebrow: "Inside Higher Ed",
        title: "What the new federal data rules mean for enrollment reporting",
        meta: "2h ago · 6 min read",
        seed: "Inside Higher Ed",
        icon: "newspaper.fill"
    )
    .padding()
}

#Preview("Thumbnail") {
    AxisThumbnailCard(
        imageURL: nil,
        eyebrow: "TechCrunch",
        title: "A practical look at on-device models for everyday apps",
        meta: "4h ago · 5 min read",
        seed: "TechCrunch",
        icon: "newspaper.fill"
    )
    .padding()
}
