import SwiftUI

// MARK: - Primary Button
// Solid fill — no gradient. Apple's own apps (Maps, Files, Reminders) use flat fills.

struct LumaPrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let hint: String?
    let action: () -> Void

    @Environment(\.lumaAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, hint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.hint = hint
        self.action = action
    }

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(LumaFont.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(accent.opacity(isEnabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

// MARK: - Secondary Button

struct LumaSecondaryButton: View {
    let title: String
    let icon: String?
    let hint: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, hint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.hint = hint
        self.action = action
    }

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.light)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.body) }
                Text(title).font(LumaFont.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(LumaSecondaryButtonStyle())
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

private struct LumaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.lumaAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(accent)
            .background(accent.opacity(configuration.isPressed ? 0.18 : 0.10))
            .overlay {
                RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                    .strokeBorder(accent.opacity(configuration.isPressed ? 0.45 : 0.25), lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.lumaFast, value: configuration.isPressed)
    }
}

// MARK: - Icon Button
// Clean circular button — uses .ultraThinMaterial instead of custom glass.

struct LumaIconButton: View {
    let icon: String
    let label: String
    var size: CGFloat
    let action: () -> Void

    init(icon: String, label: String, size: CGFloat = 44, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            LumaHaptics.impact(.light)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Tag Chip

struct LumaChip: View {
    let text: String
    var isSelected: Bool = false
    var action: (() -> Void)?

    @Environment(\.lumaAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let action {
                Button(action: {
                    LumaHaptics.selection()
                    action()
                }) { chipContent }
                    .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        Text(text)
            .font(LumaFont.caption1)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
            .clipShape(Capsule())
            .animation(reduceMotion ? .none : .lumaFast, value: isSelected)
    }
}

// MARK: - Section Header

struct LumaSectionHeader: View {
    let title: String
    var subtitle: String?
    var action: (() -> Void)?
    var actionLabel: String = "See All"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LumaFont.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let action {
                Button(actionLabel, action: action)
                    .font(LumaFont.subhead)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("\(actionLabel) \(title)")
                    .accessibilityHint("Shows all \(title.lowercased())")
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Premium Badge

struct PremiumBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            if !compact {
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundStyle(Color.Luma.goldFallback)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(Color.Luma.goldFallback.opacity(0.12))
        .overlay {
            Capsule().strokeBorder(Color.Luma.goldFallback.opacity(0.3), lineWidth: 0.5)
        }
        .clipShape(Capsule())
    }
}

// MARK: - Skeleton Loader (shimmer)

struct SkeletonView: View {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(reduceMotion ? AnyShapeStyle(Color(uiColor: .systemFill)) : AnyShapeStyle(shimmerGradient))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(uiColor: .systemFill),          location: phase - 0.3),
                .init(color: Color(uiColor: .tertiarySystemFill),   location: phase),
                .init(color: Color(uiColor: .systemFill),          location: phase + 0.3),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Skeleton Row

struct SkeletonRow: View {
    var iconSize: CGFloat = 44

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            SkeletonView()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                SkeletonView().frame(maxWidth: 200).frame(height: 13).clipShape(Capsule())
                SkeletonView().frame(maxWidth: 130).frame(height: 11).clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.vertical, LumaSpacing.xs)
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var height: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonView()
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.65)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: LumaRadius.lg,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: LumaRadius.lg
                ))
            VStack(alignment: .leading, spacing: LumaSpacing.xs) {
                SkeletonView().frame(maxWidth: 140).frame(height: 12).clipShape(Capsule())
                SkeletonView().frame(maxWidth: 90).frame(height: 10).clipShape(Capsule())
            }
            .padding(LumaSpacing.sm)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}

// MARK: - Progress Ring

struct LumaProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var color: Color = Color.Luma.accent
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: displayedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .lumaSpring, value: displayedProgress)
        }
        .frame(width: size, height: size)
        .accessibilityValue("\(Int(displayedProgress * 100)) percent")
        .onAppear {
            withAnimation(reduceMotion ? .none : .lumaSpring.delay(0.1)) { displayedProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(reduceMotion ? .none : .lumaSpring) { displayedProgress = newValue }
        }
    }
}

// MARK: - Empty State

struct LumaEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    @Environment(\.lumaAccent) private var accent

    var body: some View {
        VStack(spacing: LumaSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(accent.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: LumaSpacing.xs) {
                Text(title).font(LumaFont.headline)
                Text(message)
                    .font(LumaFont.subhead)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionLabel, let action {
                LumaPrimaryButton(actionLabel, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(LumaSpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Room Score Ring

struct RoomScoreView: View {
    let score: Int
    var size: CGFloat = 80

    private var color: Color {
        switch score {
        case 80...: return .green
        case 60..<80: return Color.Luma.goldFallback
        default: return .orange
        }
    }

    var body: some View {
        ZStack {
            LumaProgressRing(
                progress: Double(score) / 100,
                lineWidth: size * 0.10,
                color: color,
                size: size
            )
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                Text("/ 100")
                    .font(.system(size: size * 0.14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Room score \(score) out of 100")
    }
}

// MARK: - List Row Button Style
// Replaces .plain on tappable list rows — shows a system-style press highlight
// so every tap has tactile visual feedback without fighting custom appearance.

struct LumaListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : Color.clear)
            .contentShape(Rectangle())
            .animation(.lumaFast, value: configuration.isPressed)
    }
}

// MARK: - Card Style
// No explicit shadow inside a List — the system handles elevation automatically.

struct LumaCard: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }
}

extension View {
    func lumaCard(padding: CGFloat = LumaSpacing.base) -> some View {
        modifier(LumaCard(padding: padding))
    }
}

// MARK: - Product Image View
// AsyncImage with shimmer loading and category-icon fallback.
// Works for both FurnitureItem (thumbnailURL) and CatalogProduct (imageURL).

struct ProductImageView: View {
    let url: URL?
    let category: FurnitureItem.Category
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ShimmerPlaceholder(category: category)
                            .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.8))
                                    .scaleEffect(0.8)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        CategoryPlaceholder(category: category)
                    @unknown default:
                        CategoryPlaceholder(category: category)
                    }
                }
            } else {
                CategoryPlaceholder(category: category)
            }
        }
        .clipped()
    }
}

private struct CategoryPlaceholder: View {
    let category: FurnitureItem.Category

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                category.placeholderColor.opacity(0.20),
                category.placeholderColor.opacity(0.06)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            gradient
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 38, weight: .ultraLight))
                    .foregroundStyle(category.placeholderColor.opacity(0.55))
                    .symbolRenderingMode(.hierarchical)
                Text(category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(category.placeholderColor.opacity(0.45))
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
        }
    }
}

private struct ShimmerPlaceholder: View {
    let category: FurnitureItem.Category
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CategoryPlaceholder(category: category)
            .overlay(
                Group {
                    if !reduceMotion {
                        GeometryReader { geo in
                            let w = geo.size.width
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.18), .clear],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: w * 0.6)
                                .offset(x: w * phase)
                                .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: phase)
                        }
                    }
                }
            )
            .onAppear {
                guard !reduceMotion else { return }
                phase = 1.5
            }
    }
}

extension FurnitureItem.Category {
    var placeholderColor: Color {
        switch self {
        case .sofa:     return Color(hex: "7A6452")
        case .chair:    return Color(hex: "6A5A4A")
        case .table:    return Color(hex: "8B6340")
        case .bed:      return Color.Luma.navy
        case .desk:     return Color(hex: "4527A0")
        case .storage:  return Color(hex: "546E7A")
        case .lighting: return Color.Luma.gold
        case .rug:      return Color.Luma.purple
        case .decor:    return Color(hex: "1A7A6E")
        case .plant:    return Color(hex: "2E7D32")
        }
    }
}
