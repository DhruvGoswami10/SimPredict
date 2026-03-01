import SwiftUI

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var accuracyPercent: Int = 0

    func calculateAccuracy(predicted: [Driver], actual: [Driver]) {
        guard predicted.count >= 3 && actual.count >= 3 else { accuracyPercent = 0; return }
        var points = 0
        if predicted[0].id == actual[0].id { points += 3 }
        if predicted[1].id == actual[1].id { points += 2 }
        if predicted[2].id == actual[2].id { points += 1 }
        accuracyPercent = Int(round(Double(points) / 6.0 * 100))
    }

    func accuracyInterpretation() -> String {
        switch accuracyPercent {
        case 80...100:
            return "Excellent! Your model captured the key performance indicators. The features you used had strong predictive power for this race."
        case 50..<80:
            return "Moderate accuracy. Some features were predictive, but unexpected race events or missing data affected the outcome."
        case 17..<50:
            return "Low accuracy. Race events (DNFs, strategy) weren't in the data, noise confused the model, or qualifying didn't predict race pace."
        case 1..<17:
            return "Tough result. Models can't predict what they haven't seen in training data. Race-day events matter more than historical stats."
        default:
            return "No matches. Real-world racing has high variance — one small incident changes everything. This is why ML needs lots of data."
        }
    }

    func whySummary(predictedTop3: [Driver], actualTop3: [Driver], raceCars: [RaceCar]) -> String {
        guard !actualTop3.isEmpty else { return "Run a race to see the analysis." }
        let dnfNames = raceCars.filter { $0.didDNF }.map { $0.name }
        if !dnfNames.isEmpty {
            return "DNFs changed the outcome: \(dnfNames.joined(separator: ", ")). Models can't predict mechanical failures — this is a key limitation of data-driven predictions."
        }
        let predictedWins = predictedTop3.map { $0.wins }.reduce(0, +)
        let actualWins = actualTop3.map { $0.wins }.reduce(0, +)
        let predictedTrackWins = predictedTop3.map { $0.trackWins }.reduce(0, +)
        let actualTrackWins = actualTop3.map { $0.trackWins }.reduce(0, +)
        if actualTrackWins > predictedTrackWins {
            return "Track-specific experience mattered more than expected — drivers with stronger history here outperformed."
        }
        if actualWins > predictedWins {
            return "Overall race craft dominated — consistent pace beat qualifying advantage."
        }
        return "Clean race with minimal disruption — the data was a strong predictor this time."
    }

    func getAllModelScores(modelPredictions: [ModelType: [Driver]], actual: [Driver]) -> [(ModelType, Int)] {
        guard !actual.isEmpty else { return [] }
        return ModelType.allCases.map { model in
            guard let prediction = modelPredictions[model] else { return (model, 0) }
            return (model, scoreModel(prediction: prediction, actual: actual))
        }.sorted { $0.1 > $1.1 }
    }

    func modelsConverged(modelPredictions: [ModelType: [Driver]]) -> Bool {
        guard modelPredictions.count == ModelType.allCases.count else { return false }
        let allPredictions = ModelType.allCases.compactMap { modelPredictions[$0] }
        guard !allPredictions.isEmpty else { return false }
        let firstSet = Set(allPredictions[0].map { $0.id })
        return allPredictions.allSatisfy { Set($0.map { $0.id }) == firstSet }
    }

    func convergenceExplanation(modelPredictions: [ModelType: [Driver]]) -> String {
        if modelsConverged(modelPredictions: modelPredictions) {
            return "All 6 models predicted the same top-3. Strong, clear signal in your data. When different algorithms agree, confidence is high."
        } else {
            return "Models predicted different results. Mixed signals or complexity in the data. In real ML, disagreement means you need more data or better features."
        }
    }

    func compareModelsSummary(modelPredictions: [ModelType: [Driver]], actual: [Driver]) -> String {
        guard !actual.isEmpty else { return "Run a race to compare model behavior." }
        var bestModel: ModelType?
        var bestScore = -1
        for model in ModelType.allCases {
            guard let prediction = modelPredictions[model] else { continue }
            let score = scoreModel(prediction: prediction, actual: actual)
            if score > bestScore {
                bestScore = score
                bestModel = model
            }
        }
        if let bestModel {
            return "Closest this round: \(bestModel.rawValue) (\(bestScore)/6 points)."
        }
        return "No model comparison available yet."
    }

    func missingDataSummary(noiseColumns: [NoiseColumn]) -> String {
        if noiseColumns.isEmpty {
            return "Clean data — no noise added. Missing factors like tire wear, weather, or pit timing could still shift results. Try adding noise to see accuracy drop."
        }
        let names = noiseColumns.map { $0.type.rawValue }.joined(separator: ", ")
        return "Noise added (\(names)) introduced variance without improving prediction. These columns confuse the model — a classic overfitting scenario."
    }

    private func scoreModel(prediction: [Driver], actual: [Driver]) -> Int {
        guard prediction.count >= 3 && actual.count >= 3 else { return 0 }
        var points = 0
        if prediction[0].id == actual[0].id { points += 3 }
        if prediction[1].id == actual[1].id { points += 2 }
        if prediction[2].id == actual[2].id { points += 1 }
        return points
    }
}
