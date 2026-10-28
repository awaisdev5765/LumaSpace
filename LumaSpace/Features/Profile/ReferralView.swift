import SwiftUI

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let referral = ReferralService.shared
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: LumaSpacing.xxl) {
                // Hero
                VStack(spacing: LumaSpacing.md) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(Color.Luma.goldFallback)
                        .symbolRenderingMode(.hierarchical)
                    Text("Invite Friends to LumaSpace")
                        .font(LumaFont.title2)
                        .multilineTextAlignment(.center)
                    Text("Share your code and help friends discover their perfect space. More friends = more inspiration for everyone.")
                        .font(LumaFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, LumaSpacing.xxl)

                // Code display
                HStack {
                    Text(referral.myCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.Luma.accent)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = referral.myCode
                        copied = true
                        LumaHaptics.notification(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(LumaFont.subhead)
                            .fontWeight(.semibold)
                            .foregroundStyle(copied ? .green : Color.Luma.accent)
                    }
                    .animation(reduceMotion ? .none : .lumaFast, value: copied)
                }
                .padding(LumaSpacing.lg)
                .background(Color.Luma.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LumaRadius.lg, style: .continuous)
                        .strokeBorder(Color.Luma.accent.opacity(0.25), lineWidth: 1)
                }

                // Stats
                if referral.referralCount > 0 {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(Color.Luma.accent)
                        Text("\(referral.referralCount) friend\(referral.referralCount == 1 ? "" : "s") joined with your code")
                            .font(LumaFont.subhead)
                            .foregroundStyle(.secondary)
                    }
                }

                // Share button
                LumaPrimaryButton("Share Your Code", icon: "square.and.arrow.up") {
                    referral.shareCode(from: UIApplication.shared.topViewController)
                }

                Spacer()

                // Terms
                Text("Help your friends discover LumaSpace — every code shared counts.")
                    .font(LumaFont.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal, LumaSpacing.xxl)
            .padding(.bottom, LumaSpacing.xxxl)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
