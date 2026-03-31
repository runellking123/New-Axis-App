#if os(iOS)
import UIKit

enum HapticService {
    private static var isEnabled = true

    static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Warm haptic pattern for "Dad Win" moments and completions
    static func celebration() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.impactOccurred()
        }
    }

    /// Mode switch feedback
    static func modeSwitch() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.8)
    }
}
#else
// macOS stub — no haptic feedback
enum HapticService {
    enum FeedbackStyle { case light, medium, heavy, rigid, soft }
    enum FeedbackType { case success, warning, error }
    static func setEnabled(_ enabled: Bool) {}
    static func impact(_ style: FeedbackStyle = .medium) {}
    static func notification(_ type: FeedbackType) {}
    static func selection() {}
    static func celebration() {}
    static func modeSwitch() {}
}
#endif
