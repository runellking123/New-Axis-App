import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [Color.axisGold, .blue, .green, .orange, .purple, .pink]

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let color: Color
        let size: CGFloat
        let rotation: Double
        let velocity: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.6)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            burst()
        }
    }

    private func burst() {
        let screenWidth = UIScreen.main.bounds.width

        for _ in 0..<40 {
            let particle = ConfettiParticle(
                x: screenWidth / 2 + CGFloat.random(in: -50...50),
                y: -20,
                color: colors.randomElement() ?? Color.axisGold,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 2...6)
            )
            particles.append(particle)
        }

        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].x += CGFloat.random(in: -150...150)
                particles[i].y = UIScreen.main.bounds.height + 50
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            particles.removeAll()
        }
    }
}
