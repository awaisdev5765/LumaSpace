import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var expandedSection: HelpSection.ID?

    private var filtered: [HelpSection] {
        guard !searchText.isEmpty else { return HelpSection.all }
        return HelpSection.all.filter { section in
            section.title.localizedCaseInsensitiveContains(searchText) ||
            section.items.contains { $0.question.localizedCaseInsensitiveContains(searchText) ||
                                     $0.answer.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick start banner
                Section {
                    QuickStartBanner()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Shortcuts
                Section("Quick Actions") {
                    Button {
                        appState.hasCompletedOnboarding = false
                        dismiss()
                        LumaHaptics.impact(.light)
                    } label: {
                        Label("Replay App Tutorial", systemImage: "play.circle.fill")
                            .foregroundStyle(Color.Luma.accent)
                    }

                    Button {
                        UserDefaults.standard.removeObject(forKey: "ar_coach_marks_shown")
                        appState.activeTab = .ar
                        dismiss()
                        LumaHaptics.impact(.light)
                    } label: {
                        Label("Replay Furnish Tips (AR gestures)", systemImage: "chair")
                            .foregroundStyle(Color.Luma.accent)
                    }
                }

                // FAQ sections
                ForEach(filtered) { section in
                    Section {
                        ForEach(section.items) { item in
                            HelpItemRow(item: item)
                        }
                    } header: {
                        Label(section.title, systemImage: section.icon)
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Luma.accent)
                            .textCase(nil)
                    }
                }

                // Contact support
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Still need help?")
                                .font(LumaFont.subhead)
                                .fontWeight(.semibold)
                            Text("Our support team typically responds within 24 hours.")
                                .font(LumaFont.caption1)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Link(destination: URL(string: "mailto:\(Config.supportEmail)")!) {
                            Label("Email Us", systemImage: "envelope")
                                .font(LumaFont.caption1)
                                .fontWeight(.semibold)
                                .padding(.horizontal, LumaSpacing.md)
                                .padding(.vertical, LumaSpacing.xs + 2)
                                .background(Color.Luma.accent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search help topics")
            .navigationTitle("Help & Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Quick Start Banner

struct QuickStartBanner: View {
    private struct Step {
        let number: Int
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(number: 1, icon: "camera.viewfinder", color: Color(hex: "1A7A6E"),
             title: "Scan a Room",
             detail: "Open the Scan tab. Walk slowly around the room — LiDAR captures precise walls, doors, and dimensions in under a minute."),
        Step(number: 2, icon: "wand.and.stars", color: Color.Luma.purple,
             title: "Generate AI Designs",
             detail: "Go to Designs, pick your room and a style, then tap Generate. GPT-4o and DALL·E 3 create photorealistic concepts tailored to your space."),
        Step(number: 3, icon: "chair", color: Color.Luma.navy,
             title: "Furnish Your Room",
             detail: "Open the Furnish tab. Tap + Add Furniture, pick an item, then point at the floor and tap to place it. Drag to move, pinch to resize, two fingers to rotate."),
        Step(number: 4, icon: "doc.richtext.fill", color: Color.Luma.gold,
             title: "Export & Shop",
             detail: "Tap ··· → Export PDF for a full report with measurements and shopping links. Tap Shop on any furniture item to buy it directly from the retailer.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LumaSpacing.sm) {
            Text("How to Use LumaSpace")
                .font(LumaFont.subhead)
                .fontWeight(.bold)
                .padding(.horizontal, LumaSpacing.base)
                .padding(.top, LumaSpacing.md)

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: LumaSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(step.color.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: step.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(step.color)
                                .symbolRenderingMode(.hierarchical)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: LumaSpacing.xs) {
                                Text("Step \(step.number)")
                                    .font(LumaFont.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(step.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(step.color.opacity(0.10))
                                    .clipShape(Capsule())
                                Text(step.title)
                                    .font(LumaFont.subhead)
                                    .fontWeight(.semibold)
                            }
                            Text(step.detail)
                                .font(LumaFont.caption1)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(LumaSpacing.md)

                    if index < steps.count - 1 {
                        HStack {
                            Spacer().frame(width: 44 + LumaSpacing.md)
                            Rectangle()
                                .fill(Color(uiColor: .separator).opacity(0.5))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, LumaSpacing.md)
                    }
                }
            }
            .background(Color.Luma.accent.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                    .strokeBorder(Color.Luma.accent.opacity(0.12), lineWidth: 1)
            }
            .padding(.horizontal, LumaSpacing.base)
            .padding(.bottom, LumaSpacing.sm)
        }
    }
}

// MARK: - Help Item Row

struct HelpItemRow: View {
    let item: HelpItem
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(item.answer)
                .font(LumaFont.subhead)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, LumaSpacing.xs)
        } label: {
            Text(item.question)
                .font(LumaFont.subhead)
                .fontWeight(.medium)
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded { LumaHaptics.selection() }
        }
    }
}

// MARK: - Models

struct HelpSection: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let items: [HelpItem]

    static let all: [HelpSection] = [
        HelpSection(icon: "camera.viewfinder", title: "Room Scanning", items: [
            HelpItem("Which iPhone models support room scanning?",
                     "Room scanning with LiDAR requires iPhone 12 Pro, 12 Pro Max, or any later Pro model. The standard iPhone models don't include a LiDAR scanner. All other app features work on any iPhone running iOS 17+."),
            HelpItem("How do I get the best scan results?",
                     "Move slowly around the room's perimeter, keeping the camera 1–2 metres from walls. Scan in good lighting. Capture all four corners, doors, and windows. The scan typically takes 30–60 seconds."),
            HelpItem("Can I rescan a room?",
                     "Yes — open the project, tap the room, and choose 'Rescan'. This replaces the existing scan with a fresh one."),
            HelpItem("Why is my scan incomplete?",
                     "Common causes: low lighting, moving too quickly, or not covering the full perimeter. Try rescanning in daylight and moving more slowly."),
            HelpItem("What does the Room Score mean?",
                     "After scanning, LumaSpace AI analyses your room for traffic flow, lighting, and space utilisation. The score (0–100) reflects how well-optimised the space currently is. Common issues and suggestions are shown below the score.")
        ]),
        HelpSection(icon: "wand.and.stars", title: "AI Design", items: [
            HelpItem("What AI powers LumaSpace?",
                     "LumaSpace uses GPT-4o for room analysis, design text, colour palettes and budget planning. DALL·E 3 generates photorealistic design images and Future Vision renders."),
            HelpItem("How does the AI work?",
                     "LumaSpace uses GPT-4o and DALL·E 3 via a built-in connection — no setup required. Just open the Designs tab, pick a room and style, and tap Generate."),
            HelpItem("Why are my designs taking a long time?",
                     "Each design concept generates both a text description and a DALL·E 3 image. Image generation typically takes 10–20 seconds per concept. Multiple styles generate in sequence."),
            HelpItem("What design styles are available?",
                     "Japandi, Scandinavian, Modern Luxury, Minimalist, Industrial, Coastal, Contemporary, Organic Modern, Bohemian, and Mid-Century Modern. Pro and Premium unlock all 10 styles simultaneously."),
            HelpItem("What is Future Vision?",
                     "A Premium feature. Upload your room photo or use a scanned room, choose a scenario (Luxury Upgrade, Budget Makeover, Office Conversion, etc.), and set a budget. AI generates a photorealistic transformation and a plan to achieve it.")
        ]),
        HelpSection(icon: "chair", title: "Furnish — AR Furniture Placement", items: [
            HelpItem("How do I place furniture in my room?",
                     "Open the Furnish tab. Tap '+ Add Furniture', pick an item from the catalogue, then point your camera at a flat floor surface until you see the reticle appear — then tap to place. Drag to move, use two fingers to rotate, pinch to resize."),
            HelpItem("The furniture is floating — how do I fix it?",
                     "Point the camera at a flat floor surface and move the device slowly until the placement reticle appears. The reticle turns solid when a valid surface is detected. Ensure good lighting for best surface detection."),
            HelpItem("How do I save my AR layout?",
                     "Tap the save icon (arrow pointing down) in the top-right of the AR screen. Your placed furniture list is saved to the project."),
            HelpItem("What does the fit warning mean?",
                     "When a piece of furniture reduces walkway clearance below 90 cm (the recommended minimum), LumaSpace shows a warning. This helps prevent layouts that feel cramped in real life."),
            HelpItem("Can I undo placement?",
                     "Yes — tap the undo arrow to remove the last placed item. You can undo multiple times. The Reset button clears the entire scene.")
        ]),
        HelpSection(icon: "crown.fill", title: "Subscriptions & Billing", items: [
            HelpItem("What's included in the Free plan?",
                     "3 room scans, 5 AI redesigns per month, 1 design style, 5 AR placements, watermarked exports, and local storage only."),
            HelpItem("What does Pro add?",
                     "Unlimited scans, unlimited AI redesigns, all 10 design styles, HD exports without watermarks, cloud backup, and unlimited AR placements. $4.99/month or $29.99/year."),
            HelpItem("What does Premium add over Pro?",
                     "Everything in Pro plus: whole-home multi-room projects, AI renovation planner, budget estimator, shopping assistant, designer collaboration, Future Vision mode, and priority AI rendering. $9.99/month or $49.99/year."),
            HelpItem("How do I restore my purchases?",
                     "Open Profile → Restore Purchases. Your purchases are tied to your Apple ID and will restore on any device signed in with the same account."),
            HelpItem("How do I cancel my subscription?",
                     "Go to iPhone Settings → Apple ID → Subscriptions → LumaSpace. Subscriptions must be cancelled at least 24 hours before the renewal date.")
        ]),
        HelpSection(icon: "square.and.arrow.up", title: "Exporting & Sharing", items: [
            HelpItem("How do I export a PDF report?",
                     "Open a project or design concept, tap the ··· menu, and choose 'Export PDF'. The report includes the floor plan, measurements, design concepts, colour palette, furniture list, and budget."),
            HelpItem("Can I share a design with my interior designer?",
                     "Yes — export a PDF and share it via any app (Mail, Messages, AirDrop, etc.). Premium subscribers can also use the Designer Collaboration feature for real-time sharing."),
            HelpItem("How do I save a design image to Photos?",
                     "In a design concept, tap the ··· menu → Share Design, then choose 'Save Image' from the share sheet."),
            HelpItem("What is Virtual Staging?",
                     "Virtual Staging (Pro+) lets you upload a photo of any empty room and AI furnishes it in your chosen style. Ideal for real estate agents preparing listings.")
        ]),
        HelpSection(icon: "icloud", title: "Cloud & Privacy", items: [
            HelpItem("Where is my data stored?",
                     "Projects are stored locally on your device. Pro and Premium subscribers also get iCloud backup via CloudKit. AI generation uses LumaSpace's secure server connection — your room data stays on your device."),
            HelpItem("Is my room scan data private?",
                     "Room scan data stays on your device. When you generate AI designs, only a text description of your room dimensions and type is sent to OpenAI — no images or scan files."),
            HelpItem("How do I delete my data?",
                     "Delete individual projects from the Home screen by swiping left. To delete all data, uninstall the app. iCloud data can be deleted from iPhone Settings → Apple ID → iCloud → Manage Storage → LumaSpace.")
        ])
    ]
}

struct HelpItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String

    init(_ question: String, _ answer: String) {
        self.question = question
        self.answer = answer
    }
}
