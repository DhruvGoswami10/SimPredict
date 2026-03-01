import SwiftUI
import Charts
import TipKit

struct BuildYourModelView: View {
    @ObservedObject var labVM: LabViewModel
    @ObservedObject var raceVM: RaceViewModel
    @ObservedObject var resultsVM: ResultsViewModel

    var onBack: () -> Void
    var onTestModel: ([Double]) -> Void

    @State private var qualiWeight: Double = 1.0
    @State private var winsWeight: Double = 0.5
    @State private var trackWinsWeight: Double = 1.0
    @State private var dnfsWeight: Double = -0.5
    @State private var showComparison = false

    private let buildTip = BuildModelTip()

    var customWeights: [Double] {
        [qualiWeight, winsWeight, trackWinsWeight, dnfsWeight]
    }

    var customPredictedTop3: [Driver] {
        let scored = labVM.drivers.map { driver -> (Driver, Double) in
            let q = Double(labVM.drivers.count + 1 - driver.qualifying)
            let score = q * qualiWeight + Double(driver.wins) * winsWeight +
                        Double(driver.trackWins) * trackWinsWeight + Double(driver.dnfs) * dnfsWeight
            return (driver, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        HapticsManager.shared.buttonPress()
                        onBack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Results")
                        }
                        .font(AppFont.custom(14, weight: .medium))
                        .foregroundColor(AppColor.racingRed)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Workshop")
                        .font(AppFont.custom(28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Design your own ML model by setting feature weights")
                        .font(AppFont.custom(15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .popoverTip(buildTip)

                // Weight Sliders
                VStack(alignment: .leading, spacing: 16) {
                    Text("Feature Weights")
                        .font(AppFont.custom(16, weight: .bold))
                        .foregroundColor(.white)

                    WeightSlider(label: "Qualifying", icon: "flag", value: $qualiWeight, color: AppColor.racingRed)
                    WeightSlider(label: "Wins", icon: "trophy", value: $winsWeight, color: AppColor.gold)
                    WeightSlider(label: "Track Wins", icon: "mappin.circle", value: $trackWinsWeight, color: AppColor.green)
                    WeightSlider(label: "DNFs", icon: "exclamationmark.triangle", value: $dnfsWeight, color: AppColor.orange)
                }
                .padding(16)
                .glassCard(cornerRadius: 16)

                // Live Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Model's Prediction")
                        .font(AppFont.custom(16, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(Array(customPredictedTop3.enumerated()), id: \.offset) { index, driver in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(AppFont.custom(16, weight: .bold))
                                .foregroundColor(AppColor.gold)
                                .frame(width: 24)
                            Circle().fill(driver.color).frame(width: 12, height: 12)
                            Text(driver.name)
                                .font(AppFont.custom(15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(driver.team)
                                .font(AppFont.custom(12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)

                // Comparison Chart
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showComparison.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Compare with Pre-built Models")
                            .font(AppFont.custom(14, weight: .semibold))
                        Spacer()
                        Image(systemName: showComparison ? "chevron.up" : "chevron.down")
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .glassCard(cornerRadius: 14)
                }
                .buttonStyle(.plain)

                if showComparison {
                    comparisonSection
                }

                // Closest Model
                closestModelCard

                // Test Button
                Button(action: {
                    HapticsManager.shared.buttonPress()
                    // Update predictions with custom model before testing
                    onTestModel(customWeights)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                        Text("Test Your Model")
                            .font(AppFont.custom(16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.redGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppColor.racingRed.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled(raceVM.runCount >= raceVM.maxRunCount)
                .opacity(raceVM.runCount >= raceVM.maxRunCount ? 0.5 : 1)

                if raceVM.runCount >= raceVM.maxRunCount {
                    Text("Maximum race runs reached. Edit data to reset.")
                        .font(AppFont.custom(12))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Custom model score against actual results
            let customScore = scoreModel(prediction: customPredictedTop3, actual: raceVM.actualTop3)
            let allScores = resultsVM.getAllModelScores(modelPredictions: labVM.modelPredictions, actual: raceVM.actualTop3)

            let entries = allScores.map { model, score in
                ComparisonChartEntry(id: model.rawValue, name: model.shortName, score: score, isCustom: false, color: model.accent)
            } + [ComparisonChartEntry(id: "Custom", name: "Yours", score: customScore, isCustom: true, color: AppColor.gold)]

            Chart(entries) { entry in
                BarMark(
                    x: .value("Model", entry.name),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(entry.isCustom ? AppColor.gold : entry.color)
                .cornerRadius(6)
                .annotation(position: .top, spacing: 4) {
                    Text("\(entry.score)/6")
                        .font(AppFont.custom(10, weight: .bold))
                        .foregroundColor(entry.isCustom ? AppColor.gold : .white.opacity(0.7))
                }
            }
            .chartYScale(domain: 0...6)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 200)
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Closest Model

    private var closestModelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Model Analysis")
                .font(AppFont.custom(14, weight: .semibold))
                .foregroundColor(.white)

            // Find closest pre-built model
            let closest = findClosestModel()
            if let (model, distance) = closest {
                HStack(spacing: 8) {
                    Image(systemName: model.icon)
                        .foregroundColor(model.accent)
                    Text("Closest to: **\(model.rawValue)**")
                        .font(AppFont.custom(13))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: "%.0f%% similar", max(0, 100 - distance * 20)))
                        .font(AppFont.custom(12, weight: .bold))
                        .foregroundColor(model.accent)
                }

                // Weight comparison
                let heaviestFeature = ["Qualifying", "Wins", "Track Wins", "DNFs"]
                let weights = customWeights
                if let maxIdx = weights.enumerated().max(by: { abs($0.element) < abs($1.element) })?.offset {
                    Text("You weighted **\(heaviestFeature[maxIdx])** most heavily.")
                        .font(AppFont.custom(12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Helpers

    private func scoreModel(prediction: [Driver], actual: [Driver]) -> Int {
        guard prediction.count >= 3 && actual.count >= 3 else { return 0 }
        var points = 0
        if prediction[0].id == actual[0].id { points += 3 }
        if prediction[1].id == actual[1].id { points += 2 }
        if prediction[2].id == actual[2].id { points += 1 }
        return points
    }

    private func findClosestModel() -> (ModelType, Double)? {
        var closest: (ModelType, Double)?
        var minDist = Double.infinity

        for model in ModelType.allCases {
            guard let trained = labVM.allTrainedModels[model] else { continue }
            let importances = trained.featureImportances()
            let modelWeights = importances.prefix(4).map { $0.1 }
            guard modelWeights.count == 4 else { continue }

            let dist = zip(customWeights, modelWeights).map { ($0 - $1) * ($0 - $1) }.reduce(0, +).squareRoot()
            if dist < minDist {
                minDist = dist
                closest = (model, dist)
            }
        }
        return closest
    }
}

// MARK: - Chart Entry

private struct ComparisonChartEntry: Identifiable {
    let id: String
    let name: String
    let score: Int
    let isCustom: Bool
    let color: Color
}

// MARK: - Weight Slider

private struct WeightSlider: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Text(label)
                    .font(AppFont.custom(14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(AppFont.custom(14, weight: .bold))
                    .foregroundColor(value >= 0 ? AppColor.green : AppColor.racingRed)
                    .frame(width: 40, alignment: .trailing)
            }

            Slider(value: $value, in: -2...2, step: 0.1)
                .tint(color)
                .onChange(of: value) { _, _ in
                    HapticsManager.shared.sliderChange()
                }
        }
    }
}
