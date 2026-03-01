import SwiftUI

struct OnboardingSlide1: View {
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSub = false
    @State private var showMission = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.5), lineWidth: 2)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.08))
                    .frame(width: 72, height: 72)

                Image(systemName: "flag.checkered")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .scaleEffect(showIcon ? 1 : 0.8)
            .opacity(showIcon ? 1 : 0)

            Spacer().frame(height: 20)

            Text("Welcome, Race Strategist")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.white)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 10)

            Spacer().frame(height: 8)

            Text("You've been hired to predict the podium.\nCan your ML model beat the odds?")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(showSub ? 1 : 0)
                .offset(y: showSub ? 0 : 8)

            Spacer().frame(height: 36)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                MissionItem(
                    icon: "cpu",
                    iconColor: Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255),
                    title: "Pick a Model",
                    subtitle: "6 algorithms, each thinks differently",
                    show: showMission,
                    delay: 0
                )
                MissionItem(
                    icon: "chart.bar.doc.horizontal",
                    iconColor: Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255),
                    title: "Feed it Data",
                    subtitle: "Tune driver stats, shape predictions",
                    show: showMission,
                    delay: 0.08
                )
                MissionItem(
                    icon: "flag.checkered.2.crossed",
                    iconColor: Color(red: 255 / 255, green: 183 / 255, blue: 0 / 255),
                    title: "Predict & Race",
                    subtitle: "Lock in, watch the race unfold",
                    show: showMission,
                    delay: 0.16
                )
                MissionItem(
                    icon: "magnifyingglass",
                    iconColor: Color(red: 78 / 255, green: 205 / 255, blue: 196 / 255),
                    title: "Learn Why",
                    subtitle: "See how models think & fail",
                    show: showMission,
                    delay: 0.24
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 12))
                Text("Swipe to continue")
                    .font(.system(size: 12))
            }
            .foregroundColor(Color(white: 0.3))
            .opacity(showMission ? 1 : 0)
            .animation(.easeIn(duration: 0.5).delay(1.0), value: showMission)

            Spacer().frame(height: 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showIcon = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                showSub = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.35)) {
                showMission = true
            }
        }
    }
}

struct MissionItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let show: Bool
    let delay: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .opacity(show ? 1 : 0)
        .offset(y: show ? 0 : 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: show)
    }
}
