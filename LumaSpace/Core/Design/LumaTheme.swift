import SwiftUI

// MARK: - Color System

extension Color {
    enum Luma {
        // Brand
        static let accent        = Color("LumaAccent")       // Deep teal #1A7A6E
        static let accentLight   = Color("LumaAccentLight")  // #2AA898
        static let accentDark    = Color("LumaAccentDark")   // #0F5A51
        static let gold          = Color("LumaGold")         // Premium #C9A84C
        static let goldLight     = Color("LumaGoldLight")    // #DDB96B

        // Surface
        static let surface       = Color("LumaSurface")
        static let surfaceHigh   = Color("LumaSurfaceHigh")
        static let surfaceRaised = Color("LumaSurfaceRaised")

        // Semantic
        static let positive      = Color("LumaPositive")     // #34C759
        static let warning       = Color("LumaWarning")      // #FF9F0A
        static let destructive   = Color("LumaDestructive")  // #FF3B30
        static let info          = Color("LumaInfo")         // #0A84FF

        // Accent palette — used for category icons and how-it-works steps
        static let purple        = Color("LumaPurple")     // #6A3093 indigo-violet
        static let navy          = Color("LumaNavy")       // #1A2980 deep blue

        // Adaptive fallbacks used where Assets may be absent
        static var accentFallback: Color { Color(red: 0.102, green: 0.478, blue: 0.431) }
        static var goldFallback: Color   { Color(red: 0.788, green: 0.659, blue: 0.298) }
    }
}

// MARK: - Typography
// Uses Apple's semantic text styles so all fonts scale with the user's
// preferred Dynamic Type size (Settings → Display & Brightness → Text Size).
// Titles use the rounded design to match iOS Home Screen / App Store style.

struct LumaFont {
    // Fixed-size display — AR overlays and splash screens only.
    // NOT Dynamic Type — never use in scrollable content.
    static func displayFixed(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Titles — rounded, Dynamic Type-aware
    static let largeTitle = Font.system(.largeTitle,    design: .rounded, weight: .bold)
    static let title1     = Font.system(.title,         design: .rounded, weight: .bold)
    static let title2     = Font.system(.title2,        design: .rounded, weight: .semibold)
    static let title3     = Font.system(.title3,        design: .rounded, weight: .semibold)

    // Content — default SF Pro (HIG recommends for readability)
    static let headline   = Font.system(.headline)
    static let body       = Font.system(.body)
    static let callout    = Font.system(.callout)
    static let subhead    = Font.system(.subheadline)
    static let footnote   = Font.system(.footnote)
    static let caption1   = Font.system(.caption)
    static let caption2   = Font.system(.caption2)
}

// MARK: - Spacing

enum LumaSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let base: CGFloat = 16
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius

enum LumaRadius {
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let lg: CGFloat   = 16
    static let xl: CGFloat   = 20
    static let xxl: CGFloat  = 24
    static let pill: CGFloat = 999
}

// MARK: - Shadow
// Use sparingly — system List already provides visual elevation.
// Only apply on floating elements (modals, cards outside lists, FABs).

struct LumaShadow: ViewModifier {
    var radius: CGFloat
    var y: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

extension View {
    // Soft shadow for floating surfaces (sheets, standalone cards, pickers)
    func lumaShadow(radius: CGFloat = 8, y: CGFloat = 3, opacity: Double = 0.07) -> some View {
        modifier(LumaShadow(radius: radius, y: y, opacity: opacity))
    }
}

// MARK: - Accent Colour Environment Key
// Lets every view read the user's chosen accent colour without needing AppState.

private struct LumaAccentKey: EnvironmentKey {
    static let defaultValue: Color = Color(red: 0.102, green: 0.478, blue: 0.431) // default teal
}

extension EnvironmentValues {
    var lumaAccent: Color {
        get { self[LumaAccentKey.self] }
        set { self[LumaAccentKey.self] = newValue }
    }
}

// MARK: - Liquid Glass Material

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var opacity: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(opacity)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(opacity))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
        }
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = LumaRadius.lg,
        tint: Color = .clear,
        opacity: Double = 0.05
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint, opacity: opacity))
    }
}

// MARK: - Haptics

struct LumaHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Animation

extension Animation {
    static let lumaSpring = Animation.spring(response: 0.45, dampingFraction: 0.75)
    static let lumaFast   = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let lumaBounce = Animation.spring(response: 0.5, dampingFraction: 0.78)
}
