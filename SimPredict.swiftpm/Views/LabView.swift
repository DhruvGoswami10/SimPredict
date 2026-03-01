import SwiftUI
import TipKit

struct LabView: View {
    @ObservedObject var labVM: LabViewModel
    var onStartSimulation: () -> Void

    private let modelTip = ModelSelectionTip()
    private let dataTip = DataPlaygroundTip()
    private let trackTip = TrackSelectionTip()
    private let noiseTip = NoiseExperimentTip()
    private let predictTip = PredictLaunchTip()
    private var canLaunchRace: Bool {
        labVM.selectedModel != nil && labVM.drivers.count >= labVM.minDrivers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strategy Lab")
                        .font(AppFont.custom(28, weight: .bold))
                        .foregroundColor(.white)
                    Text(labVM.currentStep.title)
                        .font(AppFont.custom(14))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()

                // Live preview badge
                if !labVM.livePreviewTop3.isEmpty && labVM.currentStep != .predict {
                    LivePreviewBadge(drivers: labVM.livePreviewTop3)
                }
            }
            .padding(.bottom, 12)

            // Step Indicator
            StepIndicator(currentStep: labVM.currentStep, onTap: { step in
                labVM.goToStep(step)
            })
            .padding(.bottom, 16)

            // Step Content
            ScrollView {
                Group {
                    switch labVM.currentStep {
                    case .modelSelection:
                        modelSelectionStep
                    case .dataPlayground:
                        dataPlaygroundStep
                    case .trackSelection:
                        trackSelectionStep
                    case .dataQuality:
                        dataQualityStep
                    case .predict:
                        predictStep
                    }
                }
                .transition(.slide)
                .animation(.easeInOut(duration: 0.35), value: labVM.currentStep)
            }
        }
    }

    // MARK: - Step 1: Model Selection

    private var modelSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your ML model")
                .font(AppFont.custom(16))
                .foregroundColor(.white.opacity(0.8))
                .popoverTip(modelTip)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                ForEach(ModelType.allCases) { model in
                    ModelCard(
                        model: model,
                        isSelected: labVM.selectedModel == model,
                        isFaded: labVM.selectedModel != nil && labVM.selectedModel != model && labVM.showModelVisualization,
                        onTap: { labVM.selectModel(model) }
                    )
                }
            }

            if labVM.showModelVisualization, let model = labVM.selectedModel {
                ModelVisualizationView(
                    modelType: model,
                    labVM: labVM
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .padding(.top, 8)
            }

            if labVM.selectedModel != nil {
                Button(action: { labVM.nextStep() }) {
                    HStack {
                        Text("Next: Set Up Data")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Step 2: Data Playground

    private var dataPlaygroundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjust driver stats to shape your prediction")
                .font(AppFont.custom(15))
                .foregroundColor(.white.opacity(0.8))

            // Quick Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickActionButton(icon: "shuffle", title: "Randomize") {
                        labVM.randomizeAllStats()
                    }
                    QuickActionButton(icon: "arrow.uturn.backward", title: "Reset") {
                        labVM.resetToDefaults()
                    }
                    QuickActionButton(icon: "arrow.up.arrow.down", title: "Flip") {
                        labVM.flipStats()
                    }
                    QuickActionButton(icon: "exclamationmark.triangle", title: "Outlier") {
                        labVM.addOutlier()
                    }
                    QuickActionButton(icon: "person.3.fill", title: "Add All") {
                        labVM.addAllDrivers()
                    }
                    QuickActionButton(icon: "trophy", title: "Shuffle Quali") {
                        labVM.shuffleQualifying()
                    }
                }
            }
            .popoverTip(dataTip)

            if !labVM.livePreviewTop3.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Podium Preview")
                        .font(AppFont.custom(13, weight: .semibold))
                        .foregroundColor(.white)

                    ForEach(Array(labVM.livePreviewTop3.prefix(3).enumerated()), id: \.offset) { index, driver in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(AppFont.custom(12, weight: .bold))
                                .foregroundColor(AppColor.gold)
                                .frame(width: 14)
                            Circle().fill(driver.color).frame(width: 8, height: 8)
                            Text(driver.name)
                                .font(AppFont.custom(12, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(driver.team)
                                .font(AppFont.custom(10))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
                .padding(12)
                .glassCard(cornerRadius: 12)
            }

            // Driver Cards
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($labVM.drivers) { $driver in
                        DriverCard(
                            driver: $driver,
                            maxDrivers: labVM.drivers.count,
                            canDelete: labVM.drivers.count > labVM.minDrivers,
                            onStatChange: { labVM.updateLivePreview() },
                            onDelete: { labVM.removeDriver(id: driver.id) }
                        )
                    }
                }
            }
            .frame(maxHeight: 400)

            HStack {
                Button(action: { labVM.addDriver() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(labVM.drivers.count >= labVM.maxDrivers ? "Max \(labVM.maxDrivers)" : "Add Driver")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(labVM.drivers.count >= labVM.maxDrivers)
                .opacity(labVM.drivers.count >= labVM.maxDrivers ? 0.5 : 1)

                Spacer()

                Text("\(labVM.drivers.count) drivers")
                    .font(AppFont.custom(12))
                    .foregroundColor(.white.opacity(0.5))
            }

            NavigationButtons(
                onBack: { labVM.previousStep() },
                onNext: { labVM.nextStep() },
                nextTitle: "Next: Pick Track"
            )
        }
    }

    // MARK: - Step 3: Track Selection

    private var trackSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Different tracks favor different strengths")
                .font(AppFont.custom(15))
                .foregroundColor(.white.opacity(0.8))
                .popoverTip(trackTip)

            ForEach(TrackInfo.allCases) { track in
                TrackCard(
                    track: track,
                    isSelected: labVM.selectedTrack == track,
                    onTap: {
                        HapticsManager.shared.modelSelect()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            labVM.selectedTrack = track
                        }
                        labVM.updateLivePreview()
                    }
                )
            }

            NavigationButtons(
                onBack: { labVM.previousStep() },
                onNext: { labVM.nextStep() },
                nextTitle: "Next: Data Quality"
            )
        }
    }

    // MARK: - Step 4: Data Quality (Noise)

    private var dataQualityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add irrelevant data to test model robustness")
                .font(AppFont.custom(15))
                .foregroundColor(.white.opacity(0.8))

            // Signal vs Noise Meter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Signal Strength")
                        .font(AppFont.custom(14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(labVM.signalToNoiseRatio * 100))%")
                        .font(AppFont.custom(14, weight: .bold))
                        .foregroundColor(labVM.signalToNoiseRatio > 0.7 ? AppColor.green : AppColor.orange)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: labVM.signalToNoiseRatio > 0.7 ?
                                        [AppColor.green, AppColor.darkGreen] :
                                        [AppColor.orange, AppColor.racingRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * labVM.signalToNoiseRatio)
                            .animation(.spring(response: 0.4), value: labVM.signalToNoiseRatio)
                    }
                }
                .frame(height: 12)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
            .popoverTip(noiseTip)

            HStack(spacing: 8) {
                SignalSummaryTile(title: "Noise Columns", value: "\(labVM.noiseColumns.count)/\(labVM.maxNoiseColumns)")
                SignalSummaryTile(
                    title: "Data Robustness",
                    value: labVM.signalToNoiseRatio > 0.7 ? "High" : (labVM.signalToNoiseRatio > 0.45 ? "Medium" : "Low")
                )
            }

            // Noise Columns
            if !labVM.noiseColumns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labVM.noiseColumns) { column in
                            NoiseChip(column: column) {
                                labVM.removeNoiseColumn(id: column.id)
                            }
                        }
                    }
                }
            } else {
                Text("No noise added — predictions based on racing stats only")
                    .font(AppFont.custom(13))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
            }

            // Add Noise Buttons
            Text("Add Noise Column")
                .font(AppFont.custom(14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(NoiseColumnType.allCases) { noiseType in
                    let alreadyAdded = labVM.noiseColumns.contains { $0.type == noiseType }
                    Button(action: {
                        if !alreadyAdded {
                            labVM.addNoiseColumn(type: noiseType)
                            HapticsManager.shared.buttonPress()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: noiseType.icon)
                                .font(.system(size: 14))
                            Text(noiseType.rawValue)
                                .font(AppFont.custom(12, weight: .medium))
                        }
                        .foregroundColor(alreadyAdded ? .white.opacity(0.3) : AppColor.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(alreadyAdded ? Color.white.opacity(0.05) : AppColor.orange.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(alreadyAdded ? Color.clear : AppColor.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(alreadyAdded || labVM.noiseColumns.count >= labVM.maxNoiseColumns)
                }
            }

            NavigationButtons(
                onBack: { labVM.previousStep() },
                onNext: { labVM.nextStep() },
                nextTitle: "Next: Predict"
            )
        }
    }

    // MARK: - Step 5: Predict & Launch

    private var predictStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review your setup and launch")
                .font(AppFont.custom(15))
                .foregroundColor(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Readiness Checklist")
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white)
                ReadinessCheckRow(label: "Model selected", isReady: labVM.selectedModel != nil)
                ReadinessCheckRow(label: "At least \(labVM.minDrivers) drivers", isReady: labVM.drivers.count >= labVM.minDrivers)
                ReadinessCheckRow(label: "Track selected", isReady: true)
                ReadinessCheckRow(label: "Signal quality", isReady: labVM.signalToNoiseRatio > 0.4)
            }
            .padding(12)
            .glassCard(cornerRadius: 12)

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(icon: "cpu", label: "Model", value: selectedModelSummary)
                SummaryRow(icon: "person.3.fill", label: "Drivers", value: "\(labVM.drivers.count)")
                SummaryRow(icon: "flag.checkered", label: "Track", value: labVM.selectedTrack.rawValue)
                SummaryRow(icon: "waveform.path", label: "Noise Columns", value: "\(labVM.noiseColumns.count)")
                SummaryRow(icon: "chart.bar.fill", label: "Signal Strength", value: "\(Int(labVM.signalToNoiseRatio * 100))%")
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Predicted Top 3
            if !labVM.livePreviewTop3.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Predicted Podium")
                        .font(AppFont.custom(16, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(Array(labVM.livePreviewTop3.enumerated()), id: \.offset) { index, driver in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(AppFont.custom(16, weight: .bold))
                                .foregroundColor(AppColor.gold)
                                .frame(width: 24)
                            Circle()
                                .fill(driver.color)
                                .frame(width: 12, height: 12)
                            Text(driver.name)
                                .font(AppFont.custom(15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(driver.team)
                                .font(AppFont.custom(12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
            }

            Button(action: {
                HapticsManager.shared.buttonPress()
                onStartSimulation()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                    Text("Predict & Race")
                        .font(AppFont.custom(18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.redGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppColor.racingRed.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .disabled(!canLaunchRace)
            .opacity(canLaunchRace ? 1 : 0.5)
            .popoverTip(predictTip)

            Button(action: { labVM.previousStep() }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var selectedModelSummary: String {
        guard let selectedModel = labVM.selectedModel else { return "None" }
        if selectedModel == .knn {
            return "\(selectedModel.rawValue) (K=\(labVM.knnK))"
        }
        return selectedModel.rawValue
    }
}

// MARK: - Supporting Views

private struct StepIndicator: View {
    let currentStep: LabStep
    let onTap: (LabStep) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LabStep.allCases, id: \.rawValue) { step in
                Button(action: { onTap(step) }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(step == currentStep ? AppColor.racingRed : (step.rawValue < currentStep.rawValue ? AppColor.green : Color.white.opacity(0.15)))
                                .frame(width: 32, height: 32)
                            Image(systemName: step.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        Text(step.title)
                            .font(AppFont.custom(10, weight: step == currentStep ? .bold : .medium))
                            .foregroundColor(step == currentStep ? .white : .white.opacity(0.5))
                    }
                }
                .disabled(step.rawValue > currentStep.rawValue + 1)

                if step.rawValue < LabStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? AppColor.green.opacity(0.5) : Color.white.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                }
            }
        }
    }
}

private struct ModelCard: View {
    let model: ModelType
    let isSelected: Bool
    let isFaded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: model.icon)
                        .font(.title2)
                        .foregroundColor(model.accent)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(model.accent)
                    }
                }
                Text(model.rawValue)
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white)
                Text(model.summary)
                    .font(AppFont.custom(12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? model.accent : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isFaded ? 0.95 : 1.0)
            .opacity(isFaded ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct DriverCard: View {
    @Binding var driver: Driver
    let maxDrivers: Int
    let canDelete: Bool
    let onStatChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name)
                    .font(AppFont.custom(14, weight: .semibold))
                    .foregroundColor(.white)
                Text(driver.team)
                    .font(AppFont.custom(11))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 90, alignment: .leading)

            CompactStepper(label: "Q", value: $driver.qualifying, range: 1...maxDrivers, onChange: onStatChange)
            CompactStepper(label: "W", value: $driver.wins, range: 0...60, onChange: onStatChange)
            CompactStepper(label: "TW", value: $driver.trackWins, range: 0...8, onChange: onStatChange)
            CompactStepper(label: "D", value: $driver.dnfs, range: 0...15, onChange: onStatChange)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.system(size: 16))
            }
            .disabled(!canDelete)
            .opacity(canDelete ? 1 : 0.35)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CompactStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var onChange: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(AppFont.custom(9, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 4) {
                Button(action: {
                    guard value > range.lowerBound else { return }
                    value -= 1
                    HapticsManager.shared.sliderChange()
                    onChange?()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Text("\(value)")
                    .font(AppFont.custom(13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24)
                Button(action: {
                    guard value < range.upperBound else { return }
                    value += 1
                    HapticsManager.shared.sliderChange()
                    onChange?()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColor.racingRed)
                }
            }
        }
        .frame(width: 55)
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticsManager.shared.buttonPress()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(AppFont.custom(12, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct TrackCard: View {
    let track: TrackInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Mini track preview
                ZStack {
                    if let sampler = TrackPathSampler(svgName: track.svgName, viewBox: track.viewBox) {
                        TrackShape(path: sampler.path, viewBox: sampler.viewBox)
                            .stroke(isSelected ? AppColor.racingRed : Color.white.opacity(0.3), lineWidth: 2)
                    }
                }
                .frame(width: 80, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: track.icon)
                            .foregroundColor(isSelected ? AppColor.racingRed : .white.opacity(0.6))
                        Text(track.rawValue)
                            .font(AppFont.custom(16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(track.subtitle)
                        .font(AppFont.custom(12))
                        .foregroundColor(.white.opacity(0.6))
                    Text(track.characteristics)
                        .font(AppFont.custom(11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColor.racingRed)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AppColor.racingRed : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NoiseChip: View {
    let column: NoiseColumn
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: column.type.icon)
                .foregroundColor(AppColor.orange)
                .font(.system(size: 12))
            Text(column.type.rawValue)
                .font(AppFont.custom(12, weight: .medium))
                .foregroundColor(.white)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColor.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColor.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct LivePreviewBadge: View {
    let drivers: [Driver]

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 10))
                .foregroundColor(AppColor.gold)
            ForEach(Array(drivers.prefix(3).enumerated()), id: \.offset) { _, driver in
                Circle()
                    .fill(driver.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppColor.racingRed)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(label)
                .font(AppFont.custom(14))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(AppFont.custom(14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

private struct SignalSummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.custom(10, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))
            Text(value)
                .font(AppFont.custom(13, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct ReadinessCheckRow: View {
    let label: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isReady ? AppColor.green : AppColor.racingRed)
                .font(.system(size: 13))
            Text(label)
                .font(AppFont.custom(12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }
}

private struct NavigationButtons: View {
    let onBack: () -> Void
    let onNext: () -> Void
    var nextTitle: String = "Next"

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: onNext) {
                HStack {
                    Text(nextTitle)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 8)
    }
}
