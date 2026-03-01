import SwiftUI

struct WelcomeFlowView: View {
    var onEnterLab: () -> Void

    @State private var phase: WelcomePhase = .lightsOut
    @State private var currentPage: Int = 0

    enum WelcomePhase {
        case lightsOut
        case onboarding
    }

    private let bgDark = Color(red: 5 / 255, green: 3 / 255, blue: 3 / 255)
    private let bgGlow = Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255)

    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()

            RadialGradient(
                colors: [bgGlow.opacity(0.06), .clear],
                center: .init(x: 0.2, y: 0.8),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [bgGlow.opacity(0.04), .clear],
                center: .init(x: 0.8, y: 0.2),
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            EmberBackgroundView(particleCount: 18)

            switch phase {
            case .lightsOut:
                LightsOutView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        phase = .onboarding
                    }
                }
                .transition(.opacity)
            case .onboarding:
                onboardingPages
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var onboardingPages: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                OnboardingSlide1()
                    .tag(0)

                OnboardingSlide2(onEnterLab: onEnterLab)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                }
            }
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    WelcomeFlowView(onEnterLab: {})
}
