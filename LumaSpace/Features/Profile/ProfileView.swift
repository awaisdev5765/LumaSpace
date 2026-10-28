import SwiftUI
import StoreKit
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var projectStore: ProjectStore
    @StateObject private var account = AccountService.shared
    @State private var showSubscription = false
    @State private var showNotifications = false
    @State private var notificationsEnabled = false
    @State private var showFeedback = false
    @State private var showReferral = false
    @State private var showHelp = false
    @State private var shareSheetItem: URL?
    @State private var showSignOutConfirm = false
    @State private var showDeleteDataConfirm = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                planSection
                statsSection
                settingsSection
                supportSection
                dataSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView(context: .upgrade)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showReferral) {
            ReferralView()
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
                .environmentObject(appState)
        }
        .task {
            await refreshNotificationState()
            await account.checkCredentialState()
            await account.checkICloudStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refreshNotificationState() }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if account.isSignedIn {
                HStack(spacing: LumaSpacing.md) {
                    // Avatar initials circle
                    ZStack {
                        Circle()
                            .fill(appState.accentColor.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Text(account.initials)
                            .font(LumaFont.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(appState.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName ?? "Apple Account")
                            .font(LumaFont.headline)
                        if let email = account.email {
                            Text(email)
                                .font(LumaFont.caption1)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: account.iCloudAvailable ? "icloud.fill" : "icloud.slash")
                                .font(.caption2)
                                .foregroundStyle(account.iCloudAvailable ? Color.Luma.accent : .secondary)
                            Text(account.iCloudAvailable ? "iCloud Sync On" : "iCloud Unavailable")
                                .font(LumaFont.caption2)
                                .foregroundStyle(account.iCloudAvailable ? Color.Luma.accent : .secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, LumaSpacing.xs)

                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                    Button("Sign Out", role: .destructive) { account.signOut() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your data stays on this device. Sign back in with the same Apple ID to restore access.")
                }
            } else {
                VStack(alignment: .leading, spacing: LumaSpacing.md) {
                    Text("Connect your Apple ID to protect your data and enable cross-device sync via iCloud.")
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        if case .success(let auth) = result,
                           let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                            account.handleSignIn(credential: credential)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                }
                .padding(.vertical, LumaSpacing.xs)
            }
        } header: {
            Text("Account")
        } footer: {
            if !account.isSignedIn {
                Text("Sign in with Apple uses Face ID and your Apple ID. LumaSpace never sees your Apple credentials.")
            }
        }
    }

    private func refreshNotificationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
    }

    // MARK: - Plan Section

    private var planSection: some View {
        Section {
            HStack(spacing: LumaSpacing.md) {
                ZStack {
                    Circle()
                        .fill(planGradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: store.currentTier.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(store.currentTier.rawValue + " Plan")
                            .font(LumaFont.headline)
                        if store.currentTier != .free {
                            PremiumBadge()
                        }
                    }
                    Text(planSubtitle)
                        .font(LumaFont.caption1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.currentTier == .free {
                    Button("Upgrade") {
                        showSubscription = true
                        LumaHaptics.impact(.medium)
                    }
                    .font(LumaFont.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, LumaSpacing.md)
                    .padding(.vertical, LumaSpacing.xs + 2)
                    .background(appState.accentColor)
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, LumaSpacing.xs)

            if store.currentTier == .free {
                VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                    Text("Free Plan Limits")
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    PlanLimitRow(icon: "camera.viewfinder", label: "Room Scans", used: projectStore.projects.flatMap(\.rooms).count, max: 3)
                    PlanLimitRow(icon: "wand.and.stars", label: "AI Redesigns / month", used: UsageTracker.shared.aiRedesignCount, max: 5)
                }
                .padding(.vertical, LumaSpacing.xs)
            }
        } header: {
            Text("Subscription")
        }
    }

    private var planGradient: LinearGradient {
        switch store.currentTier {
        case .free:     return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pro:      return LinearGradient(colors: [Color.Luma.accent, Color(hex: "1A7A6E")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .premium:  return LinearGradient(colors: [Color.Luma.goldFallback, Color.Luma.gold], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .lifetime: return LinearGradient(colors: [Color.Luma.purple, Color(hex: "A044FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var planSubtitle: String {
        switch store.currentTier {
        case .free:     return "3 scans • 5 AI redesigns/month"
        case .pro:      return "Unlimited scans & AI redesigns"
        case .premium:  return "Everything + whole-home projects"
        case .lifetime: return "Forever access to Pro features"
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        Section("Your Activity") {
            HStack(spacing: 0) {
                StatCell(
                    value: projectStore.projects.count,
                    label: "Projects",
                    trend: projectStore.projects.count > 0 ? "active" : nil
                )
                Divider().frame(height: 40)
                StatCell(
                    value: projectStore.projects.flatMap(\.rooms).count,
                    label: "Rooms",
                    trend: nil
                )
                Divider().frame(height: 40)
                StatCell(
                    value: projectStore.projects.flatMap(\.designs).count,
                    label: "Designs",
                    trend: nil
                )
            }
            .padding(.vertical, LumaSpacing.xs)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        Section("Settings") {
            // Theme — accent colour swatch preview
            NavigationLink {
                AppearanceSettingsView()
                    .environmentObject(appState)
            } label: {
                HStack {
                    Label("Theme", systemImage: "paintpalette")
                    Spacer()
                    Circle()
                        .fill(appState.accentColor)
                        .frame(width: 16, height: 16)
                        .overlay { Circle().strokeBorder(.separator, lineWidth: 0.5) }
                }
            }

            Toggle(isOn: $notificationsEnabled) {
                Label("Smart Reminders", systemImage: "bell.badge")
            }
            .tint(appState.accentColor)
            .onChange(of: notificationsEnabled) { _, enabled in
                if enabled {
                    Task {
                        let granted = await NotificationService.shared.requestPermission()
                        if granted {
                            NotificationService.shared.scheduleWeeklyInspiration()
                        } else {
                            // Permission denied — open Settings
                            await MainActor.run {
                                notificationsEnabled = false
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                } else {
                    NotificationService.shared.cancelAll()
                }
            }

            NavigationLink {
                ExportSettingsView()
            } label: {
                Label("Export Preferences", systemImage: "square.and.arrow.up")
            }

            NavigationLink {
                CloudSyncView()
            } label: {
                HStack {
                    Label("Cloud Sync", systemImage: "icloud")
                    if store.currentTier == .free {
                        Spacer()
                        PremiumBadge(compact: true)
                    }
                }
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section("Support") {
            Button {
                showReferral = true
                LumaHaptics.impact(.light)
            } label: {
                HStack {
                    Label("Invite Friends", systemImage: "gift.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Share the app")
                        .font(LumaFont.caption1)
                        .foregroundStyle(Color.Luma.goldFallback)
                }
            }

            Button {
                showFeedback = true
            } label: {
                Label("Send Feedback", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(.primary)
            }

            Button {
                showHelp = true
            } label: {
                Label("Help & FAQ", systemImage: "questionmark.circle")
                    .foregroundStyle(.primary)
            }

            // Replay onboarding tutorial
            Button {
                appState.hasCompletedOnboarding = false
                LumaHaptics.impact(.light)
            } label: {
                Label("View Tutorial", systemImage: "play.circle")
                    .foregroundStyle(.primary)
            }

            Link(destination: URL(string: "https://lumaspace.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
                    .foregroundStyle(.primary)
            }

            Button {
                Task {
                    await store.restorePurchases()
                    LumaHaptics.notification(.success)
                }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .foregroundStyle(.primary)
            }

            Button {
                if let url = Config.appStoreReviewURL {
                    UIApplication.shared.open(url)
                } else if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            } label: {
                Label("Rate LumaSpace", systemImage: "star")
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteDataConfirm = true
            } label: {
                Label("Delete All My Data", systemImage: "trash")
            }
            .confirmationDialog(
                "Delete All Data?",
                isPresented: $showDeleteDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all projects, rooms, designs, and settings from this device and iCloud. Your subscription is not affected — manage it in iPhone Settings → Subscriptions.")
            }
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Deletes all local data. iCloud data is removed from your private iCloud account. Your subscription remains active and can be restored at any time.")
        }
    }

    private func deleteAllData() {
        // 1. Delete all projects (removes Spotlight index entries and CloudKit records)
        let allProjects = projectStore.projects
        allProjects.forEach { projectStore.delete($0) }

        // 2. Clear Spotlight
        SpotlightService.shared.removeAll()

        // 3. Reset usage counters
        UsageTracker.shared.totalScansCompleted = 0
        UsageTracker.shared.hasRequestedReview = false
        appState.hasSeenReferralBanner = false
        UsageTracker.shared.aiRedesignCount = 0

        // 4. Clear AR coach marks so the tutorial replays on next AR session
        UserDefaults.standard.removeObject(forKey: "ar_coach_marks_shown")

        // 5. Reset aha-moment paywall flag so it fires again after first new design
        appState.hasSeenFirstDesignPaywall = false

        // 6. Reset onboarding (sends user back to start)
        appState.hasCompletedOnboarding = false

        LumaHaptics.notification(.success)
        AnalyticsService.shared.track(.projectDeleted, properties: ["bulk": true])
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Text("LumaSpace v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(LumaFont.caption1)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Supporting Views

struct PlanLimitRow: View {
    let icon: String
    let label: String
    let used: Int
    let max: Int

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(LumaFont.caption1)
            Spacer()
            Text("\(used)/\(max)")
                .font(LumaFont.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(used >= max ? .red : .secondary)
            LumaProgressRing(progress: Double(used) / Double(max), lineWidth: 3, size: 20)
        }
    }
}

struct StatCell: View {
    let value: Int
    let label: String
    var trend: String?

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(LumaFont.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(LumaFont.caption1)
                .foregroundStyle(.secondary)
            if let trend {
                Text(trend)
                    .font(LumaFont.caption2)
                    .foregroundStyle(Color.Luma.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Appearance Settings (Full Theme Screen)

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("preferredColorScheme") private var storedScheme = 0

    private let schemes: [(Int, String, String)] = [
        (0, "Automatic", "circle.lefthalf.filled"),
        (1, "Light",     "sun.max"),
        (2, "Dark",      "moon.stars"),
    ]

    var body: some View {
        Form {
            // MARK: Appearance Mode
            Section {
                HStack(spacing: 0) {
                    ForEach(schemes, id: \.0) { tag, label, icon in
                        Button {
                            storedScheme = tag
                            LumaHaptics.selection()
                        } label: {
                            VStack(spacing: LumaSpacing.xs) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                                        .fill(storedScheme == tag
                                              ? appState.accentColor.opacity(0.12)
                                              : Color(uiColor: .tertiarySystemFill))
                                        .frame(height: 52)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous)
                                                .strokeBorder(storedScheme == tag ? appState.accentColor : Color.clear, lineWidth: 2)
                                        }
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(storedScheme == tag ? appState.accentColor : .secondary)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text(label)
                                    .font(LumaFont.caption1)
                                    .foregroundStyle(storedScheme == tag ? appState.accentColor : .secondary)
                                    .fontWeight(storedScheme == tag ? .semibold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .animation(.lumaFast, value: storedScheme)
                    }
                }
                .padding(.vertical, LumaSpacing.xs)
            } header: {
                Text("Appearance")
            }

            // MARK: Accent Colour
            Section {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: LumaSpacing.sm), count: 8),
                    spacing: LumaSpacing.sm
                ) {
                    ForEach(Color.lumaAccents.indices, id: \.self) { i in
                        let accent = Color.lumaAccents[i]
                        Button {
                            appState.accentColorIndex = i
                            LumaHaptics.selection()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 36, height: 36)
                                if appState.accentColorIndex == i {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accent.name)
                        .animation(.lumaFast, value: appState.accentColorIndex)
                    }
                }
                .padding(.vertical, LumaSpacing.xs)

                HStack {
                    Text("Selected")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Color.lumaAccents[safe: appState.accentColorIndex]?.name ?? "Teal")
                        .font(LumaFont.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(appState.accentColor)
                }
            } header: {
                Text("Accent Colour")
            } footer: {
                Text("The accent colour applies to buttons, highlights, and interactive elements throughout the app.")
            }

            // MARK: Layout
            Section {
                Toggle(isOn: $appState.useCompactLayout) {
                    Label("Compact Layout", systemImage: "rectangle.compress.vertical")
                }
                .tint(appState.accentColor)
            } header: {
                Text("Display")
            } footer: {
                Text("Reduces padding and card sizes for more content on screen.")
            }

        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Export Settings

struct ExportSettingsView: View {
    @EnvironmentObject private var store: StoreService
    @AppStorage("exportIncludeFloorPlan") private var includeFloorPlan = true
    @AppStorage("exportIncludeBudget")    private var includeBudget    = true
    @AppStorage("exportIncludeDesigns")   private var includeDesigns   = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Format", systemImage: "doc.richtext")
                    Spacer()
                    Text("PDF")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Export format: PDF")
            } header: {
                Text("Format")
            } footer: {
                Text("All projects export as multi-page PDF. Includes cover, floor plan, room analysis, designs, and budget.")
            }

            Section("Include in Export") {
                Toggle(isOn: $includeFloorPlan) {
                    Label("Floor Plan", systemImage: "square.dashed")
                }
                .tint(Color.Luma.accent)

                Toggle(isOn: $includeDesigns) {
                    Label("Design Concepts", systemImage: "paintbrush")
                }
                .tint(Color.Luma.accent)

                Toggle(isOn: $includeBudget) {
                    Label("Budget Plan", systemImage: "dollarsign.circle")
                }
                .tint(Color.Luma.accent)
            }

            Section("Quality") {
                if store.currentTier == .free {
                    HStack {
                        Label("HD Export + No Watermark", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        PremiumBadge()
                    }
                } else {
                    Label("HD Quality — No Watermark", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.Luma.accent)
                }
            }
        }
        .navigationTitle("Export Preferences")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Cloud Sync Placeholder

struct CloudSyncView: View {
    @EnvironmentObject private var store: StoreService

    var body: some View {
        VStack(spacing: LumaSpacing.xxl) {
            Image(systemName: "icloud")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(store.hasCloudSync ? Color.Luma.accent : Color.secondary)
                .symbolRenderingMode(.hierarchical)

            if store.hasCloudSync {
                VStack(spacing: LumaSpacing.md) {
                    Text("Cloud Sync Active")
                        .font(LumaFont.title3)
                    Text("Your projects are backed up to iCloud automatically.")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: LumaSpacing.md) {
                    Text("Cloud Sync")
                        .font(LumaFont.title3)
                    Text("Upgrade to Pro to enable automatic iCloud backup across all your devices.")
                        .font(LumaFont.subhead)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .navigationTitle("Cloud Sync")
    }
}

extension StoreService {
    var hasCloudSync: Bool { currentTier != .free }
}

