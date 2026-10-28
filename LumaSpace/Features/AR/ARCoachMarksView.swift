import SwiftUI

struct ARCoachMarksView: View {
    @Binding var isShowing: Bool
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let marks: [CoachMark] = [
        CoachMark(icon: "hand.tap.fill",      title: "Tap to Place",    body: "Tap the floor to place selected furniture at that location."),
        CoachMark(icon: "hand.draw.fill",     title: "Drag to Move",    body: "Drag any placed item to reposition it anywhere in the room."),
        CoachMark(icon: "arrow.2.circlepath", title: "Rotate",          body: "Use two fingers to rotate a selected piece."),
        CoachMark(icon: "arrow.up.left.and.arrow.down.right", title: "Resize", body: "Pinch in or out to scale furniture proportionally."),
        CoachMark(icon: "arrow.uturn.backward", title: "Undo",          body: "Tap Undo to remove the last placed item, or Reset to clear all.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: LumaSpacing.xxl) {
                Spacer()

                // Coach card
                VStack(spacing: LumaSpacing.lg) {
                    // Progress dots
                    HStack(spacing: LumaSpacing.xs) {
                        ForEach(0..<marks.count, id: \.self) { i in
                            Capsule()
                                .fill(i == step ? Color.white : Color.white.opacity(0.35))
                                .frame(width: i == step ? 20 : 6, height: 6)
                                .animation(reduceMotion ? .none : .lumaFast, value: step)
                        }
                    }

                    // Icon
                    Image(systemName: marks[step].icon)
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                        .transition(.scale.combined(with: .opacity))
                        .id("icon-\(step)")

                    // Text
                    VStack(spacing: LumaSpacing.sm) {
                        Text(marks[step].title)
                            .font(LumaFont.title3)
                            .foregroundStyle(.white)
                        Text(marks[step].body)
                            .font(LumaFont.subhead)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id("text-\(step)")

                    // Buttons
                    HStack(spacing: LumaSpacing.md) {
                        if step > 0 {
                            Button("Back") { advance(by: -1) }
                                .foregroundStyle(.white.opacity(0.7))
                                .font(LumaFont.subhead)
                        }
                        Spacer()
                        Button(step < marks.count - 1 ? "Next" : "Got It!") {
                            if step < marks.count - 1 { advance(by: 1) }
                            else { dismiss() }
                        }
                        .font(LumaFont.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, LumaSpacing.xl)
                        .padding(.vertical, LumaSpacing.md)
                        .background(Color.Luma.accent)
                        .clipShape(Capsule())
                    }
                }
                .padding(LumaSpacing.xxl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.xxl, style: .continuous))
                .padding(.horizontal, LumaSpacing.lg)

                // Skip
                Button("Skip Tutorial") { dismiss() }
                    .font(LumaFont.caption1)
                    .foregroundStyle(.white.opacity(0.6))

                Spacer(minLength: LumaSpacing.xxxl)
            }
        }
        .transition(.opacity)
    }

    private func advance(by delta: Int) {
        withAnimation(reduceMotion ? .none : .lumaSpring) {
            step = max(0, min(marks.count - 1, step + delta))
        }
        LumaHaptics.selection()
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .none : .easeOut) {
            isShowing = false
        }
        UserDefaults.standard.set(true, forKey: "ar_coach_marks_shown")
        LumaHaptics.impact(.light)
    }
}

struct CoachMark {
    let icon: String
    let title: String
    let body: String
}
