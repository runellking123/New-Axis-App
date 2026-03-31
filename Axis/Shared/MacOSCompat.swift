#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Stub types for iOS-only SwiftUI modifiers

enum MacNavBarTitleDisplayMode {
    case automatic, inline, large
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: MacNavBarTitleDisplayMode) -> some View {
        self
    }

    func statusBarHidden(_ hidden: Bool = true) -> some View {
        self
    }
}

// MARK: - Toolbar placement aliases

extension ToolbarItemPlacement {
    static var navigationBarTrailing: ToolbarItemPlacement { .automatic }
    static var navigationBarLeading: ToolbarItemPlacement { .automatic }
    static var topBarLeading: ToolbarItemPlacement { .automatic }
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
}

// MARK: - Keyboard type stub

enum MacKeyboardType { case `default`, decimalPad, numberPad, phonePad, emailAddress, URL }

extension View {
    func keyboardType(_ type: MacKeyboardType) -> some View {
        self
    }

    func textInputAutocapitalization(_ style: MacTextAutocap?) -> some View {
        self
    }
}

enum MacTextAutocap { case never, words, sentences, characters }

// MARK: - Presentation stubs (iOS-only sheet modifiers not available on macOS)

// MARK: - List style stub

extension ListStyle where Self == InsetListStyle {
    static var insetGrouped: InsetListStyle { .init() }
}

// MARK: - NSColor aliases for iOS UIColor names used throughout the app

extension NSColor {
    static var systemGroupedBackground: NSColor {
        .windowBackgroundColor
    }
    static var secondarySystemGroupedBackground: NSColor {
        .controlBackgroundColor
    }
    static var systemBackground: NSColor {
        .windowBackgroundColor
    }
    static var secondarySystemBackground: NSColor {
        .controlBackgroundColor
    }
    static var systemGray5: NSColor {
        .separatorColor
    }
    static var systemGray6: NSColor {
        NSColor(white: 0.95, alpha: 1.0)
    }
    static var tertiarySystemGroupedBackground: NSColor {
        .textBackgroundColor
    }
    static var systemGray4: NSColor {
        .tertiaryLabelColor
    }
    static var label: NSColor {
        .labelColor
    }
    static var secondaryLabel: NSColor {
        .secondaryLabelColor
    }
}
#endif
