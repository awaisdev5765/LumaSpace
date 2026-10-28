import SwiftUI

struct NotificationPrePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: LumaSpacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.Luma.accent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.Luma.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, LumaSpacing.xl)

            VStack(spacing: LumaSpacing.md) {
                Text("Stay inspired")
                    .font(LumaFont.title2)
                    .fontWeight(.bold)
                Text("Let us nudge you when it's time to refine your room — we'll only send what's useful.")
                    .font(LumaFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: LumaSpacing.md) {
                NotifBenefitRow(icon: "sparkles", text: "Know when your AI designs are ready")
                NotifBenefitRow(icon: "arrow.clockwise", text: "Pick up your project where you left off")
                NotifBenefitRow(icon: "calendar.badge.clock", text: "Weekly inspiration every Sunday")
            }
            .padding(LumaSpacing.lg)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))

            Spacer()

            VStack(spacing: LumaSpacing.md) {
                LumaPrimaryButton("Allow Notifications", icon: "bell.fill") {
                    onAllow()
                    dismiss()
                }
                Button("Not Now") { dismiss() }
                    .font(LumaFont.subhead)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, LumaSpacing.xl)
        .padding(.bottom, LumaSpacing.xl)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct NotifBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: LumaSpacing.md) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.Luma.accent)
                .frame(width: 24)
            Text(text)
                .font(LumaFont.subhead)
        }
    }
}
