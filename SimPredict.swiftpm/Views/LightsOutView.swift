import SwiftUI

struct LightsOutView: View {
    let onComplete: () -> Void

    @State private var litCount: Int = 0
    @State private var lightsOut: Bool = false
    @State private var showHousing: Bool = false
    @State private var titleVisible: Bool = false
    @State private var subtitleVisible: Bool = false
    @State private var fadeOutTitle: Bool = false
    @State private var fadeOutHousing: Bool = false

    @State private var dataPoints: [DataPoint] = []
    @State private var dataConverged: Bool = false
    @State private var dataFaded: Bool = false

    struct DataPoint: Identifiable {
        let id = UUID()
        let scatterX: CGFloat
        let scatterY: CGFloat
        let convergeX: CGFloat
        let convergeY: CGFloat
        let size: CGFloat
        let color: Color
        let revealAt: Int
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(dataPoints) { point in
                    Circle()
                        .fill(point.color)
                        .frame(width: point.size, height: point.size)
                        .shadow(color: point.color.opacity(0.4), radius: point.size)
                        .position(
                            x: dataConverged ? point.convergeX : point.scatterX,
                            y: dataConverged ? point.convergeY : point.scatterY
                        )
                        .opacity(dataFaded ? 0 : (litCount >= point.revealAt ? Double(point.revealAt) * 0.12 : 0))
                        .animation(.easeInOut(duration: dataConverged ? 0.45 : 0.3), value: dataConverged)
                        .animation(.easeInOut(duration: 0.25), value: dataFaded)
                        .animation(.easeIn(duration: 0.3), value: litCount)
                }

                RadialGradient(
                    colors: [Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.15), .clear],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.55
                )
                .opacity(lightsOut ? 0 : Double(litCount) / 5.0)
                .animation(.easeInOut(duration: 0.15), value: lightsOut)

                if showHousing {
                    HStack(spacing: 18) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(lightColor(for: index))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(lightBorder(for: index), lineWidth: 2))
                                .shadow(
                                    color: index < litCount && !lightsOut
                                        ? Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.8)
                                        : .clear,
                                    radius: index < litCount && !lightsOut ? 16 : 0
                                )
                                .shadow(
                                    color: index < litCount && !lightsOut
                                        ? Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.4)
                                        : .clear,
                                    radius: index < litCount && !lightsOut ? 40 : 0
                                )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(white: 0.06).opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .opacity(fadeOutHousing ? 0 : 1)
                    .offset(y: fadeOutHousing ? -20 : 0)
                    .transition(.opacity.combined(with: .offset(y: -10)))
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                }

                VStack(spacing: 8) {
                    Text("SimPredict")
                        .font(.system(size: 58, weight: .heavy))
                        .tracking(-2)
                        .foregroundColor(.white)
                        .opacity(titleVisible && !fadeOutTitle ? 1 : 0)
                        .scaleEffect(titleVisible ? (fadeOutTitle ? 1.05 : 1.0) : 0.7)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: titleVisible)
                        .animation(.easeOut(duration: 0.35), value: fadeOutTitle)

                    Text("Learn Machine Learning by Racing")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.gray)
                        .opacity(subtitleVisible && !fadeOutTitle ? 1 : 0)
                        .offset(y: subtitleVisible ? 0 : 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: subtitleVisible)
                        .animation(.easeOut(duration: 0.3), value: fadeOutTitle)
                }
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            }
            .onAppear {
                generateDataPoints(in: geo.size)
                startSequence()
            }
        }
    }

    private func lightColor(for index: Int) -> Color {
        if lightsOut {
            return Color(white: 0.07)
        }
        return index < litCount
            ? Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255)
            : Color(white: 0.07)
    }

    private func lightBorder(for index: Int) -> Color {
        if lightsOut {
            return Color(white: 0.1)
        }
        return index < litCount
            ? Color(red: 1, green: 0.28, blue: 0.34)
            : Color(white: 0.1)
    }

    private func generateDataPoints(in size: CGSize) {
        let colors: [Color] = [
            Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255),
            Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255),
            Color(red: 255 / 255, green: 183 / 255, blue: 0 / 255),
            Color(red: 78 / 255, green: 205 / 255, blue: 196 / 255)
        ]

        dataPoints = (0..<35).map { _ in
            DataPoint(
                scatterX: CGFloat.random(in: size.width * 0.1...size.width * 0.9),
                scatterY: CGFloat.random(in: size.height * 0.15...size.height * 0.85),
                convergeX: size.width / 2 + CGFloat.random(in: -50...50),
                convergeY: size.height * 0.48 + CGFloat.random(in: -15...15),
                size: CGFloat.random(in: 2...5),
                color: colors.randomElement() ?? .orange,
                revealAt: Int.random(in: 1...5)
            )
        }
    }

    private func startSequence() {
        withAnimation(.easeOut(duration: 0.3)) {
            showHousing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.05)) { litCount = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.05)) { litCount = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.05)) { litCount = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.05)) { litCount = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.05)) { litCount = 5 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.06)) { lightsOut = true }
            withAnimation(.easeOut(duration: 0.4)) { fadeOutHousing = true }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { dataConverged = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.25)) { dataFaded = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            titleVisible = true
            subtitleVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            fadeOutTitle = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            onComplete()
        }
    }
}
