import SwiftUI

struct EmberParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let wobbleAmplitude: CGFloat
    let wobbleSpeed: CGFloat
    let phase: CGFloat
    let maxOpacity: CGFloat
    let color: Color
    var age: CGFloat = 0
    let lifetime: CGFloat

    static func random() -> EmberParticle {
        let colors: [Color] = [
            Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255),
            Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255),
            Color(red: 255 / 255, green: 183 / 255, blue: 0 / 255)
        ]
        return EmberParticle(
            x: .random(in: 0.02...0.98),
            y: 1.05,
            size: .random(in: 1.5...3.5),
            speed: .random(in: 0.04...0.1),
            wobbleAmplitude: .random(in: 0.005...0.02),
            wobbleSpeed: .random(in: 0.8...2.0),
            phase: .random(in: 0...(2 * .pi)),
            maxOpacity: .random(in: 0.25...0.6),
            color: colors.randomElement() ?? .orange,
            lifetime: .random(in: 8...14)
        )
    }

    static func randomScattered() -> EmberParticle {
        var particle = EmberParticle.random()
        particle.age = .random(in: 0...particle.lifetime)
        particle.y = 1.0 - (particle.age / particle.lifetime)
        return particle
    }
}

struct EmberBackgroundView: View {
    let particleCount: Int

    @State private var particles: [EmberParticle] = []
    @State private var lastUpdate: Date = .now

    init(particleCount: Int = 18) {
        self.particleCount = particleCount
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let time = now.timeIntervalSinceReferenceDate
                let dt = CGFloat(now.timeIntervalSince(lastUpdate))

                // Keep state updates outside the draw pipeline.
                DispatchQueue.main.async {
                    lastUpdate = now
                    updateParticles(dt: min(dt, 0.1))
                }

                for particle in particles {
                    let px = particle.x * size.width
                    let py = particle.y * size.height
                    let lifeRatio = particle.age / particle.lifetime
                    let opacity = sin(lifeRatio * .pi) * particle.maxOpacity
                    guard opacity > 0.01 else { continue }

                    let wobbleX = sin(time * Double(particle.wobbleSpeed) + Double(particle.phase))
                        * Double(particle.wobbleAmplitude * size.width)
                    let drawX = px + wobbleX

                    let glowRect = CGRect(
                        x: drawX - particle.size * 3,
                        y: py - particle.size * 3,
                        width: particle.size * 6,
                        height: particle.size * 6
                    )
                    var glowContext = context
                    glowContext.opacity = opacity * 0.12
                    glowContext.fill(Circle().path(in: glowRect), with: .color(particle.color))

                    let coreRect = CGRect(
                        x: drawX - particle.size * 0.5,
                        y: py - particle.size * 0.5,
                        width: particle.size,
                        height: particle.size
                    )
                    var coreContext = context
                    coreContext.opacity = opacity
                    coreContext.fill(Circle().path(in: coreRect), with: .color(particle.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<particleCount).map { _ in EmberParticle.randomScattered() }
        }
    }

    private func updateParticles(dt: CGFloat) {
        guard !particles.isEmpty else { return }

        for index in particles.indices {
            particles[index].age += dt
            particles[index].y -= particles[index].speed * dt

            if particles[index].age >= particles[index].lifetime || particles[index].y < -0.05 {
                particles[index] = .random()
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 3:
            (r, g, b, a) = (
                ((value >> 8) & 0xF) * 17,
                ((value >> 4) & 0xF) * 17,
                (value & 0xF) * 17,
                255
            )
        case 6:
            (r, g, b, a) = (
                (value >> 16) & 0xFF,
                (value >> 8) & 0xFF,
                value & 0xFF,
                255
            )
        case 8:
            (r, g, b, a) = (
                (value >> 24) & 0xFF,
                (value >> 16) & 0xFF,
                (value >> 8) & 0xFF,
                value & 0xFF
            )
        default:
            (r, g, b, a) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
