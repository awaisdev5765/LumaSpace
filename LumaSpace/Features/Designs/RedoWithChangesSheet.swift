import SwiftUI

struct RedoWithChangesSheet: View {
    let concept: DesignConcept
    @Binding var prompt: String
    var isLoading: Bool
    let onConfirm: () -> Void

    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private let suggestions = [
        "Make the walls lighter",
        "Add more plants",
        "Use warmer lighting",
        "Make it more minimalist",
        "Add a bold accent color",
        "Use natural wood tones",
        "Make it cozier",
        "Add more storage",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: LumaSpacing.xxl) {
                HStack(spacing: LumaSpacing.md) {
                    LinearGradient(
                        colors: concept.style.palette,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Refining: \(concept.style.rawValue)")
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                        Text(concept.title)
                            .font(LumaFont.caption1)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(LumaSpacing.md)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                    Text("What would you like to change?")
                        .font(LumaFont.headline)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .font(LumaFont.body)
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(LumaSpacing.sm)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.md, style: .continuous))
                            .focused($isFocused)
                        if prompt.isEmpty {
                            Text("e.g. make the walls lighter, add more plants…")
                                .font(LumaFont.body)
                                .foregroundStyle(.tertiary)
                                .padding(LumaSpacing.sm + 4)
                                .allowsHitTesting(false)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: LumaSpacing.sm) {
                    Text("Quick Suggestions")
                        .font(LumaFont.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: LumaSpacing.xs) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    prompt = suggestion
                                    LumaHaptics.selection()
                                } label: {
                                    Text(suggestion)
                                        .font(LumaFont.caption1)
                                        .fontWeight(.medium)
                                        .foregroundStyle(prompt == suggestion ? .white : Color.Luma.accent)
                                        .padding(.horizontal, LumaSpacing.md)
                                        .padding(.vertical, LumaSpacing.xs + 2)
                                        .background(prompt == suggestion ? Color.Luma.accent : Color.Luma.accent.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(Color.Luma.accent.opacity(0.25), lineWidth: prompt == suggestion ? 0 : 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                LumaPrimaryButton(
                    "Regenerate with Changes",
                    icon: "arrow.clockwise",
                    isLoading: isLoading
                ) {
                    isFocused = false
                    onConfirm()
                }
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(LumaSpacing.base)
            .navigationTitle("Redo with Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
