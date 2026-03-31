import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum PlatformServices {
    /// Share items using the platform's native sharing UI
    static func share(items: [Any]) {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            var top = vc
            while let p = top.presentedViewController { top = p }
            let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
            top.present(av, animated: true)
        }
        #elseif os(macOS)
        guard let window = NSApplication.shared.keyWindow,
              let contentView = window.contentView else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        #endif
    }

    /// Open a URL using the platform's default handler
    static func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Copy a string to the system clipboard
    static func copyToClipboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    /// Read a string from the system clipboard
    static func pasteFromClipboard() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }

    /// Dismiss the keyboard (iOS only, no-op on macOS)
    static func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
