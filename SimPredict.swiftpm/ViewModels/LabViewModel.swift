import SwiftUI

private struct CustomWeightedModel: MLModel {
    let type: ModelType = .linearRegression
    private var weights: [Double]
    private var maxDrivers: Int = 10
    private let names = ["Qualifying", "Wins", "Track Wins", "DNFs"]

    init(weights: [Double]) {
        var normalized = Array(weights.prefix(4))
        if normalized.count < 4 {
            normalized.append(contentsOf: Array(repeating: 0, count: 4 - normalized.count))
        }
        self.weights = normalized
    }

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        maxDrivers = max(1, drivers.count)
    }

    func predict(driver: Driver) -> Double {
        let q = Double(maxDrivers + 1 - driver.qualifying)
        let values = [q, Double(driver.wins), Double(driver.trackWins), Double(driver.dnfs)]
        return zip(values, weights).map(*).reduce(0, +)
    }

    func featureImportances() -> [(String, Double)] {
        zip(names, weights).map { ($0, $1) }
    }

    func explanation(for driver: Driver) -> String {
        let q = Double(maxDrivers + 1 - driver.qualifying)
        let values = [q, Double(driver.wins), Double(driver.trackWins), Double(driver.dnfs)]
        let score = predict(driver: driver)
        var parts: [String] = []
        for index in 0..<names.count {
            parts.append(String(format: "%@(%.1f) x %.2f", names[index], values[index], weights[index]))
        }
        return String(format: "Score: %.2f\n%@", score, parts.joined(separator: " + "))
    }
}

@MainActor
final class LabViewModel: ObservableObject {
    @Published var currentStep: LabStep = .modelSelection
    @Published var selectedModel: ModelType? = nil
    @Published var knnK: Int = 3
    @Published var drivers: [Driver] = []
    @Published var noiseColumns: [NoiseColumn] = []
    @Published var selectedTrack: TrackInfo = .monza
    @Published var predictedTop3: [Driver] = []
    @Published var modelPredictions: [ModelType: [Driver]] = [:]
    @Published var showModelVisualization: Bool = false

    // Live preview of predictions (updates as user changes data)
    @Published var livePreviewTop3: [Driver] = []

    let maxNoiseColumns = 5
    let minDrivers = 5
    let maxDrivers = 20

    // Trained model instance for current selection
    var trainedModel: (any MLModel)?

    // All trained models for comparison
    var allTrainedModels: [ModelType: any MLModel] = [:]

    init() {
        drivers = Driver.defaultDrivers()
    }

    // MARK: - Step Navigation

    func nextStep() {
        guard let nextIndex = LabStep(rawValue: currentStep.rawValue + 1) else { return }
        HapticsManager.shared.stepChange()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextIndex
        }
    }

    func previousStep() {
        guard let prevIndex = LabStep(rawValue: currentStep.rawValue - 1) else { return }
        HapticsManager.shared.stepChange()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = prevIndex
        }
    }

    func goToStep(_ step: LabStep) {
        guard step.rawValue <= currentStep.rawValue + 1 else { return }
        HapticsManager.shared.stepChange()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
    }

    // MARK: - Model Selection

    func selectModel(_ model: ModelType) {
        HapticsManager.shared.modelSelect()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            if selectedModel == model {
                showModelVisualization.toggle()
            } else {
                selectedModel = model
                showModelVisualization = true
            }
        }
        updateLivePreview()
    }

    // MARK: - Driver Management

    func addDriver() {
        guard drivers.count < maxDrivers else { return }
        let usedNames = Set(drivers.map { $0.name })
        guard let next = Driver.driverPool.first(where: { !usedNames.contains($0.0) }) else { return }

        let newDriver = Driver(
            id: UUID(),
            name: next.0,
            team: next.1,
            color: next.2,
            qualifying: drivers.count + 1,
            wins: Int.random(in: 5...35),
            trackWins: Int.random(in: 0...5),
            dnfs: Int.random(in: 0...4)
        )
        drivers.append(newDriver)

        for index in noiseColumns.indices {
            noiseColumns[index].driverValues[newDriver.id] = noiseColumns[index].type.randomValue()
        }
        updateLivePreview()
    }

    func removeDriver(id: UUID) {
        guard drivers.count > minDrivers else {
            HapticsManager.shared.error()
            return
        }
        drivers.removeAll { $0.id == id }
        for index in noiseColumns.indices {
            noiseColumns[index].driverValues.removeValue(forKey: id)
        }
        updateLivePreview()
    }

    func addAllDrivers() {
        while drivers.count < min(maxDrivers, Driver.driverPool.count) {
            addDriver()
        }
    }

    func shuffleQualifying() {
        let positions = Array(1...drivers.count).shuffled()
        for index in drivers.indices {
            drivers[index].qualifying = positions[index]
        }
        updateLivePreview()
    }

    func resetToDefaults() {
        drivers = Driver.defaultDrivers()
        noiseColumns = []
        predictedTop3 = []
        modelPredictions = [:]
        livePreviewTop3 = []
        knnK = 3
        updateLivePreview()
    }

    func randomizeAllStats() {
        for index in drivers.indices {
            drivers[index].qualifying = Int.random(in: 1...drivers.count)
            drivers[index].wins = Int.random(in: 0...55)
            drivers[index].trackWins = Int.random(in: 0...8)
            drivers[index].dnfs = Int.random(in: 0...12)
        }
        updateLivePreview()
    }

    func flipStats() {
        for index in drivers.indices {
            drivers[index].qualifying = drivers.count + 1 - drivers[index].qualifying
            drivers[index].wins = 60 - drivers[index].wins
            drivers[index].trackWins = 8 - drivers[index].trackWins
            drivers[index].dnfs = 15 - drivers[index].dnfs
        }
        updateLivePreview()
    }

    func addOutlier() {
        guard let index = drivers.indices.randomElement() else { return }
        drivers[index].wins = 58
        drivers[index].trackWins = 8
        drivers[index].qualifying = 1
        drivers[index].dnfs = 0
        updateLivePreview()
    }

    func applyToAll(column: StatColumn, value: Int) {
        for index in drivers.indices {
            switch column {
            case .qualifying:
                drivers[index].qualifying = min(drivers.count, max(1, value))
            case .wins:
                drivers[index].wins = min(60, max(0, value))
            case .trackWins:
                drivers[index].trackWins = min(8, max(0, value))
            case .dnfs:
                drivers[index].dnfs = min(15, max(0, value))
            }
        }
        updateLivePreview()
    }

    // MARK: - Noise Management

    func addNoiseColumn(type: NoiseColumnType) {
        guard noiseColumns.count < maxNoiseColumns else { return }
        var newColumn = NoiseColumn(type: type)
        for driver in drivers {
            newColumn.driverValues[driver.id] = type.randomValue()
        }
        noiseColumns.append(newColumn)
        updateLivePreview()
    }

    func removeNoiseColumn(id: UUID) {
        noiseColumns.removeAll { $0.id == id }
        updateLivePreview()
    }

    // MARK: - Prediction

    func predict() {
        syncKValueBounds()
        guard let modelType = selectedModel else { return }
        guard drivers.count >= minDrivers else {
            predictedTop3 = []
            modelPredictions = [:]
            return
        }

        // Train and predict with selected model
        var model = makeConfiguredModel(type: modelType)
        model.train(drivers: drivers, noiseColumns: noiseColumns, track: selectedTrack)
        trainedModel = model

        let scored = drivers.map { driver -> (Driver, Double) in
            (driver, model.predict(driver: driver))
        }
        predictedTop3 = scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }

        // Train all models for comparison
        var allPredictions: [ModelType: [Driver]] = [:]
        for mt in ModelType.allCases {
            var m = makeConfiguredModel(type: mt)
            m.train(drivers: drivers, noiseColumns: noiseColumns, track: selectedTrack)
            let s = drivers.map { d -> (Driver, Double) in (d, m.predict(driver: d)) }
            allPredictions[mt] = s.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
            allTrainedModels[mt] = m
        }
        modelPredictions = allPredictions

        HapticsManager.shared.predictionReveal()
    }

    func predictWithCustomWeights(_ customWeights: [Double]) {
        guard drivers.count >= minDrivers else {
            predictedTop3 = []
            return
        }

        var customModel = CustomWeightedModel(weights: customWeights)
        customModel.train(drivers: drivers, noiseColumns: noiseColumns, track: selectedTrack)
        trainedModel = customModel

        let scored = drivers.map { driver -> (Driver, Double) in
            (driver, customModel.predict(driver: driver))
        }
        predictedTop3 = scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }

        HapticsManager.shared.predictionReveal()
    }

    func updateLivePreview() {
        syncKValueBounds()
        guard let modelType = selectedModel else {
            livePreviewTop3 = []
            return
        }
        guard drivers.count >= minDrivers else {
            livePreviewTop3 = []
            return
        }
        var model = makeConfiguredModel(type: modelType)
        model.train(drivers: drivers, noiseColumns: noiseColumns, track: selectedTrack)
        let scored = drivers.map { driver -> (Driver, Double) in
            (driver, model.predict(driver: driver))
        }
        livePreviewTop3 = scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }

    private func makeConfiguredModel(type: ModelType) -> any MLModel {
        switch type {
        case .knn:
            var model = KNNModel()
            model.k = clampedKValue
            return model
        default:
            return MLModelFactory.create(type: type)
        }
    }

    private var clampedKValue: Int {
        let maxK = max(1, drivers.count - 1)
        return min(max(knnK, 1), maxK)
    }

    private func syncKValueBounds() {
        let clamped = clampedKValue
        if knnK != clamped {
            knnK = clamped
        }
    }

    // MARK: - Signal vs Noise Meter

    var signalToNoiseRatio: Double {
        let coreFeatures = 4.0
        let totalFeatures = coreFeatures + Double(noiseColumns.count)
        return coreFeatures / totalFeatures
    }
}
