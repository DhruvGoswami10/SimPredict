import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private let isEnabled: Bool

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        #if targetEnvironment(macCatalyst)
        isEnabled = false
        #else
        isEnabled = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
        #endif
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    func buttonPress() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func sliderChange() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    func phaseTransition() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
    }

    func countdown() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    func raceStart() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
    }

    func overtake() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func dnf() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    func raceFinish() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func predictionReveal() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    func modelSelect() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    func stepChange() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }
}
