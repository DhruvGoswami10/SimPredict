import SwiftUI
import Charts

struct ResultsView: View {
    @ObservedObject var labVM: LabViewModel
    @ObservedObject var raceVM: RaceViewModel
    @ObservedObject var resultsVM: ResultsViewModel

    var onRunAgain: () -> Void
    var onEditData: () -> Void
    var onBuildModel: () -> Void

    @State private var showTransparency = false
    @State private var showWhy = false
    @State private var showCompare = false
    @State private var showNoise = false
    @State private var cardAppeared = [false, false, false, false, false]
    @State private var selectedClassroomScenario: ClassroomScenario = .cleanData
    @State private var selectedCoachTopic: StrategyCoachTopic = .whyResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Race Results")
                    .font(AppFont.custom(30, weight: .bold))
                    .foregroundColor(.white)

                resultsPrimerCard
                resultsContextCard

                // Accuracy Gauge
                accuracyGauge
                    .opacity(cardAppeared[0] ? 1 : 0)
                    .offset(y: cardAppeared[0] ? 0 : 20)

                // Predicted vs Actual
                if !raceVM.actualTop3.isEmpty {
                    comparisonSection
                        .opacity(cardAppeared[1] ? 1 : 0)
                        .offset(y: cardAppeared[1] ? 0 : 20)
                }

                // Detailed Prediction Breakdown
                if !raceVM.actualTop3.isEmpty {
                    predictionBreakdown
                        .opacity(cardAppeared[1] ? 1 : 0)
                        .offset(y: cardAppeared[1] ? 0 : 20)
                }

                if !raceVM.actualTop3.isEmpty {
                    positionErrorTable
                        .opacity(cardAppeared[2] ? 1 : 0)
                        .offset(y: cardAppeared[2] ? 0 : 20)
                }

                if !raceVM.actualTop3.isEmpty {
                    pitWallClassroomCard
                        .opacity(cardAppeared[2] ? 1 : 0)
                        .offset(y: cardAppeared[2] ? 0 : 20)
                }

                metricGlossaryCard
                    .opacity(cardAppeared[2] ? 1 : 0)
                    .offset(y: cardAppeared[2] ? 0 : 20)

                // Accuracy Interpretation
                interpretationCard
                    .opacity(cardAppeared[2] ? 1 : 0)
                    .offset(y: cardAppeared[2] ? 0 : 20)

                strategyCoachCard
                    .opacity(cardAppeared[2] ? 1 : 0)
                    .offset(y: cardAppeared[2] ? 0 : 20)

                // Feature Importance Chart
                ResultCard(title: "Model Transparency & Feature Impact", icon: "magnifyingglass", isExpanded: $showTransparency) {
                    featureImportanceChart
                }
                .opacity(cardAppeared[3] ? 1 : 0)
                .offset(y: cardAppeared[3] ? 0 : 20)

                // Model Comparison
                ResultCard(title: "Compare All Models", icon: "chart.bar.fill", isExpanded: $showCompare) {
                    modelComparisonChart
                }

                // Why Right / Wrong
                ResultCard(title: "Root Cause Analysis", icon: "questionmark.circle.fill", isExpanded: $showWhy) {
                    whyAnalysis
                }

                // Noise Impact
                if !labVM.noiseColumns.isEmpty {
                    ResultCard(title: "Noise vs Signal", icon: "waveform.path", isExpanded: $showNoise) {
                        noiseAnalysis
                    }
                }

                // Key Takeaways
                takeaways
                    .opacity(cardAppeared[4] ? 1 : 0)
                    .offset(y: cardAppeared[4] ? 0 : 20)

                // Action Buttons
                actionButtons
            }
            .padding(.top, 10)
        }
        .onAppear { staggerAppearance() }
    }

    private var resultsPrimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How To Read This Page")
                .font(AppFont.custom(16, weight: .semibold))
                .foregroundColor(.white)

            BulletPoint(text: "**Step 1:** Compare your podium prediction with the actual race result.")
            BulletPoint(text: "**Step 2:** Check where errors happened using the position error table.")
            BulletPoint(text: "**Step 3:** Use model transparency to see which features drove decisions.")
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [AppColor.gold.opacity(0.16), AppColor.racingRed.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColor.gold.opacity(0.25), lineWidth: 1)
        )
    }

    private var metricGlossaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics In Plain Language")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            MetricExplainerRow(
                title: "Prediction Accuracy",
                definition: "How close your full top-3 prediction was to reality.",
                whyItMatters: "Higher accuracy means your selected features captured real race performance."
            )

            MetricExplainerRow(
                title: "Position Error",
                definition: "How many places each predicted driver was off from the real finish position.",
                whyItMatters: "It shows whether the model was directionally right but misplaced exact rank."
            )

            MetricExplainerRow(
                title: "Model Transparency",
                definition: "How strongly each input feature influenced the model's score.",
                whyItMatters: "It helps you debug data choices and understand why a prediction happened."
            )
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    private var resultsContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Race Context")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ResultMetricTile(title: "Model", value: labVM.selectedModel?.shortName ?? "--")
                ResultMetricTile(title: "Track", value: labVM.selectedTrack.rawValue)
                ResultMetricTile(title: "Drivers", value: "\(labVM.drivers.count)")
                ResultMetricTile(title: "Noise", value: "\(labVM.noiseColumns.count)")
                ResultMetricTile(title: "Signal", value: "\(Int(labVM.signalToNoiseRatio * 100))%")
            }

            Text("This context explains why two runs with different settings can produce different outcomes.")
                .font(AppFont.custom(10))
                .foregroundColor(.white.opacity(0.62))
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    private var pitWallClassroomCard: some View {
        let baselineTop3 = Array(labVM.predictedTop3.prefix(3))
        let scenarioTop3 = scenarioPrediction(for: selectedClassroomScenario)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Pit Wall Classroom")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            Text("Run quick what-if drills to learn how feature changes shift your podium prediction.")
                .font(AppFont.custom(10))
                .foregroundColor(.white.opacity(0.68))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClassroomScenario.allCases) { scenario in
                        Button(action: {
                            selectedClassroomScenario = scenario
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: scenario.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(scenario.title)
                                    .font(AppFont.custom(11, weight: .semibold))
                            }
                            .foregroundColor(selectedClassroomScenario == scenario ? .white : .white.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedClassroomScenario == scenario ? AppColor.gold.opacity(0.26) : Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(selectedClassroomScenario == scenario ? AppColor.gold.opacity(0.42) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                classroomPodiumColumn(
                    title: "Current Setup",
                    subtitle: "Your original top-3",
                    drivers: baselineTop3
                )

                classroomPodiumColumn(
                    title: selectedClassroomScenario.afterTitle,
                    subtitle: selectedClassroomScenario.afterSubtitle,
                    drivers: scenarioTop3
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(scenarioExplanation(for: selectedClassroomScenario))
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var strategyCoachCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask Strategy Coach (Offline)")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            Text("Tap a question to get an instant explanation based on your current run.")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StrategyCoachTopic.allCases) { topic in
                        Button(action: {
                            selectedCoachTopic = topic
                        }) {
                            Text(topic.title)
                                .font(AppFont.custom(11, weight: .semibold))
                                .foregroundColor(selectedCoachTopic == topic ? .white : .white.opacity(0.75))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedCoachTopic == topic ? AppColor.racingRed.opacity(0.28) : Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(selectedCoachTopic == topic ? AppColor.racingRed.opacity(0.45) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
            }

            Text(coachAnswer(for: selectedCoachTopic))
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Accuracy Gauge

    private var accuracyGauge: some View {
        VStack(spacing: 12) {
            Text("Prediction Accuracy")
                .font(AppFont.custom(18, weight: .bold))
                .foregroundColor(.white)

            Text("This summarizes how close your predicted podium was to the actual podium.")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 14)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: CGFloat(resultsVM.accuracyPercent) / 100.0)
                    .stroke(AppColor.gold, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: resultsVM.accuracyPercent)

                Text("\(resultsVM.accuracyPercent)%")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }

            let correctCount = labVM.predictedTop3.prefix(3).filter { driver in
                raceVM.actualTop3.contains(where: { $0.id == driver.id })
            }.count

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(correctCount)")
                        .font(AppFont.custom(20, weight: .bold))
                        .foregroundColor(AppColor.green)
                    Text("Correct")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.6))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 25)

                VStack(spacing: 4) {
                    Text("\(3 - correctCount)")
                        .font(AppFont.custom(20, weight: .bold))
                        .foregroundColor(AppColor.orange)
                    Text("Missed")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Prediction Breakdown

    private var predictionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position-by-Position Breakdown")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            ForEach(0..<3, id: \.self) { position in
                if position < labVM.predictedTop3.count && position < raceVM.actualTop3.count {
                    let predicted = labVM.predictedTop3[position]
                    let actual = raceVM.actualTop3[position]
                    let isCorrect = predicted.id == actual.id

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Position badge
                            ZStack {
                                Circle()
                                    .fill(position == 0 ? AppColor.gold : position == 1 ? Color.gray : Color.brown)
                                    .frame(width: 28, height: 28)
                                Text("\(position + 1)")
                                    .font(AppFont.custom(14, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Predicted:")
                                        .font(AppFont.custom(10))
                                        .foregroundColor(.white.opacity(0.6))
                                    Circle().fill(predicted.color).frame(width: 8, height: 8)
                                    Text(predicted.name)
                                        .font(AppFont.custom(12, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                HStack(spacing: 6) {
                                    Text("Actual:")
                                        .font(AppFont.custom(10))
                                        .foregroundColor(.white.opacity(0.6))
                                    Circle().fill(actual.color).frame(width: 8, height: 8)
                                    Text(actual.name)
                                        .font(AppFont.custom(12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }

                            Spacer()

                            // Result indicator
                            if isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColor.green)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColor.racingRed)
                            }
                        }

                        // Visual progress bar showing confidence
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: isCorrect ? [AppColor.green, AppColor.green.opacity(0.6)] : [AppColor.racingRed, AppColor.racingRed.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: isCorrect ? geo.size.width : geo.size.width * 0.5, height: 6)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(position) * 0.2), value: isCorrect)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isCorrect ? AppColor.green.opacity(0.3) : AppColor.racingRed.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var positionErrorTable: some View {
        let predicted = Array(labVM.predictedTop3.prefix(3))
        let actual = Array(raceVM.actualTop3.prefix(3))

        var combinedDrivers: [Driver] = []
        for driver in predicted + actual where !combinedDrivers.contains(where: { $0.id == driver.id }) {
            combinedDrivers.append(driver)
        }

        let predictedRankByID = Dictionary(uniqueKeysWithValues: predicted.enumerated().map { ($1.id, $0 + 1) })
        let actualRankByID = Dictionary(uniqueKeysWithValues: actual.enumerated().map { ($1.id, $0 + 1) })
        let top3Inclusion = predicted.filter { driver in actual.contains(where: { $0.id == driver.id }) }.count
        let exactOrder = predicted.count == 3 && actual.count == 3 && zip(predicted, actual).allSatisfy { $0.id == $1.id }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Podium Position Error")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)

            Text("`Err` is the absolute difference between predicted and actual position. `Miss` means the driver was not in one of the top-3 lists.")
                .font(AppFont.custom(10))
                .foregroundColor(.white.opacity(0.65))

            HStack(spacing: 8) {
                Text("Driver")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Pred")
                    .frame(width: 34, alignment: .trailing)
                Text("Act")
                    .frame(width: 34, alignment: .trailing)
                Text("Err")
                    .frame(width: 36, alignment: .trailing)
            }
            .font(AppFont.custom(10, weight: .semibold))
            .foregroundColor(.white.opacity(0.6))

            ForEach(combinedDrivers, id: \.id) { driver in
                let predictedPos = predictedRankByID[driver.id]
                let actualPos = actualRankByID[driver.id]
                let errorText: String = {
                    if let predictedPos, let actualPos {
                        return "\(abs(predictedPos - actualPos))"
                    }
                    return "Miss"
                }()
                let errorColor: Color = {
                    if errorText == "0" { return AppColor.green }
                    if errorText == "Miss" { return AppColor.racingRed }
                    return AppColor.orange
                }()

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(driver.color)
                            .frame(width: 8, height: 8)
                        Text(driver.name)
                            .font(AppFont.custom(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(predictedPos.map(String.init) ?? "-")
                        .frame(width: 34, alignment: .trailing)
                    Text(actualPos.map(String.init) ?? "-")
                        .frame(width: 34, alignment: .trailing)
                    Text(errorText)
                        .frame(width: 36, alignment: .trailing)
                        .foregroundColor(errorColor)
                }
                .font(AppFont.custom(11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.vertical, 4)
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: exactOrder ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(exactOrder ? AppColor.green : AppColor.orange)
                    Text(exactOrder ? "Exact Order Match" : "Order Mismatch")
                        .font(AppFont.custom(11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text("Top-3 Inclusion: \(top3Inclusion)/3")
                    .font(AppFont.custom(11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Prediction")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                ForEach(Array(labVM.predictedTop3.enumerated()), id: \.offset) { index, driver in
                    PodiumRow(position: index + 1, driver: driver,
                              isCorrect: raceVM.actualTop3.indices.contains(index) && raceVM.actualTop3[index].id == driver.id)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.3)).frame(height: 100)

            VStack(alignment: .leading, spacing: 8) {
                Text("Actual Result")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                ForEach(Array(raceVM.actualTop3.enumerated()), id: \.offset) { index, driver in
                    PodiumRow(
                        position: index + 1,
                        driver: driver,
                        isCorrect: labVM.predictedTop3.indices.contains(index) && labVM.predictedTop3[index].id == driver.id
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Interpretation

    private var interpretationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What This Means")
                .font(AppFont.custom(16, weight: .semibold))
                .foregroundColor(.white)
            Text(resultsVM.accuracyInterpretation())
                .font(AppFont.custom(14))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Text("To improve: tune the data in Strategy Lab (especially Qualifying, Wins, Track Wins, DNFs) and compare model behavior in the transparency panel.")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Feature Importance Chart (Swift Charts)

    private var featureImportanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature influence on predictions")
                .font(AppFont.custom(13))
                .foregroundColor(.white.opacity(0.7))

            Text("Use this to understand model behavior: larger bars mean stronger impact on final ranking.")
                .font(AppFont.custom(10))
                .foregroundColor(.white.opacity(0.6))

            if let model = labVM.trainedModel {
                let importances = model.featureImportances()

                // Enhanced horizontal bars
                ForEach(importances, id: \.0) { feature, weight in
                    HStack(spacing: 8) {
                        Text(feature)
                            .font(AppFont.custom(12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 90, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: weight >= 0 ? [AppColor.green, AppColor.green.opacity(0.6)] : [AppColor.racingRed, AppColor.racingRed.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * min(abs(weight), 1.0))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(weight >= 0 ? AppColor.green : AppColor.racingRed, lineWidth: 1)
                                    )
                                    .shadow(color: (weight >= 0 ? AppColor.green : AppColor.racingRed).opacity(0.3), radius: 3)
                            }
                        }
                        .frame(height: 20)

                        Text(String(format: "%.2f", abs(weight)))
                            .font(AppFont.custom(11, weight: .bold))
                            .foregroundColor(weight >= 0 ? AppColor.green : AppColor.racingRed)
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(AppColor.green).frame(width: 8, height: 8)
                        Text("Helps").font(AppFont.custom(11)).foregroundColor(.white.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        Circle().fill(AppColor.racingRed).frame(width: 8, height: 8)
                        Text("Hurts").font(AppFont.custom(11)).foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            // Model calculations
            if let model = labVM.trainedModel {
                Divider().background(Color.white.opacity(0.2))

                Text("How the Model Scored Your Top 3")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white)

                ForEach(labVM.predictedTop3.prefix(3), id: \.id) { driver in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(driver.color).frame(width: 8, height: 8)
                            Text(driver.name)
                                .font(AppFont.custom(13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(model.explanation(for: driver))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Model Performance Radar

    private var modelPerformanceRadar: some View {
        let scores = resultsVM.getAllModelScores(
            modelPredictions: labVM.modelPredictions,
            actual: raceVM.actualTop3
        )

        return VStack(spacing: 16) {
            Text("Model Performance Comparison")
                .font(AppFont.custom(15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius: CGFloat = min(geo.size.width, geo.size.height) / 2 - 40

                ZStack {
                    // Background circles
                    ForEach(1..<7) { level in
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: radius * 2 * CGFloat(level) / 6, height: radius * 2 * CGFloat(level) / 6)
                    }

                    // Model performance arcs
                    ForEach(Array(scores.enumerated()), id: \.offset) { index, item in
                        let (model, score) = item
                        let angle = CGFloat(index) * (360.0 / CGFloat(scores.count))
                        let normalizedScore = CGFloat(score) / 6.0
                        let arcRadius = radius * normalizedScore

                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [model.accent.opacity(0.6), model.accent.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .position(
                                x: center.x + cos(angle * .pi / 180 - .pi / 2) * arcRadius,
                                y: center.y + sin(angle * .pi / 180 - .pi / 2) * arcRadius
                            )

                        // Data point
                        Circle()
                            .fill(model.accent)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .position(
                                x: center.x + cos(angle * .pi / 180 - .pi / 2) * arcRadius,
                                y: center.y + sin(angle * .pi / 180 - .pi / 2) * arcRadius
                            )

                        // Line from center
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: CGPoint(
                                x: center.x + cos(angle * .pi / 180 - .pi / 2) * arcRadius,
                                y: center.y + sin(angle * .pi / 180 - .pi / 2) * arcRadius
                            ))
                        }
                        .stroke(model.accent.opacity(0.5), lineWidth: 2)

                        // Model label
                        Text(model.shortName)
                            .font(AppFont.custom(10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(model.accent.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(model.accent, lineWidth: 1)
                                    )
                            )
                            .position(
                                x: center.x + cos(angle * .pi / 180 - .pi / 2) * (radius + 25),
                                y: center.y + sin(angle * .pi / 180 - .pi / 2) * (radius + 25)
                            )

                        // Score label
                        Text("\(score)")
                            .font(AppFont.custom(14, weight: .bold))
                            .foregroundColor(model.accent)
                            .position(
                                x: center.x + cos(angle * .pi / 180 - .pi / 2) * arcRadius,
                                y: center.y + sin(angle * .pi / 180 - .pi / 2) * arcRadius - 20
                            )
                    }

                    // Center point
                    Circle()
                        .fill(AppColor.gold)
                        .frame(width: 8, height: 8)
                        .position(center)
                }
            }
            .frame(height: 280)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Model Comparison Chart (Swift Charts)

    private var modelComparisonChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare models to learn that architecture choice and data quality both affect outcome.")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.7))

            // Add radar chart first
            modelPerformanceRadar
            // Convergence insight
            let converged = resultsVM.modelsConverged(modelPredictions: labVM.modelPredictions)
            HStack(spacing: 10) {
                Image(systemName: converged ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(converged ? AppColor.green : AppColor.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(converged ? "High Model Agreement" : "Models Disagree")
                        .font(AppFont.custom(14, weight: .bold))
                        .foregroundColor(.white)
                    Text(resultsVM.convergenceExplanation(modelPredictions: labVM.modelPredictions))
                        .font(AppFont.custom(12))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((converged ? AppColor.green : AppColor.orange).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((converged ? AppColor.green : AppColor.orange).opacity(0.3), lineWidth: 1.5)
                    )
            )

            // Scores chart with animation
            let scores = resultsVM.getAllModelScores(
                modelPredictions: labVM.modelPredictions,
                actual: raceVM.actualTop3
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("How Each Model Performed")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Chart(scores, id: \.0) { model, score in
                    BarMark(
                        x: .value("Model", model.shortName),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [model.accent, model.accent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                    .annotation(position: .top, spacing: 6) {
                        VStack(spacing: 2) {
                            Text("\(score)")
                                .font(AppFont.custom(14, weight: .bold))
                                .foregroundColor(.white)
                            if score == scores.map({ $0.1 }).max() {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColor.gold)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...6)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel() {
                            if let model = value.as(String.self) {
                                Text(model)
                                    .font(AppFont.custom(11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 2, 4, 6]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel() {
                            if let score = value.as(Int.self) {
                                Text("\(score)")
                                    .font(AppFont.custom(10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(.vertical, 8)

                // Winner callout
                if let winner = scores.max(by: { $0.1 < $1.1 }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(AppColor.gold)
                        Text("\(winner.0.rawValue) performed best with \(winner.1)/6 points")
                            .font(AppFont.custom(13, weight: .semibold))
                            .foregroundColor(AppColor.gold)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColor.gold.opacity(0.1))
                    )
                }
            }
        }
    }

    // MARK: - Why Analysis

    private var whyAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(resultsVM.whySummary(
                predictedTop3: labVM.predictedTop3,
                actualTop3: raceVM.actualTop3,
                raceCars: raceVM.raceCars
            ))
            .font(AppFont.custom(14))
            .foregroundColor(.white.opacity(0.85))

            Divider().background(Color.white.opacity(0.2))

            Text("ML Lesson")
                .font(AppFont.custom(14, weight: .semibold))
                .foregroundColor(AppColor.gold)

            Text("Models can only learn from the data you give them. If important factors (like pit strategy, tires, or weather) aren't in your dataset, the model can't account for them. This is called **missing features**.")
                .font(AppFont.custom(13))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Noise Analysis

    private var noiseAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(resultsVM.missingDataSummary(noiseColumns: labVM.noiseColumns))
                .font(AppFont.custom(14))
                .foregroundColor(.white.opacity(0.85))

            VStack(alignment: .leading, spacing: 8) {
                Text("Why Noise Hurts ML")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(AppColor.gold)

                BulletPoint(text: "**Overfitting**: Model learns random patterns instead of real relationships")
                BulletPoint(text: "**Reduced Accuracy**: Irrelevant data dilutes the signal from useful features")
                BulletPoint(text: "**Feature Engineering**: Selecting the right features is as important as the model")
            }
        }
    }

    // MARK: - Key Takeaways

    private var takeaways: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Takeaways")
                .font(AppFont.custom(18, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                LearningPoint(title: "Models Learn Patterns", description: "ML finds mathematical relationships between inputs and outputs.")
                LearningPoint(title: "Data Quality = Model Quality", description: "Garbage in, garbage out. Clean, relevant features lead to better predictions.")
                LearningPoint(title: "No Crystal Ball", description: "Models can't predict events that aren't in historical data.")
                LearningPoint(title: "Feature Engineering Matters", description: "Choosing which data to include is as important as the model itself.")
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppColor.racingRed.opacity(0.15), AppColor.gold.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                HapticsManager.shared.buttonPress()
                onBuildModel()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Build Your Own Model")
                        .font(AppFont.custom(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppColor.gold, AppColor.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppColor.gold.opacity(0.4), radius: 8, x: 0, y: 4)
            }

            HStack(spacing: 12) {
                Button("Run Again") {
                    HapticsManager.shared.buttonPress()
                    onRunAgain()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(raceVM.runCount >= raceVM.maxRunCount)
                .opacity(raceVM.runCount >= raceVM.maxRunCount ? 0.5 : 1)

                Button("Edit Data") {
                    HapticsManager.shared.buttonPress()
                    onEditData()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - Stagger

    private func staggerAppearance() {
        for i in 0..<cardAppeared.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardAppeared[i] = true
                }
            }
        }
    }

    private func classroomPodiumColumn(title: String, subtitle: String, drivers: [Driver]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.custom(12, weight: .semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(AppFont.custom(9))
                .foregroundColor(.white.opacity(0.62))

            ForEach(0..<3, id: \.self) { index in
                let driver = drivers.indices.contains(index) ? drivers[index] : nil
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(AppFont.custom(10, weight: .bold))
                        .foregroundColor(AppColor.gold)
                        .frame(width: 14, alignment: .leading)

                    if let driver {
                        Circle()
                            .fill(driver.color)
                            .frame(width: 8, height: 8)
                        Text(driver.name)
                            .font(AppFont.custom(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    } else {
                        Text("--")
                            .font(AppFont.custom(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func scenarioPrediction(for scenario: ClassroomScenario) -> [Driver] {
        guard let modelType = labVM.selectedModel else { return [] }
        guard labVM.drivers.count >= 3 else { return [] }

        var scenarioDrivers = labVM.drivers
        var scenarioNoise = labVM.noiseColumns

        switch scenario {
        case .cleanData:
            scenarioNoise = []
        case .qualifyingFocus:
            let ordered = scenarioDrivers.sorted { lhs, rhs in
                scenarioQualifyingStrength(lhs) > scenarioQualifyingStrength(rhs)
            }
            for (position, driver) in ordered.enumerated() {
                guard let index = scenarioDrivers.firstIndex(where: { $0.id == driver.id }) else { continue }
                scenarioDrivers[index].qualifying = position + 1
                scenarioDrivers[index].wins = min(60, scenarioDrivers[index].wins + 1)
            }
        case .reliabilityFocus:
            for index in scenarioDrivers.indices {
                scenarioDrivers[index].dnfs = max(0, scenarioDrivers[index].dnfs - 2)
                if scenarioDrivers[index].dnfs <= 1 {
                    scenarioDrivers[index].trackWins = min(8, scenarioDrivers[index].trackWins + 1)
                }
            }
        }

        var scenarioModel = MLModelFactory.create(type: modelType)
        scenarioModel.train(drivers: scenarioDrivers, noiseColumns: scenarioNoise, track: labVM.selectedTrack)

        let scored = scenarioDrivers.map { driver -> (Driver, Double) in
            (driver, scenarioModel.predict(driver: driver))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }

    private func scenarioQualifyingStrength(_ driver: Driver) -> Double {
        let consistencyBonus = max(0.0, 8.0 - Double(driver.dnfs)) * 2.2
        return Double(driver.wins) * 1.4 + Double(driver.trackWins) * 3.0 + consistencyBonus - Double(driver.qualifying) * 0.6
    }

    private func scenarioExplanation(for scenario: ClassroomScenario) -> String {
        let modelName = labVM.selectedModel?.shortName ?? "selected model"
        switch scenario {
        case .cleanData:
            return "Noise columns are removed while core racing stats stay the same. This shows how \(modelName) behaves with a cleaner signal."
        case .qualifyingFocus:
            return "Qualifying order is rebuilt from recent pace proxies (wins, track wins, reliability). This teaches how front-row starts can shift podium outcomes."
        case .reliabilityFocus:
            return "DNFs are reduced and dependable drivers gain slight track confidence. This demonstrates why consistency often outperforms raw pace over a race."
        }
    }

    private func coachAnswer(for topic: StrategyCoachTopic) -> String {
        let scoreSummary = resultsVM.compareModelsSummary(modelPredictions: labVM.modelPredictions, actual: raceVM.actualTop3)
        let bestSignal = Int(labVM.signalToNoiseRatio * 100)

        switch topic {
        case .whyResult:
            return resultsVM.whySummary(predictedTop3: labVM.predictedTop3, actualTop3: raceVM.actualTop3, raceCars: raceVM.raceCars)
        case .improve:
            return "Start by improving data quality: keep signal high (\(bestSignal)% now), reduce noise, and tune Qualifying/Track Wins for the selected track. Then compare models and rerun."
        case .transparency:
            return "Model transparency shows which features had the strongest impact. If a feature dominates too much, rebalance your data or test another model."
        case .positionError:
            return "Position error tells how far each prediction was from the true finish rank. Focus on reducing large errors first, not just maximizing one correct position."
        case .modelChoice:
            return scoreSummary
        }
    }
}

// MARK: - Supporting Views

private enum StrategyCoachTopic: String, CaseIterable, Identifiable {
    case whyResult = "Why this result?"
    case improve = "How to improve?"
    case transparency = "What is transparency?"
    case positionError = "What is position error?"
    case modelChoice = "Which model next?"

    var id: String { rawValue }
    var title: String { rawValue }
}

private enum ClassroomScenario: CaseIterable, Identifiable {
    case cleanData
    case qualifyingFocus
    case reliabilityFocus

    var id: String { title }

    var title: String {
        switch self {
        case .cleanData: return "Remove Noise"
        case .qualifyingFocus: return "Quali Drill"
        case .reliabilityFocus: return "Reliability Drill"
        }
    }

    var icon: String {
        switch self {
        case .cleanData: return "waveform.path.ecg"
        case .qualifyingFocus: return "flag.checkered"
        case .reliabilityFocus: return "shield.lefthalf.filled"
        }
    }

    var afterTitle: String {
        switch self {
        case .cleanData: return "After Cleaning Data"
        case .qualifyingFocus: return "After Qualifying Focus"
        case .reliabilityFocus: return "After Reliability Focus"
        }
    }

    var afterSubtitle: String {
        switch self {
        case .cleanData: return "Signal-first prediction"
        case .qualifyingFocus: return "Grid-optimized projection"
        case .reliabilityFocus: return "Consistency-optimized projection"
        }
    }
}

private struct ResultMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.custom(9, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(AppFont.custom(12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct PodiumRow: View {
    var position: Int
    var driver: Driver
    var isCorrect: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(position)")
                .font(AppFont.custom(12, weight: .bold))
                .foregroundColor(AppColor.gold)
                .frame(width: 20)
            Circle().fill(driver.color).frame(width: 8, height: 8)
            Text(driver.name)
                .font(AppFont.custom(13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isCorrect ? AppColor.green : .red.opacity(0.7))
                .font(.system(size: 12))
        }
        .padding(.vertical, 4)
    }
}

private struct MetricExplainerRow: View {
    let title: String
    let definition: String
    let whyItMatters: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.custom(12, weight: .semibold))
                .foregroundColor(AppColor.gold)
            Text("What it is: \(definition)")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.8))
            Text("Why it matters: \(whyItMatters)")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct LearningPoint: View {
    var title: String
    var description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(AppColor.gold)
                .font(.system(size: 16))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(AppFont.custom(12))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(AppColor.orange).frame(width: 6, height: 6).padding(.top, 5)
            Text(.init(text))
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

struct ResultCard<Content: View>: View {
    var title: String
    var icon: String
    @Binding var isExpanded: Bool
    var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(AppColor.racingRed)
                    Text(title)
                        .font(AppFont.custom(16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }
}
