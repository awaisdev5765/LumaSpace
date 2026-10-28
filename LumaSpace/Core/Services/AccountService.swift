import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AccountService: NSObject, ObservableObject {
    static let shared = AccountService()

    @Published var displayName: String?
    @Published var userID: String?
    @Published var email: String?
    @Published var iCloudAvailable: Bool = false

    private let keyUserID = "siwa_user_id"
    private let keyName   = "siwa_display_name"
    private let keyEmail  = "siwa_email"

    var isSignedIn: Bool { userID != nil }

    var initials: String {
        guard let name = displayName, !name.isEmpty else { return "?" }
        return name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    override init() {
        super.init()
        loadStoredCredentials()
    }

    // MARK: - Credential handling

    func handleSignIn(credential: ASAuthorizationAppleIDCredential) {
        let id = credential.user

        var name: String? = nil
        if let fn = credential.fullName {
            let parts = [fn.givenName, fn.familyName].compactMap { $0 }.filter { !$0.isEmpty }
            if !parts.isEmpty { name = parts.joined(separator: " ") }
        }
        let emailStr = credential.email

        KeychainService.save(id, for: keyUserID)
        if let n = name { KeychainService.save(n, for: keyName) }
        if let e = emailStr { KeychainService.save(e, for: keyEmail) }

        userID      = id
        displayName = name ?? KeychainService.load(for: keyName)
        email       = emailStr ?? KeychainService.load(for: keyEmail)
    }

    func signOut() {
        KeychainService.delete(for: keyUserID)
        KeychainService.delete(for: keyName)
        KeychainService.delete(for: keyEmail)
        userID = nil
        displayName = nil
        email = nil
    }

    // MARK: - Credential refresh

    func checkCredentialState() async {
        guard let id = userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state = (try? await provider.credentialState(forUserID: id)) ?? .notFound
        if state != .authorized { signOut() }
    }

    func checkICloudStatus() async {
        iCloudAvailable = await CloudSyncService.shared.checkAccountStatus()
    }

    // MARK: - Persistence

    private func loadStoredCredentials() {
        userID      = KeychainService.load(for: keyUserID)
        displayName = KeychainService.load(for: keyName)
        email       = KeychainService.load(for: keyEmail)
    }
}
