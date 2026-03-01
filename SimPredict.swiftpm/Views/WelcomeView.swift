import SwiftUI
import TipKit

struct WelcomeView: View {
    var onStart: () -> Void
    @State private var currentPage = 0
    @State private var trackDrawProgress: CGFloat = 0
    @State private var showCards = false

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            missionPage.tag(1)
            modelsPage.tag(2)
            readyPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0)) {
                trackDrawProgress = 1.0
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated track outline
            ZStack {
                Circle()
                    .trim(from: 0, to: trackDrawProgress)
                    .stroke(
                        AppColor.racingRed.opacity(0.4),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "flag.checkered")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .opacity(trackDrawProgress)
            }

            VStack(spacing: 12) {
                Text("Welcome, Race Strategist")
                    .font(AppFont.custom(32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("You've been hired to predict the podium.\nCan your ML model beat the odds?")
                    .font(AppFont.custom(17))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 14))
                Text("Swipe to continue")
                    .font(AppFont.custom(14))
            }
            .foregroundColor(.white.opacity(0.5))
            .padding(.bottom, 20)
        }
    }

    // MARK: - Page 2: Your Mission

    private var missionPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Your Mission")
                .font(AppFont.custom(28, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 20) {
                MissionStep(
                    icon: "cpu",
                    title: "Pick an ML Model",
                    description: "Choose from 6 algorithms, each with different strengths."
                )
                MissionStep(
                    icon: "slider.horizontal.3",
                    title: "Feed it Data",
                    description: "Tune driver stats. Your data shapes the prediction."
                )
                MissionStep(
                    icon: "flag.checkered",
                    title: "Predict & Race",
                    description: "Lock in your prediction, then watch the race unfold."
                )
                MissionStep(
                    icon: "chart.bar.fill",
                    title: "Learn Why",
                    description: "See how models think and why predictions succeed or fail."
                )
            }
            .padding(.horizontal, 8)

            Spacer()
        }
    }

    // MARK: - Page 3: The Models

    private var modelsPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Six ML Models")
                .font(AppFont.custom(28, weight: .bold))
                .foregroundColor(.white)

            Text("Each thinks differently about the same data")
                .font(AppFont.custom(15))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(ModelType.allCases) { model in
                    HStack(spacing: 10) {
                        Image(systemName: model.icon)
                            .font(.system(size: 18))
                            .foregroundColor(model.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.shortName)
                                .font(AppFont.custom(14, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showCards = true
            }
        }
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(AppColor.gold)

            VStack(spacing: 12) {
                Text("Ready to Predict?")
                    .font(AppFont.custom(28, weight: .bold))
                    .foregroundColor(.white)

                Text("Step into the Strategy Lab and\nbuild your first prediction.")
                    .font(AppFont.custom(16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                HapticsManager.shared.buttonPress()
                onStart()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                    Text("Enter the Lab")
                        .font(AppFont.custom(18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.redGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppColor.racingRed.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Mission Step

private struct MissionStep: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColor.racingRed.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColor.racingRed)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.custom(16, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(AppFont.custom(14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
