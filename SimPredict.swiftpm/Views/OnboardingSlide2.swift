import SwiftUI

struct OnboardingSlide2: View {
    let onEnterLab: () -> Void

    @State private var showContent = false

    private let models: [(icon: String, name: String, color: Color)] = [
        ("chart.line.uptrend.xyaxis", "Linear", Color(red: 255 / 255, green: 183 / 255, blue: 0 / 255)),
        ("leaf", "Tree", Color(red: 78 / 255, green: 205 / 255, blue: 196 / 255)),
        ("tree", "Forest", Color(red: 59 / 255, green: 157 / 255, blue: 221 / 255)),
        ("antenna.radiowaves.left.and.right", "KNN", Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255)),
        ("chart.bar.fill", "Bayes", Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255)),
        ("brain", "Neural", Color(red: 196 / 255, green: 125 / 255, blue: 255 / 255))
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Six ML Models")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

            Spacer().frame(height: 6)

            Text("Each thinks differently about the same data")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

            Spacer().frame(height: 32)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { index in
                        modelChip(models[index], delay: Double(index) * 0.06)
                    }
                }
                HStack(spacing: 10) {
                    ForEach(3..<6, id: \.self) { index in
                        modelChip(models[index], delay: Double(index) * 0.06)
                    }
                }
            }
            .padding(.horizontal, 60)

            Spacer().frame(height: 48)

            Button(action: onEnterLab) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                    Text("Enter the Lab")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 400)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255))
                        .shadow(color: Color(red: 230 / 255, green: 57 / 255, blue: 70 / 255).opacity(0.3), radius: 12, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 60)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: showContent)

            Spacer()
            Spacer().frame(height: 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    @ViewBuilder
    private func modelChip(_ model: (icon: String, name: String, color: Color), delay: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: model.icon)
                .font(.system(size: 14))
                .foregroundColor(model.color)

            Text(model.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(model.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2 + delay), value: showContent)
    }
}
