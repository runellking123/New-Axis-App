import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension entry point. Accepts plain text and URLs from any
/// app's Share Sheet and forwards them to the main Axis app via the
/// `axis://reminder?title=...` URL handler. The main app's
/// QuickAddParser then converts natural-language tokens
/// ("tomorrow 5pm p1 #work") into structured fields.
final class ShareViewController: SLComposeServiceViewController {
    private var sharedURL: URL?

    override func isContentValid() -> Bool {
        // Allow empty body if a URL was shared (URL alone is enough to
        // make a reminder).
        let hasText = !(contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || sharedURL != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add to Axis"
        placeholder = "Reminder title — try \"tomorrow 5pm p1 #work\""
        extractSharedURL()
    }

    override func didSelectPost() {
        let userText = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let combined: String
        if let url = sharedURL {
            combined = userText.isEmpty ? url.absoluteString : "\(userText) — \(url.absoluteString)"
        } else {
            combined = userText
        }
        openMainAppWithReminder(title: combined)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    // MARK: - Helpers

    private func extractSharedURL() {
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let providers = item.attachments else { return }
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async { self?.sharedURL = url }
                }
            }
            return
        }
    }

    private func openMainAppWithReminder(title: String) {
        guard var components = URLComponents(string: "axis://reminder") else { return }
        components.queryItems = [URLQueryItem(name: "title", value: title)]
        guard let url = components.url else { return }
        // Share Extensions are sandboxed and can't call UIApplication.shared
        // directly. Walk the responder chain to find a UIApplication-like
        // object that responds to openURL:.
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: NSSelectorFromString("openURL:")) {
                _ = r.perform(NSSelectorFromString("openURL:"), with: url)
                return
            }
            responder = r.next
        }
    }
}
