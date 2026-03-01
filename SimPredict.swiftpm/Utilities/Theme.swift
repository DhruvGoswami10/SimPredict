import SwiftUI

// MARK: - App Colors

enum AppColor {
    static let racingRed = Color(red: 0.86, green: 0.0, blue: 0.0)
    static let darkRed = Color(red: 0.65, green: 0.0, blue: 0.0)
    static let gold = Color(red: 1.0, green: 0.85, blue: 0.0)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let green = Color(red: 0.0, green: 0.9, blue: 0.2)
    static let darkGreen = Color(red: 0.0, green: 0.7, blue: 0.15)

    static let backgroundDark = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let backgroundDarker = Color(red: 0.02, green: 0.02, blue: 0.02)
    static let backgroundMid = Color(red: 0.05, green: 0.05, blue: 0.05)

    static let cardBackground = Color.white.opacity(0.08)
    static let cardBackgroundSelected = Color.white.opacity(0.2)
    static let cardBorder = Color.white.opacity(0.12)

    static let redGradient = LinearGradient(
        colors: [racingRed, darkRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - App Font

enum AppFont {
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Avenir Next", size: size).weight(weight)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.custom(15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(AppColor.redGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppColor.racingRed.opacity(0.4), radius: 8, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.custom(13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Background View

struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColor.backgroundDark, AppColor.backgroundDarker, AppColor.backgroundMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [AppColor.racingRed.opacity(0.3), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )

            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.02))
                        .frame(width: 120, height: geometry.size.height * 1.5)
                        .rotationEffect(.degrees(25))
                        .offset(x: CGFloat(index) * 180 - 200, y: -100)
                }
            }

            LinearGradient(
                colors: [Color.clear, AppColor.racingRed.opacity(0.15)],
                startPoint: .center,
                endPoint: .bottom
            )
            .offset(y: 100)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(AppFont.custom(18, weight: .bold))
            .foregroundColor(.white)
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColor.cardBackground)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
