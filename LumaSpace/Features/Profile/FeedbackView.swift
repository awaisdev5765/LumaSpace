import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var message = ""
    @State private var canSendMail = MFMailComposeViewController.canSendMail()
    @State private var showMailComposer = false
    @State private var showFallbackAlert = false

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case general    = "General"
        case bug        = "Bug Report"
        case feature    = "Feature Request"
        case design     = "Design Feedback"
        case billing    = "Billing"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general:  return "bubble.left"
            case .bug:      return "ant.fill"
            case .feature:  return "lightbulb"
            case .design:   return "paintbrush"
            case .billing:  return "creditcard"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Type", selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Your Feedback") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("Tell us what's on your mind…")
                                    .font(LumaFont.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, LumaSpacing.xs + 2)
                                    .padding(.leading, LumaSpacing.xs)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    Button {
                        if canSendMail {
                            showMailComposer = true
                        } else {
                            showFallbackAlert = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Send Feedback", systemImage: "paperplane.fill")
                                .font(LumaFont.headline)
                                .foregroundStyle(Color.Luma.accent)
                            Spacer()
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    subject: "[LumaSpace] \(selectedCategory.rawValue)",
                    body: message,
                    recipient: Config.supportEmail
                ) {
                    AnalyticsService.shared.track(.feedbackSubmitted, properties: ["category": selectedCategory.rawValue])
                    dismiss()
                }
            }
            .alert("Mail Not Available", isPresented: $showFallbackAlert) {
                Button("Copy Email") {
                    UIPasteboard.general.string = Config.supportEmail
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please email \(Config.supportEmail) directly.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Mail Composer UIViewControllerRepresentable

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String
    let onSent: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSent: onSent) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onSent: () -> Void
        init(onSent: @escaping () -> Void) { self.onSent = onSent }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            if result == .sent { onSent() }
        }
    }
}
