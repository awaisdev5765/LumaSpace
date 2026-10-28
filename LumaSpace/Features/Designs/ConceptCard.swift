import SwiftUI

// MARK: - Concept Card

struct ConceptCard: View {
    let concept: DesignConcept
    var isSelectedForCompare: Bool = false
    let action: () -> Void
    var onLongPress: (() -> Void)?
    var onRate: ((DesignRating) -> Void)?
    var onRedo: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showRating = false

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.light)
            action()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let image = concept.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: concept.style.palette,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.45)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    Text(concept.style.rawValue)
                        .font(LumaFont.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, LumaSpacing.sm)
                        .padding(.bottom, LumaSpacing.sm)

                    if isSelectedForCompare {
                        Color.black.opacity(0.18)
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(LumaSpacing.sm)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 130)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: LumaRadius.lg,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: LumaRadius.lg
                ))

                VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                    HStack {
                        Text(concept.title)
                            .font(LumaFont.caption1)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Spacer()
                        if concept.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    Text("~$\(Int(concept.estimatedCost).formatted())")
                        .font(LumaFont.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 3) {
                        let p = concept.style.palette
                        ForEach(0..<min(p.count, 4), id: \.self) { i in
                            p[i].frame(width: 14, height: 14).clipShape(Circle())
                        }
                        Spacer()

                        if let onRedo {
                            Button {
                                LumaHaptics.impact(.light)
                                onRedo()
                            } label: {
                                Label("Refine", systemImage: "sparkles")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.Luma.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.Luma.accent.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Refine this design")
                            .accessibilityHint("Opens prompt to tell AI what to change")
                        }

                        if let rating = concept.rating {
                            Image(systemName: rating == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                                .font(.caption2)
                                .foregroundStyle(rating == .thumbsUp ? Color.Luma.accent : .secondary)
                        }
                    }

                    if showRating {
                        HStack(spacing: LumaSpacing.sm) {
                            Button {
                                onRate?(.thumbsUp)
                                showRating = false
                                LumaHaptics.impact(.light)
                            } label: {
                                Label("Like", systemImage: "hand.thumbsup")
                                    .font(.caption2)
                                    .foregroundStyle(Color.Luma.accent)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onRate?(.thumbsDown)
                                showRating = false
                                LumaHaptics.impact(.light)
                            } label: {
                                Label("Dislike", systemImage: "hand.thumbsdown")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(LumaSpacing.sm)
                .animation(reduceMotion ? .none : .lumaFast, value: showRating)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                    .strokeBorder(
                        isSelectedForCompare ? Color.Luma.accent : Color.clear,
                        lineWidth: 2
                    )
            }
            .lumaShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(concept.style.rawValue) design, estimated cost \(Int(concept.estimatedCost)) dollars")
        .accessibilityAction(named: "Compare with another design") { onLongPress?() }
        .contextMenu {
            Button("Rate: Like", systemImage: "hand.thumbsup") { onRate?(.thumbsUp) }
            Button("Rate: Dislike", systemImage: "hand.thumbsdown") { onRate?(.thumbsDown) }
            Divider()
            Button("Redo with Changes…", systemImage: "arrow.clockwise.circle") { onRedo?() }
            Divider()
            Button("Compare with Another", systemImage: "arrow.left.arrow.right") { onLongPress?() }
        }
        .onLongPressGesture {
            LumaHaptics.impact(.medium)
            withAnimation(reduceMotion ? .none : .lumaSpring) { showRating.toggle() }
            onLongPress?()
        }
    }
}

// MARK: - Skeleton Grid (loading state)

struct SkeletonConceptGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: LumaSpacing.md
        ) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 0) {
                    SkeletonView()
                        .frame(height: 140)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: LumaRadius.lg,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: LumaRadius.lg
                        ))
                    VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                        SkeletonView()
                            .frame(width: 100, height: 12)
                            .clipShape(Capsule())
                        SkeletonView()
                            .frame(width: 60, height: 10)
                            .clipShape(Capsule())
                    }
                    .padding(LumaSpacing.sm)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            }
        }
    }
}
