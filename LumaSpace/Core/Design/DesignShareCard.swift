import SwiftUI

// MARK: - Design Share Card
// Renders a 9:16 branded card suitable for Instagram Stories, TikTok, and
// any full-bleed share format. Use ImageRenderer to convert to UIImage.

struct DesignShareCard: View {
    let concept: DesignConcept
    /// Pass the room's before photo if available — shows a mini before/after strip.
    var beforePhoto: UIImage?

    private var palette: [Color] { concept.style.palette }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Background gradient from palette
            LinearGradient(
                colors: palette.prefix(3).map { $0 },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // ── AI design image (if available)
            if let data = concept.imageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(0.55)
            }

            // ── Bottom scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            // ── Content overlay
            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                // Before / after strip (only if both images exist)
                if let beforePhoto,
                   let afterData = concept.imageData,
                   let afterImg = UIImage(data: afterData) {
                    beforeAfterStrip(before: beforePhoto, after: afterImg)
                        .padding(.bottom, 4)
                }

                // Style badge
                HStack(spacing: 6) {
                    Text(concept.style.emoji)
                        .font(.system(size: 20))
                    Text(concept.style.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Title
                Text(concept.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                // Description
                Text(concept.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Cost + palette chips row
                HStack(spacing: 12) {
                    Text("Est. $\(Int(concept.estimatedCost).formatted())")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 5) {
                        ForEach(palette.prefix(4).indices, id: \.self) { i in
                            Circle()
                                .fill(palette[i])
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                }

                Divider().background(.white.opacity(0.2))

                // Branding footer
                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("LumaSpace")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("lumaspace.app")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(width: 390, height: 693)   // 9:16 at common screen density
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    @ViewBuilder
    private func beforeAfterStrip(before: UIImage, after: UIImage) -> some View {
        HStack(spacing: 3) {
            VStack(spacing: 3) {
                Image(uiImage: before)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("BEFORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
            }
            VStack(spacing: 3) {
                Image(uiImage: after)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("AFTER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
            }
        }
    }
}

// MARK: - Share Card Renderer

@MainActor
enum DesignShareCardRenderer {
    static func render(concept: DesignConcept, beforePhoto: UIImage? = nil) -> UIImage? {
        let card = DesignShareCard(concept: concept, beforePhoto: beforePhoto)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0   // @2x for crisp output
        return renderer.uiImage
    }
}
