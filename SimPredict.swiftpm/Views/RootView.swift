import SwiftUI

struct RootView: View {
    @StateObject private var appVM = AppViewModel()
    @StateObject private var labVM = LabViewModel()
    @StateObject private var raceVM = RaceViewModel()
    @StateObject private var resultsVM = ResultsViewModel()
    @Namespace private var animation

    var body: some View {
        ZStack {
            phaseBackground

            Group {
                switch appVM.phase {
                case .welcome:
                    WelcomeFlowView {
                        appVM.goTo(.lab)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .lab:
                    LabView(
                        labVM: labVM,
                        onStartSimulation: {
                            labVM.predict()
                            raceVM.beginRace(
                                drivers: labVM.drivers,
                                noiseColumns: labVM.noiseColumns,
                                track: labVM.selectedTrack,
                                runAgain: false
                            )
                            appVM.goTo(.simulation)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .simulation:
                    RaceSimulationView(
                        raceVM: raceVM,
                        labVM: labVM,
                        onRaceComplete: {
                            resultsVM.calculateAccuracy(
                                predicted: labVM.predictedTop3,
                                actual: raceVM.actualTop3
                            )
                            appVM.goTo(.results)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .results:
                    ResultsView(
                        labVM: labVM,
                        raceVM: raceVM,
                        resultsVM: resultsVM,
                        onRunAgain: {
                            raceVM.beginRace(
                                drivers: labVM.drivers,
                                noiseColumns: labVM.noiseColumns,
                                track: labVM.selectedTrack,
                                runAgain: true
                            )
                            appVM.goTo(.simulation)
                        },
                        onEditData: {
                            appVM.goTo(.lab)
                        },
                        onBuildModel: {
                            appVM.goTo(.buildModel)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .buildModel:
                    BuildYourModelView(
                        labVM: labVM,
                        raceVM: raceVM,
                        resultsVM: resultsVM,
                        onBack: {
                            appVM.goTo(.results)
                        },
                        onTestModel: { customWeights in
                            labVM.predictWithCustomWeights(customWeights)
                            raceVM.beginRace(
                                drivers: labVM.drivers,
                                noiseColumns: labVM.noiseColumns,
                                track: labVM.selectedTrack,
                                runAgain: true
                            )
                            appVM.goTo(.simulation)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, appVM.phase == .welcome ? 0 : 20)
            .padding(.vertical, appVM.phase == .welcome ? 0 : 16)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appVM.phase)
    }

    @ViewBuilder
    private var phaseBackground: some View {
        if appVM.phase == .welcome {
            Color.black.ignoresSafeArea()
        } else {
            ZStack {
                Color(hex: "0a0808").ignoresSafeArea()
                EmberBackgroundView()
            }
        }
    }
}
