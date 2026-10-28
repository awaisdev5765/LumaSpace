import SwiftUI
import AVFoundation

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var showPermissionSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            // Deep canvas — always near-black, never distracts from content
            Color(hex: "080C10").ignoresSafeArea()

            // Per-page radial glow — transitions with the page
            atmosphericGlow
                .ignoresSafeArea()
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.65), value: currentPage)

            VStack(spacing: 0) {
                pageHeader
                    .padding(.horizontal, LumaSpacing.xl)
                    .padding(.top, LumaSpacing.sm)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, reduceMotion: reduceMotion)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                bottomChrome
                    .padding(.horizontal, LumaSpacing.xl)
                    .padding(.bottom, LumaSpacing.xxxl)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPermissionSheet) {
            OnboardingPermissionSheet {
                Task {
                    await AVCaptureDevice.requestAccess(for: .video)
                    completeOnboarding()
                }
            } onSkip: {
                completeOnboarding()
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(LumaRadius.xl)
        }
    }

    // MARK: - Atmospheric background

    private var atmosphericGlow: some View {
        let accent = pages[currentPage].accentColor
        return ZStack {
            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 20,
                endRadius: 370
            )
            RadialGradient(
                colors: [accent.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 1.05),
                startRadius: 0,
                endRadius: 260
            )
        }
    }

    // MARK: - Header (wordmark on page 0, skip on others)

    private var pageHeader: some View {
        HStack {
            if currentPage == 0 {
                HStack(spacing: LumaSpacing.xs) {
                    Image(systemName: "light.max")
                        .font(LumaFont.subhead.weight(.semibold))
                        .foregroundStyle(pages[0].accentColor)
                    Text("LumaSpace")
                        .font(LumaFont.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Spacer()
            if currentPage < pages.count - 1 {
                Button("Skip") { completeOnboarding() }
                    .font(LumaFont.subhead.weight(.medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(height: 44)
        .animation(reduceMotion ? .none : .lumaFast, value: currentPage)
    }

    // MARK: - Bottom chrome

    private var bottomChrome: some View {
        VStack(spacing: LumaSpacing.lg) {
            pageIndicator

            if currentPage < pages.count - 1 {
                OnboardingContinueButton {
                    LumaHaptics.selection()
                    withAnimation(reduceMotion ? .none : .lumaSpring) { currentPage += 1 }
                }
            } else {
                OnboardingContinueButton(label: "Get Started — It's Free") {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    if status == .notDetermined {
                        showPermissionSheet = true
                    } else {
                        completeOnboarding()
                    }
                }
                Button {
                    Task {
                        await store.restorePurchases()
                        completeOnboarding()
                    }
                } label: {
                    Text("Already subscribed? Restore")
                        .font(LumaFont.footnote)
                        .foregroundStyle(.white.opacity(0.30))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? Color.white : Color.white.opacity(0.22))
                    .frame(width: i == currentPage ? 22 : 6, height: 6)
                    .animation(reduceMotion ? .none : .lumaSpring, value: currentPage)
            }
        }
    }

    private func completeOnboarding() {
        LumaHaptics.notification(.success)
        withAnimation(reduceMotion ? .none : .lumaSpring) { appState.hasCompletedOnboarding = true }
    }
}

// MARK: - Continue / Get Started Button

private struct OnboardingContinueButton: View {
    var label: String = "Continue"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LumaSpacing.sm) {
                Text(label)
                    .font(LumaFont.body.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(LumaFont.footnote.weight(.bold))
            }
            .foregroundStyle(Color(hex: "080C10"))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let reduceMotion: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: LumaSpacing.xl)

            IllustrationView(page: page, appeared: appeared, reduceMotion: reduceMotion)
                .frame(height: 270)

            Spacer().frame(height: LumaSpacing.xxl)

            // Headline + body
            VStack(spacing: LumaSpacing.md) {
                Text(page.headline)
                    .font(LumaFont.largeTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(reduceMotion ? .none : .lumaSpring.delay(0.18), value: appeared)

                Text(page.subheadline)
                    .font(LumaFont.body)
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(reduceMotion ? .none : .lumaSpring.delay(0.26), value: appeared)
            }
            .padding(.horizontal, 36)

            Spacer().frame(height: LumaSpacing.xl)

            // Feature chips
            featureChips
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .animation(reduceMotion ? .none : .lumaSpring.delay(0.34), value: appeared)

            Spacer(minLength: LumaSpacing.lg)
        }
        .onAppear {
            if reduceMotion { appeared = true; return }
            withAnimation(.lumaSpring.delay(0.06)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private var featureChips: some View {
        HStack(spacing: LumaSpacing.sm) {
            ForEach(page.chips, id: \.label) { chip in
                Label(chip.label, systemImage: chip.icon)
                    .font(LumaFont.caption1.weight(.medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.horizontal, 14)
                    .padding(.vertical, LumaSpacing.xs + 2)
                    .background(.white.opacity(0.09), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
            }
        }
    }
}

// MARK: - Illustration

struct IllustrationView: View {
    let page: OnboardingPage
    let appeared: Bool
    let reduceMotion: Bool

    @State private var breathe = false

    var body: some View {
        ZStack {
            // Outermost halo ring (decorative)
            Circle()
                .stroke(page.accentColor.opacity(0.14), lineWidth: 1)
                .frame(width: 236, height: 236)
                .scaleEffect(appeared ? (breathe ? 1.03 : 1.0) : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(
                    reduceMotion ? .none : .lumaSpring.delay(0.04),
                    value: appeared
                )
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 3.8).repeatForever(autoreverses: true),
                    value: breathe
                )
                .accessibilityHidden(true)

            // Mid ring with soft fill (decorative)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [page.accentColor.opacity(0.20), .clear],
                        center: .center, startRadius: 0, endRadius: 90
                    )
                )
                .frame(width: 178, height: 178)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .none : .lumaSpring.delay(0.08), value: appeared)
                .accessibilityHidden(true)

            // Inner filled circle (decorative)
            Circle()
                .fill(page.accentColor.opacity(0.24))
                .frame(width: 112, height: 112)
                .scaleEffect(appeared ? (breathe ? 0.97 : 1.0) : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .none : .lumaBounce.delay(0.04), value: appeared)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.5),
                    value: breathe
                )
                .accessibilityHidden(true)

            // Main icon — labeled for VoiceOver
            Image(systemName: page.systemImage)
                .font(.system(size: 52, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .none : .lumaBounce.delay(0.10), value: appeared)
                .accessibilityLabel(page.headline)
                .accessibilityHidden(false)

            // Floating decorative mini-elements
            ForEach(Array(page.floatingElements.enumerated()), id: \.offset) { i, el in
                FloatingElement(element: el, accentColor: page.accentColor, index: i, appeared: appeared, reduceMotion: reduceMotion)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true).delay(0.4)) {
                breathe = true
            }
        }
    }
}

// MARK: - Floating Element

private struct FloatingElement: View {
    let element: OnboardingFloatingElement
    let accentColor: Color
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    @State private var drift = false

    private var driftX: CGFloat { index % 2 == 0 ? (drift ? 3.0 : -3.0) : (drift ? -4.0 : 4.0) }
    private var driftY: CGFloat { index % 2 == 0 ? (drift ? -4.0 : 4.0) : (drift ? 3.0 : -3.0) }

    var body: some View {
        Image(systemName: element.icon)
            .font(.system(size: element.size, weight: .light))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accentColor.opacity(0.80))
            .frame(width: 34, height: 34)
            .background(accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
            )
            .offset(
                x: element.offset.x + (reduceMotion ? 0 : driftX),
                y: element.offset.y + (reduceMotion ? 0 : driftY)
            )
            .scaleEffect(appeared ? 1 : 0.2)
            .opacity(appeared ? 1 : 0)
            .animation(
                reduceMotion ? .none : .lumaSpring.delay(0.18 + Double(index) * 0.07),
                value: appeared
            )
            .animation(
                reduceMotion ? .none : .easeInOut(duration: Double(3 + index) + 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.5),
                value: drift
            )
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation { drift = true }
            }
    }
}

// MARK: - Model

struct OnboardingChip {
    let icon: String
    let label: String
}

struct OnboardingFloatingElement {
    let icon: String
    let size: CGFloat
    let offset: CGPoint
}

struct OnboardingPage {
    let headline: String
    let subheadline: String
    let systemImage: String
    let accentColor: Color
    let chips: [OnboardingChip]
    let floatingElements: [OnboardingFloatingElement]

    // Backward-compat shims used by SubscriptionView background
    var backgroundColors: [Color] { [Color(hex: "080C10"), accentColor] }
    var features: [String] { chips.map(\.label) }

    static var all: [OnboardingPage] = [
        OnboardingPage(
            headline: "Scan in seconds",
            subheadline: "LiDAR maps every wall, door, and window — no tape measure needed.",
            systemImage: "camera.viewfinder",
            accentColor: Color(hex: "1A7A6E"),
            chips: [
                OnboardingChip(icon: "bolt.fill",  label: "LiDAR precision"),
                OnboardingChip(icon: "ruler.fill",  label: "Exact dimensions"),
            ],
            floatingElements: [
                OnboardingFloatingElement(icon: "ruler",                  size: 15, offset: CGPoint(x: -108, y: -32)),
                OnboardingFloatingElement(icon: "square.3.layers.3d",     size: 14, offset: CGPoint(x: 104,  y: -54)),
                OnboardingFloatingElement(icon: "door.left.hand.open",    size: 14, offset: CGPoint(x: 106,  y:  46)),
                OnboardingFloatingElement(icon: "window.horizontal",      size: 13, offset: CGPoint(x: -102, y:  56)),
            ]
        ),
        OnboardingPage(
            headline: "Design with AI",
            subheadline: "Choose a style. Your room comes back redesigned by world-class AI.",
            systemImage: "wand.and.stars",
            accentColor: Color(hex: "5B4FD4"),
            chips: [
                OnboardingChip(icon: "sparkles",   label: "20 styles"),
                OnboardingChip(icon: "bolt.fill",   label: "Instant results"),
            ],
            floatingElements: [
                OnboardingFloatingElement(icon: "paintpalette",     size: 15, offset: CGPoint(x: -108, y: -42)),
                OnboardingFloatingElement(icon: "photo.artframe",   size: 14, offset: CGPoint(x: 104,  y: -52)),
                OnboardingFloatingElement(icon: "sofa",             size: 14, offset: CGPoint(x: 106,  y:  42)),
                OnboardingFloatingElement(icon: "lightbulb.fill",   size: 13, offset: CGPoint(x: -102, y:  54)),
            ]
        ),
        OnboardingPage(
            headline: "Try before you buy",
            subheadline: "Place furniture at true scale in your actual room. Drag, rotate, see it.",
            systemImage: "arkit",
            accentColor: Color(hex: "1B6CA8"),
            chips: [
                OnboardingChip(icon: "arrow.up.left.and.arrow.down.right", label: "True scale"),
                OnboardingChip(icon: "hand.draw",                           label: "Drag & rotate"),
            ],
            floatingElements: [
                OnboardingFloatingElement(icon: "sofa.fill",            size: 15, offset: CGPoint(x: -106, y: -36)),
                OnboardingFloatingElement(icon: "bed.double.fill",       size: 14, offset: CGPoint(x: 104,  y: -52)),
                OnboardingFloatingElement(icon: "table.furniture.fill",  size: 14, offset: CGPoint(x: 102,  y:  46)),
                OnboardingFloatingElement(icon: "cabinet.fill",          size: 13, offset: CGPoint(x: -100, y:  52)),
            ]
        ),
        OnboardingPage(
            headline: "No surprises",
            subheadline: "AI checks if everything fits. You get a PDF. Your space, perfectly planned.",
            systemImage: "checkmark.seal.fill",
            accentColor: Color(hex: "A0781A"),
            chips: [
                OnboardingChip(icon: "exclamationmark.triangle", label: "Fit checker"),
                OnboardingChip(icon: "doc.richtext.fill",         label: "PDF export"),
            ],
            floatingElements: [
                OnboardingFloatingElement(icon: "dollarsign.circle", size: 15, offset: CGPoint(x: -108, y: -42)),
                OnboardingFloatingElement(icon: "cart.fill",          size: 14, offset: CGPoint(x: 104,  y: -50)),
                OnboardingFloatingElement(icon: "star.fill",          size: 13, offset: CGPoint(x: 102,  y:  48)),
                OnboardingFloatingElement(icon: "heart.fill",         size: 13, offset: CGPoint(x: -100, y:  54)),
            ]
        ),
    ]
}

// MARK: - Permission Pre-Prompt Sheet

private struct OnboardingPermissionSheet: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: LumaSpacing.xxl) {
            VStack(spacing: LumaSpacing.md) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.Luma.accent)

                Text("Camera Access")
                    .font(LumaFont.title2.weight(.bold))

                Text("LumaSpace uses your camera to scan rooms with LiDAR, creating accurate 3D floor plans for AI design generation.")
                    .font(LumaFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, LumaSpacing.xl)
            .padding(.top, LumaSpacing.xxl)

            VStack(spacing: LumaSpacing.md) {
                Button(action: onAllow) {
                    Text("Allow Camera Access")
                        .font(LumaFont.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.Luma.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("Skip for Now")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LumaSpacing.xl)
            .padding(.bottom, LumaSpacing.xxl)
        }
    }
}
