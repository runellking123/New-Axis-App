import SwiftUI

// MARK: - Confetti trigger
// Fires a confetti burst whenever the trigger value changes. Drive it with a
// milestone Bool (streak hit, goal complete) or a counter.

private struct AxisConfettiModifier<T: Equatable>: ViewModifier {
    let trigger: T
    @State private var bursts: [UUID] = []

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    ForEach(bursts, id: \.self) { id in
                        ConfettiView().id(id)
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, _ in
                let id = UUID()
                bursts.append(id)
                HapticService.celebration()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    bursts.removeAll { $0 == id }
                }
            }
    }
}

// MARK: - Staggered appear
// Fade + slide-up entrance. Give sequential views increasing delays for a
// cascading reveal.

private struct AxisAppearModifier: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Pressable
// Scale-down + selection haptic on press. Use for tappable cards that aren't
// already using one of the AxisTheme button styles.

struct AxisPressableStyle: ButtonStyle {
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic { HapticService.selection() }
            }
    }
}

extension ButtonStyle where Self == AxisPressableStyle {
    static var axisPressable: AxisPressableStyle { AxisPressableStyle() }
}

// MARK: - View helpers

extension View {
    /// Fires a confetti burst (and celebration haptic) when `trigger` changes.
    func axisConfetti<T: Equatable>(trigger: T) -> some View {
        modifier(AxisConfettiModifier(trigger: trigger))
    }

    /// Fade + slide-up entrance animation. Stagger with increasing `delay`.
    func axisAppear(delay: Double = 0) -> some View {
        modifier(AxisAppearModifier(delay: delay))
    }
}

// MARK: - Transition presets

extension AnyTransition {
    /// Slide up from below while fading in.
    static var axisSlideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Pop in with a slight scale.
    static var axisPop: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }
}
