import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .welcome
    @Published var isTransitioning: Bool = false

    func goTo(_ newPhase: AppPhase) {
        HapticsManager.shared.phaseTransition()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isTransitioning = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
            phase = newPhase
            isTransitioning = false
        }
    }
}
