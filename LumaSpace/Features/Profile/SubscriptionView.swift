import SwiftUI
import StoreKit

// MARK: - Context

enum SubscriptionContext {
    case onboarding
    case upgrade
    case featureGate(String)
}

// MARK: - Subscription View (Paywall)

struct SubscriptionView: View {
    let context: SubscriptionContext
    var onComplete: (() -> Void)?

    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPlan: PlanOption = .proAnnual
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var headerOffset: CGFloat = 0
    @State private var appeared = false

    private let trialDays = 7

    enum PlanOption: Hashable {
        case proMonthly, proAnnual, premiumMonthly, premiumAnnual, lifetime
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Gradient background
                paywallBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero
                        heroSection
                            .padding(.bottom, LumaSpacing.xl)

                        // White card body
                        VStack(spacing: LumaSpacing.xxl) {
                            if case .featureGate(let feature) = context {
                                featureGateHeader(feature)
                            } else {
                                socialProofStrip
                                valueHeader
                                trialTimelineCard
                            }

                            planSection
                            reviewsSection
                            ctaSection
                            footerLinks
                        }
                        .padding(.horizontal, LumaSpacing.base)
                        .padding(.bottom, LumaSpacing.xxxl)
                        .background(
                            Color(uiColor: .systemBackground)
                                .clipShape(UnevenRoundedRectangle(
                                    topLeadingRadius: LumaRadius.xxl,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: LumaRadius.xxl
                                ))
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if case .onboarding = context {
                            onComplete?()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title3)
                    }
                }
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            withAnimation(.lumaSpring.delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Background

    private var paywallBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "0A1628"), Color(hex: "0F3D35")]
                : [Color(hex: "0F5A51"), Color.Luma.navy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: LumaSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.Luma.goldFallback)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(.lumaBounce.delay(0.2), value: appeared)
            }
            .padding(.top, LumaSpacing.xxl)

            VStack(spacing: LumaSpacing.xs) {
                Text("LumaSpace Pro")
                    .font(LumaFont.largeTitle)
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.lumaSpring.delay(0.15), value: appeared)

                Text("Your rooms, beautifully designed")
                    .font(LumaFont.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.lumaSpring.delay(0.22), value: appeared)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, LumaSpacing.xl)
        .padding(.bottom, LumaSpacing.xxl)
    }

    // MARK: - Feature Gate Header

    private func featureGateHeader(_ feature: String) -> some View {
        VStack(spacing: LumaSpacing.md) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.Luma.accent)
                .symbolRenderingMode(.hierarchical)
                .padding(.top, LumaSpacing.lg)

            Text("Unlock \(feature)")
                .font(LumaFont.title2)
                .multilineTextAlignment(.center)
            Text("This feature is available on Pro and Premium plans.")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Social Proof Strip

    private var socialProofStrip: some View {
        HStack(spacing: LumaSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.Luma.accent)
                .font(.subheadline)
            Text("Trusted by homeowners, designers & real estate agents")
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, LumaSpacing.lg)
    }

    // MARK: - Value Header

    private var valueHeader: some View {
        VStack(spacing: LumaSpacing.sm) {
            Text("Design any room in minutes")
                .font(LumaFont.title2)
                .multilineTextAlignment(.center)
            Text("Scan, design with AI, place furniture in AR — everything you need to transform any space.")
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Trial Timeline Card

    private var trialTimelineCard: some View {
        VStack(spacing: LumaSpacing.md) {
            // Trial badge
            HStack(spacing: LumaSpacing.xs) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(Color.Luma.goldFallback)
                    .font(.subheadline)
                Text("\(trialDays)-day free trial included")
                    .font(LumaFont.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Luma.goldFallback)
            }

            // Visual timeline
            HStack(spacing: 0) {
                TimelineNode(label: "Today", sublabel: "Trial starts", icon: "play.fill", color: .green, isFirst: true)
                TimelineLine()
                TimelineNode(label: "Day \(trialDays)", sublabel: "Reminder", icon: "bell.fill", color: .orange, isFirst: false)
                TimelineLine()
                TimelineNode(label: "Day \(trialDays + 1)", sublabel: "Billing starts", icon: "creditcard.fill", color: Color.Luma.accent, isFirst: false)
            }
        }
        .padding(LumaSpacing.lg)
        .background(Color.Luma.goldFallback.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                .strokeBorder(Color.Luma.goldFallback.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
    }

    // MARK: - Plan Section

    private var planSection: some View {
        VStack(spacing: LumaSpacing.sm) {
            Text("Choose your plan")
                .font(LumaFont.headline)

            // Pro
            PaywallPlanCard(
                tier: "Pro",
                badge: "Most Popular",
                badgeColor: Color.Luma.accent,
                features: [
                    ("Unlimited scans & AI redesigns",  "checkmark.circle.fill"),
                    ("All 10 design styles at once",    "checkmark.circle.fill"),
                    ("HD exports — no watermarks",      "checkmark.circle.fill"),
                    ("iCloud backup & sync",            "checkmark.circle.fill"),
                    ("AR furniture placement",          "checkmark.circle.fill"),
                ],
                monthlyLabel: store.proMonthly.map { "\($0.displayPrice) / mo" } ?? "$4.99 / mo",
                annualLabel:  store.proAnnual.map  { "\($0.displayPrice) / yr" } ?? "$29.99 / yr",
                annualSaving: "Save 50%",
                isSelectedMonthly: selectedPlan == .proMonthly,
                isSelectedAnnual:  selectedPlan == .proAnnual,
                isHighlighted: true,
                onMonthly: { withAnimation(.lumaFast) { selectedPlan = .proMonthly } },
                onAnnual:  { withAnimation(.lumaFast) { selectedPlan = .proAnnual  } }
            )

            // Premium
            PaywallPlanCard(
                tier: "Premium",
                badge: "All Features",
                badgeColor: Color.Luma.goldFallback,
                features: [
                    ("Everything in Pro",              "checkmark.circle.fill"),
                    ("Multi-room whole-home projects", "checkmark.circle.fill"),
                    ("AI Budget Planner",              "checkmark.circle.fill"),
                    ("Future Vision redesigns",        "checkmark.circle.fill"),
                ],
                monthlyLabel: store.premMonthly.map { "\($0.displayPrice) / mo" } ?? "$9.99 / mo",
                annualLabel:  store.premAnnual.map  { "\($0.displayPrice) / yr" } ?? "$49.99 / yr",
                annualSaving: "Save 58%",
                isSelectedMonthly: selectedPlan == .premiumMonthly,
                isSelectedAnnual:  selectedPlan == .premiumAnnual,
                isHighlighted: false,
                onMonthly: { withAnimation(.lumaFast) { selectedPlan = .premiumMonthly } },
                onAnnual:  { withAnimation(.lumaFast) { selectedPlan = .premiumAnnual  } }
            )

            // Lifetime
            PaywallLifetimeCard(
                price: store.lifetime?.displayPrice ?? "$99.99",
                isSelected: selectedPlan == .lifetime,
                onSelect: { withAnimation(.lumaFast) { selectedPlan = .lifetime } }
            )
        }
    }

    // MARK: - Reviews Section

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            Text("Loved by homeowners")
                .font(LumaFont.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LumaSpacing.md) {
                    ForEach(PaywallReview.samples) { review in
                        PaywallReviewCard(review: review)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: LumaSpacing.md) {
            // Main CTA
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: LumaSpacing.sm) {
                    if isPurchasing {
                        ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.body.weight(.semibold))
                        Text(ctaTitle)
                            .font(LumaFont.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(Color.Luma.accent)
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            // Legal sub-text
            Text(legalSubtext)
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Restore
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(LumaFont.caption1)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)

            // Continue with Free (onboarding only)
            if case .onboarding = context {
                Button {
                    onComplete?()
                    dismiss()
                } label: {
                    Text("Continue with Free Plan")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, LumaSpacing.xs)
            }
        }
    }

    // MARK: - Footer Links

    private var footerLinks: some View {
        HStack(spacing: LumaSpacing.xl) {
            Link("Terms of Use", destination: URL(string: Config.termsURL)!)
            Link("Privacy Policy", destination: URL(string: Config.privacyURL)!)
        }
        .font(LumaFont.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: - Computed Strings

    private var ctaTitle: String {
        switch selectedPlan {
        case .proMonthly:     return "Start Free Trial — Pro"
        case .proAnnual:      return "Start Free Trial — Pro Annual"
        case .premiumMonthly: return "Start Free Trial — Premium"
        case .premiumAnnual:  return "Start Free Trial — Premium Annual"
        case .lifetime:       return "Get Lifetime Access"
        }
    }

    private var legalSubtext: String {
        switch selectedPlan {
        case .proMonthly:
            let p = store.proMonthly?.displayPrice ?? "$4.99"
            return "After \(trialDays)-day trial, \(p)/month. Cancel anytime."
        case .proAnnual:
            let p = store.proAnnual?.displayPrice ?? "$29.99"
            return "After \(trialDays)-day trial, \(p)/year. Cancel anytime."
        case .premiumMonthly:
            let p = store.premMonthly?.displayPrice ?? "$9.99"
            return "After \(trialDays)-day trial, \(p)/month. Cancel anytime."
        case .premiumAnnual:
            let p = store.premAnnual?.displayPrice ?? "$49.99"
            return "After \(trialDays)-day trial, \(p)/year. Cancel anytime."
        case .lifetime:
            let p = store.lifetime?.displayPrice ?? "$99.99"
            return "One-time purchase of \(p). No subscriptions, ever."
        }
    }

    private var productID: String {
        switch selectedPlan {
        case .proMonthly:     return StoreService.ProductID.proMonthly
        case .proAnnual:      return StoreService.ProductID.proAnnual
        case .premiumMonthly: return StoreService.ProductID.premMonthly
        case .premiumAnnual:  return StoreService.ProductID.premAnnual
        case .lifetime:       return StoreService.ProductID.lifetime
        }
    }

    // MARK: - Purchase

    private func purchase() async {
        guard let product = store.product(for: productID) else {
            errorMessage = "Product unavailable. Check your connection and try again."
            showError = true
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await store.purchase(product)
            LumaHaptics.notification(.success)
            dismiss()
            onComplete?()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Paywall Plan Card

struct PaywallPlanCard: View {
    let tier: String
    let badge: String
    let badgeColor: Color
    let features: [(String, String)]
    let monthlyLabel: String
    let annualLabel: String
    let annualSaving: String
    let isSelectedMonthly: Bool
    let isSelectedAnnual: Bool
    let isHighlighted: Bool
    let onMonthly: () -> Void
    let onAnnual: () -> Void

    var isEitherSelected: Bool { isSelectedMonthly || isSelectedAnnual }

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            // Header row
            HStack {
                Text(tier)
                    .font(LumaFont.title3)
                Spacer()
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, LumaSpacing.sm)
                    .padding(.vertical, 4)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }

            // Features
            VStack(alignment: .leading, spacing: LumaSpacing.xs + 2) {
                ForEach(features, id: \.0) { label, icon in
                    HStack(spacing: LumaSpacing.sm) {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(badgeColor)
                        Text(label)
                            .font(LumaFont.subhead)
                    }
                }
            }

            Divider()

            // Billing toggle
            HStack(spacing: LumaSpacing.sm) {
                // Monthly
                Button(action: { LumaHaptics.selection(); onMonthly() }) {
                    Text(monthlyLabel)
                        .font(LumaFont.caption1)
                        .fontWeight(isSelectedMonthly ? .semibold : .regular)
                        .padding(.horizontal, LumaSpacing.md)
                        .padding(.vertical, LumaSpacing.md)  // 12pt → 44pt+ touch target
                        .frame(maxWidth: .infinity)
                        .background(isSelectedMonthly ? badgeColor.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(isSelectedMonthly ? badgeColor : .secondary)
                        .overlay {
                            RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                                .strokeBorder(isSelectedMonthly ? badgeColor : Color.clear, lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)

                // Annual
                Button(action: { LumaHaptics.selection(); onAnnual() }) {
                    HStack(spacing: 4) {
                        Text(annualLabel)
                            .font(LumaFont.caption1)
                            .fontWeight(isSelectedAnnual ? .semibold : .regular)
                        Text(annualSaving)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, LumaSpacing.md)
                    .padding(.vertical, LumaSpacing.md)  // 12pt → 44pt+ touch target
                    .frame(maxWidth: .infinity)
                    .background(isSelectedAnnual ? badgeColor.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
                    .foregroundStyle(isSelectedAnnual ? badgeColor : .secondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                            .strokeBorder(isSelectedAnnual ? badgeColor : Color.clear, lineWidth: 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(LumaSpacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                .strokeBorder(
                    isEitherSelected
                        ? badgeColor
                        : (isHighlighted ? badgeColor.opacity(0.3) : Color.clear),
                    lineWidth: isEitherSelected ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
        .shadow(
            color: isEitherSelected ? badgeColor.opacity(0.20) : .black.opacity(0.06),
            radius: isEitherSelected ? 20 : 8,
            y: isEitherSelected ? 6 : 3
        )
        .animation(.lumaFast, value: isEitherSelected)
    }
}

// MARK: - Paywall Lifetime Card

struct PaywallLifetimeCard: View {
    var price: String = "$99.99"
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: { LumaHaptics.selection(); onSelect() }) {
            HStack(spacing: LumaSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: LumaSpacing.xs) {
                        Image(systemName: "infinity")
                            .font(.subheadline)
                            .foregroundStyle(Color.Luma.goldFallback)
                        Text("Lifetime Access")
                            .font(LumaFont.headline)
                    }
                    Text("Pro features forever — pay once, own it")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(LumaFont.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Luma.goldFallback)
                    Text("one-time")
                        .font(LumaFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(LumaSpacing.lg)
            .background(isSelected ? Color.Luma.goldFallback.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous)
                    .strokeBorder(isSelected ? Color.Luma.goldFallback : Color.Luma.goldFallback.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xl, style: .continuous))
            .shadow(color: isSelected ? Color.Luma.goldFallback.opacity(0.25) : .black.opacity(0.05), radius: isSelected ? 18 : 6, y: 3)
            .animation(.lumaFast, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trial Timeline Nodes

struct TimelineNode: View {
    let label: String
    let sublabel: String
    let icon: String
    let color: Color
    let isFirst: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Text(sublabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimelineLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1.5)
            .padding(.bottom, 28) // align with node circles
    }
}

// MARK: - Review Card

struct PaywallReview: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let rating: Int
    let text: String
    let color: Color

    static let samples: [PaywallReview] = [
        PaywallReview(name: "Sarah M.", initials: "SM", rating: 5,
                      text: "Scanned my living room and had three stunning design concepts in under 5 minutes. The AR placement is next level.",
                      color: Color.Luma.accent),
        PaywallReview(name: "James T.", initials: "JT", rating: 5,
                      text: "The fit warning saved me from ordering a sectional that wouldn't clear my doorway. Paid for itself on the first room.",
                      color: Color.Luma.purple),
        PaywallReview(name: "Priya K.", initials: "PK", rating: 5,
                      text: "I send the PDF to every client before we shop. The measurements and shopping list save hours of back-and-forth.",
                      color: Color.Luma.navy),
    ]
}

struct PaywallReviewCard: View {
    let review: PaywallReview

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.md) {
            // Avatar + name
            HStack(spacing: LumaSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(review.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(review.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(review.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.name)
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                    HStack(spacing: 2) {
                        ForEach(0..<review.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.Luma.goldFallback)
                        }
                    }
                }
            }

            Text(review.text)
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LumaSpacing.md)
        .frame(width: 220)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
        .lumaShadow()
    }
}

// MARK: - Feature Lines (used elsewhere if needed)

struct FeatureLine: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let tier: String

    static var all: [FeatureLine] = [
        FeatureLine(icon: "camera.viewfinder",   name: "Unlimited Room Scans",    tier: "Pro+"),
        FeatureLine(icon: "wand.and.stars",       name: "Unlimited AI Redesigns",  tier: "Pro+"),
        FeatureLine(icon: "arkit",               name: "Unlimited AR Placement",  tier: "Pro+"),
        FeatureLine(icon: "doc.richtext",         name: "HD PDF Exports",          tier: "Pro+"),
        FeatureLine(icon: "icloud",              name: "Cloud Backup",             tier: "Pro+"),
        FeatureLine(icon: "square.3.layers.3d",  name: "Multi-Room Projects",     tier: "Premium"),
        FeatureLine(icon: "dollarsign.circle",   name: "Budget Planner",           tier: "Premium"),
        FeatureLine(icon: "sparkles",            name: "Future Vision Mode",       tier: "Premium"),
        FeatureLine(icon: "person.2",            name: "Designer Collab (Soon)",   tier: "Premium"),
    ]
}
