import SwiftUI
import TipKit

@main
struct MyApp: App {
    init() {
        Task { @MainActor in
            try? Tips.configure([.displayFrequency(.immediate)])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
