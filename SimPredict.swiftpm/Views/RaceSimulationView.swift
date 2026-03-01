import SwiftUI
@preconcurrency import CoreGraphics

struct RaceSimulationView: View {
    @ObservedObject var raceVM: RaceViewModel
    @ObservedObject var labVM: LabViewModel
    var onRaceComplete: () -> Void

    @State private var timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    @State private var didScheduleCompletion = false
    @State private var raceCompletionGeneration: Int = 0
    private let simulationTimeScale: Double = 1.45

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Race Simulation")
                .font(AppFont.custom(26, weight: .bold))
                .foregroundColor(.white)

            RaceTopInfoBar(raceVM: raceVM)

            GeometryReader { geometry in
                let isWide = geometry.size.width > 700
                if isWide {
                    HStack(spacing: 16) {
                        RaceTrackView(
                            cars: raceVM.raceCars,
                            track: raceVM.selectedTrack
                        )
                        .frame(width: geometry.size.width * 0.63, height: geometry.size.height)

                        RaceSidePanel(raceVM: raceVM, labVM: labVM)
                            .frame(width: geometry.size.width * 0.37, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 16) {
                        RaceTrackView(
                            cars: raceVM.raceCars,
                            track: raceVM.selectedTrack
                        )
                        .frame(height: geometry.size.height * 0.62)

                        RaceSidePanel(raceVM: raceVM, labVM: labVM)
                    }
                }
            }
            .frame(height: 500)

            RaceBottomInfoBar(raceVM: raceVM, labVM: labVM)
        }
        .onReceive(timer) { _ in
            raceVM.tickRace(delta: 0.02 * simulationTimeScale)
            if !raceVM.isRaceActive && !raceVM.actualTop3.isEmpty && !didScheduleCompletion {
                didScheduleCompletion = true
                let generation = raceCompletionGeneration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard generation == raceCompletionGeneration else { return }
                    guard !raceVM.isRaceActive, !raceVM.actualTop3.isEmpty else { return }
                    onRaceComplete()
                }
            }
        }
        .onChange(of: raceVM.isRaceActive) { _, isActive in
            if isActive {
                didScheduleCompletion = false
                raceCompletionGeneration += 1
            }
        }
    }
}

// MARK: - Race Track View

struct RaceTrackView: View {
    var cars: [RaceCar]
    var track: TrackInfo
    private static let carAsset = SVGVectorLoader.loadCompositeAsset(named: "race-car-3-svgrepo-com")
    private enum MarkerStyle {
        static let carWidth: CGFloat = 25
        static let activeGlow: CGFloat = 30
        static let overtakeGlow: CGFloat = 35
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let sampler = TrackPathSampler(svgName: track.svgName, viewBox: track.viewBox)
            ZStack {
                if let sampler = sampler {
                    let trackRect = CGRect(origin: .zero, size: size)

                    // Track surface
                    TrackShape(path: sampler.path, viewBox: sampler.viewBox)
                        .stroke(Color.black.opacity(0.55), lineWidth: 20)
                    TrackShape(path: sampler.path, viewBox: sampler.viewBox)
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    TrackShape(path: sampler.path, viewBox: sampler.viewBox)
                        .stroke(Color.white.opacity(0.08), lineWidth: 2)

                    // Start/Finish line aligned with track direction
                    let (startTrackPoint, startTangent) = sampler.pointAndAngle(at: 0.0)
                    let startPos = sampler.map(point: startTrackPoint, in: trackRect)
                    StartFinishMarker(angle: Angle(radians: Double(startTangent + (CGFloat.pi / 2))))
                        .position(startPos)

                    // DRS markers from selected track data
                    ForEach(Array(track.drsZones.enumerated()), id: \.offset) { _, zone in
                        let markerCount = max(8, Int((zone.1 - zone.0) * 140))
                        ForEach(0..<markerCount, id: \.self) { marker in
                            let t = Double(marker) / Double(max(markerCount - 1, 1))
                            let progress = zone.0 + (zone.1 - zone.0) * t
                            let pos = sampler.position(for: progress, in: trackRect, laneOffset: 0)
                            Circle()
                                .fill(AppColor.green.opacity(0.35))
                                .frame(width: 5, height: 5)
                                .position(pos)
                        }
                    }
                } else {
                    Text("Track loading...")
                        .foregroundColor(.white.opacity(0.5))
                }

                ForEach(cars) { car in
                    let pose = markerPose(for: car, in: size, sampler: sampler)
                    VStack(spacing: 0) {
                        Text("\(car.position)")
                            .font(AppFont.custom(12, weight: .black))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                            .offset(y: -15)

                        ZStack {
                            if car.justOvertook {
                                Circle()
                                    .fill(AppColor.green.opacity(0.3))
                                    .frame(width: MarkerStyle.overtakeGlow, height: MarkerStyle.overtakeGlow)
                                    .blur(radius: 5)
                            } else if car.isOvertaking {
                                Circle()
                                    .fill(AppColor.gold.opacity(0.3))
                                    .frame(width: MarkerStyle.activeGlow, height: MarkerStyle.activeGlow)
                                    .blur(radius: 4)
                            }

                            if let carAsset = Self.carAsset {
                                RaceCarMarker(
                                    asset: carAsset,
                                    markerWidth: MarkerStyle.carWidth,
                                    fillColor: car.color
                                )
                                .rotationEffect(pose.angle)
                            } else {
                                Circle()
                                    .fill(car.color)
                                    .frame(width: 92, height: 92)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                car.justOvertook ? AppColor.green :
                                                car.isOvertaking ? AppColor.gold :
                                                Color.white.opacity(0.7),
                                                lineWidth: car.justOvertook || car.isOvertaking ? 2 : 1
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 2)
                            }
                        }
                    }
                    .position(pose.point)
                    .opacity(car.didDNF ? 0.25 : 1)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.1), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppColor.racingRed.opacity(0.3), Color.white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    private func position(for car: RaceCar, in size: CGSize, sampler: TrackPathSampler?) -> CGPoint {
        let rect = CGRect(origin: .zero, size: size)
        if let sampler = sampler {
            return sampler.position(for: car.progress, in: rect, laneOffset: CGFloat(car.laneOffset))
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func markerPose(for car: RaceCar, in size: CGSize, sampler: TrackPathSampler?) -> (point: CGPoint, angle: Angle) {
        let rect = CGRect(origin: .zero, size: size)
        guard let sampler = sampler else {
            return (CGPoint(x: rect.midX, y: rect.midY), .zero)
        }

        let fraction = CGFloat(car.progress.truncatingRemainder(dividingBy: 1.0))
        let (trackPoint, tangent) = sampler.pointAndAngle(at: fraction)
        let mapped = sampler.map(point: trackPoint, in: rect)
        let normal = CGPoint(x: -sin(tangent), y: cos(tangent))
        let positioned = CGPoint(
            x: mapped.x + normal.x * CGFloat(car.laneOffset),
            y: mapped.y + normal.y * CGFloat(car.laneOffset)
        )
        return (positioned, Angle(radians: Double(tangent)))
    }

}

private struct RaceCarMarker: View {
    let asset: SVGVectorAsset
    let markerWidth: CGFloat
    let fillColor: Color

    var body: some View {
        let sourceBounds = asset.path.boundingBoxOfPath
        let safeAspect = max(0.1, sourceBounds.width / max(sourceBounds.height, 0.1))
        let markerHeight = markerWidth / safeAspect

        SVGVectorShape(path: asset.path, viewBox: asset.viewBox, sourceRect: sourceBounds)
            .fill(fillColor)
            .frame(width: markerWidth, height: markerHeight)
            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
    }
}

private struct SVGVectorShape: Shape {
    let path: CGPath
    let viewBox: CGRect
    var sourceRect: CGRect? = nil

    func path(in rect: CGRect) -> Path {
        let reference: CGRect
        if let sourceRect, sourceRect.width > 0, sourceRect.height > 0 {
            reference = sourceRect
        } else {
            reference = viewBox
        }
        guard reference.width > 0, reference.height > 0 else { return Path(path) }

        let scale = min(rect.width / reference.width, rect.height / reference.height)
        let scaledWidth = reference.width * scale
        let scaledHeight = reference.height * scale
        let offsetX = rect.midX - (scaledWidth / 2)
        let offsetY = rect.midY - (scaledHeight / 2)

        var transform = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: offsetX - (reference.minX * scale),
            ty: offsetY - (reference.minY * scale)
        )
        guard let transformed = path.copy(using: &transform) else {
            return Path(path)
        }
        return Path(transformed)
    }
}

private struct StartFinishMarker: View {
    let angle: Angle

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { column in
                VStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { row in
                        Rectangle()
                            .fill((column + row).isMultiple(of: 2) ? Color.white : Color.black)
                    }
                }
            }
        }
        .frame(width: 20, height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 0.7)
        )
        .rotationEffect(angle)
        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

private struct RaceTopInfoBar: View {
    @ObservedObject var raceVM: RaceViewModel

    private var sessionClock: String {
        guard raceVM.raceStarted else { return "Pre-start" }
        let total = Int(raceVM.raceElapsedTime.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var liveGrip: Int {
        let elapsed = raceVM.raceStarted ? raceVM.raceElapsedTime : 0
        let wearDrop = Int(min(8.0, elapsed * 0.4))
        return max(84, raceVM.selectedTrack.baseGripPercent - wearDrop)
    }

    var body: some View {
        AdaptiveRaceInfoBar(
            items: [
                RaceInfoItem(id: "track", icon: "flag.checkered", title: "Track", value: raceVM.selectedTrack.rawValue),
                RaceInfoItem(id: "weather", icon: raceVM.selectedTrack.weatherIcon, title: "Weather", value: raceVM.selectedTrack.defaultWeather),
                RaceInfoItem(
                    id: "temps",
                    icon: "thermometer.medium",
                    title: "Air / Track",
                    value: "\(raceVM.selectedTrack.airTemperatureC)\u{00B0}C / \(raceVM.selectedTrack.trackTemperatureC)\u{00B0}C"
                ),
                RaceInfoItem(id: "grip", icon: "speedometer", title: "Grip", value: "\(liveGrip)%"),
                RaceInfoItem(id: "drs", icon: "dot.radiowaves.left.and.right", title: "DRS Zones", value: "\(raceVM.selectedTrack.drsZones.count)"),
                RaceInfoItem(id: "session", icon: "timer", title: "Session", value: sessionClock)
            ],
            minItemWidth: 130
        )
    }
}

private struct RaceBottomInfoBar: View {
    @ObservedObject var raceVM: RaceViewModel
    @ObservedObject var labVM: LabViewModel

    private func driverCode(for name: String) -> String {
        String(name.replacingOccurrences(of: " ", with: "").prefix(3)).uppercased()
    }

    private var activeCars: [RaceCar] {
        raceVM.raceCars.filter { !$0.finished && !$0.didDNF }
    }

    private var sortedActiveCars: [RaceCar] {
        activeCars.sorted { $0.position < $1.position }
    }

    private var leaderGapText: String {
        guard sortedActiveCars.count > 1 else { return "--" }
        let leader = sortedActiveCars[0]
        let second = sortedActiveCars[1]
        let refSpeed = max((leader.speed + second.speed) * 0.5, 0.001)
        let gap = max(0, (leader.progress - second.progress) / refSpeed)
        return String(format: "+%.2fs", gap)
    }

    private var predictedTop3Text: String {
        let top3 = Array(labVM.predictedTop3.prefix(3))
        guard !top3.isEmpty else { return "Run prediction in Lab" }
        return top3.map { driverCode(for: $0.name) }.joined(separator: " > ")
    }

    private var predictedWinnerText: String {
        guard let winner = labVM.predictedTop3.first else { return "--" }
        return driverCode(for: winner.name)
    }

    private var lastOvertakeText: String {
        guard let last = raceVM.raceNotes.last(where: { $0.contains("overtakes") }) else {
            return "No overtakes yet"
        }
        return last
    }

    var body: some View {
        AdaptiveRaceInfoBar(
            items: [
                RaceInfoItem(id: "leaderGap", icon: "person.fill.checkmark", title: "Leader Gap", value: leaderGapText),
                RaceInfoItem(
                    id: "predictionTop3",
                    icon: "list.number",
                    title: "Your Prediction",
                    value: predictedTop3Text
                ),
                RaceInfoItem(id: "predictedWinner", icon: "flag.checkered.circle", title: "Predicted Winner", value: predictedWinnerText),
                RaceInfoItem(id: "lastMove", icon: "arrow.left.arrow.right", title: "Last Move", value: lastOvertakeText)
            ],
            minItemWidth: 220
        )
    }
}

private struct RaceInfoItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
}

private struct AdaptiveRaceInfoBar: View {
    let items: [RaceInfoItem]
    let minItemWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let horizontalPadding: CGFloat = 16
            let availableWidth = max(0, geo.size.width - horizontalPadding)
            let requiredWidth = (CGFloat(items.count) * minItemWidth) + (CGFloat(max(items.count - 1, 0)) * spacing)
            let useEvenDistribution = availableWidth >= requiredWidth

            Group {
                if useEvenDistribution {
                    HStack(spacing: spacing) {
                        ForEach(items) { item in
                            RaceInfoChip(icon: item.icon, title: item.title, value: item.value)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(items) { item in
                                RaceInfoChip(icon: item.icon, title: item.title, value: item.value)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 62)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RaceInfoChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColor.gold)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.custom(8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(AppFont.custom(11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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

// MARK: - Race Side Panel

private enum TimingRowDensity {
    case full
    case compact
}

private struct RaceSidePanel: View {
    @ObservedObject var raceVM: RaceViewModel
    @ObservedObject var labVM: LabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if raceVM.isRaceActive && !raceVM.raceStarted {
                VStack(spacing: 20) {
                    Text("Race Starting")
                        .font(AppFont.custom(18, weight: .bold))
                        .foregroundColor(.white)

                    RaceStartLights(lightsOn: raceVM.startLightsOn)

                    Text(raceVM.startLightsOn < 5 ? "LIGHTS SEQUENCE" : "ALL LIGHTS ON")
                        .font(AppFont.custom(11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if raceVM.isRaceActive {
                Text("Live Timing")
                    .font(AppFont.custom(16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 4)

                let sorted = raceVM.raceCars.sorted { $0.position < $1.position }
                let leader = sorted.first
                let density: TimingRowDensity = sorted.count > 8 ? .compact : .full
                let shouldScroll = sorted.count > 12
                let orderSignature = sorted.map { "\($0.id.uuidString)-\($0.position)" }.joined(separator: "|")

                if shouldScroll {
                    ScrollView(showsIndicators: false) {
                        timingRows(sorted: sorted, leader: leader, density: density, orderSignature: orderSignature)
                    }
                } else {
                    timingRows(sorted: sorted, leader: leader, density: density, orderSignature: orderSignature)
                    Spacer(minLength: 0)
                }
            } else {
                // Pre-race: show predictions
                Text("Your Predicted Top-3")
                    .font(AppFont.custom(16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 4)

                ForEach(Array(labVM.predictedTop3.enumerated()), id: \.offset) { index, driver in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(AppFont.custom(12, weight: .bold))
                            .foregroundColor(AppColor.gold)
                            .frame(width: 18)
                        Circle()
                            .fill(driver.color)
                            .frame(width: 10, height: 10)
                        Text(driver.name)
                            .font(AppFont.custom(13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 6)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func timingRows(
        sorted: [RaceCar],
        leader: RaceCar?,
        density: TimingRowDensity,
        orderSignature: String
    ) -> some View {
        let spacing: CGFloat = density == .full ? 6 : 4
        VStack(spacing: spacing) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, car in
                RaceTimingRow(
                    index: index,
                    car: car,
                    leader: leader,
                    driverCode: driverCode(for: car.name),
                    density: density
                )
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: orderSignature)
    }

    private func driverCode(for name: String) -> String {
        let compact = name.replacingOccurrences(of: " ", with: "")
        return String(compact.prefix(3)).uppercased()
    }
}

private struct RaceStartLights: View {
    let lightsOn: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < lightsOn ? AppColor.racingRed : Color.white.opacity(0.12))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(index < lightsOn ? AppColor.racingRed.opacity(0.9) : Color.white.opacity(0.2), lineWidth: 1.5)
                    )
                    .shadow(color: index < lightsOn ? AppColor.racingRed.opacity(0.6) : .clear, radius: 6)
                    .animation(.easeInOut(duration: 0.2), value: lightsOn)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct RaceTimingRow: View {
    let index: Int
    let car: RaceCar
    let leader: RaceCar?
    let driverCode: String
    let density: TimingRowDensity

    private var speedKmh: Int {
        Int((car.speed * 6000).rounded())
    }

    private var gapText: String {
        guard index > 0, let leader else { return "LEADER" }
        let gapSec = max(0, (leader.progress - car.progress) / max(leader.speed, 0.001))
        return gapSec > 0.02 ? String(format: "+%.2fs", gapSec) : "<0.02s"
    }

    private var ersPercent: Int {
        Int((car.ersCharge * 100).rounded())
    }

    private var moveDelta: Int {
        car.previousPosition - car.position
    }

    private var movedUp: Bool {
        moveDelta > 0
    }

    private var movedDown: Bool {
        moveDelta < 0
    }

    private var ersLabel: String {
        if car.didDNF { return "OUT" }
        if car.finished { return "FIN" }
        if car.ersDeploying { return "ERS DEP" }
        if car.ersRecovering { return "ERS CHG" }
        return "ERS"
    }

    private var ersLabelColor: Color {
        if car.didDNF { return .red.opacity(0.9) }
        if car.finished { return AppColor.gold }
        if car.ersDeploying { return AppColor.orange }
        if car.ersRecovering { return AppColor.green }
        return .white.opacity(0.55)
    }

    private var rowFill: Color {
        if movedUp || car.justOvertook { return AppColor.green.opacity(0.12) }
        return index < 3 ? Color.white.opacity(0.11) : Color.white.opacity(0.04)
    }

    private var rowStroke: Color {
        if movedUp || car.justOvertook { return AppColor.green.opacity(0.5) }
        return index < 3 ? AppColor.gold.opacity(0.15) : Color.clear
    }

    private var isCompact: Bool {
        density == .compact
    }

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                fullBody
            }
        }
        .padding(.vertical, isCompact ? 3 : 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(rowStroke, lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: car.position)
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    private var fullBody: some View {
        HStack(spacing: 8) {
            positionBlock

            Rectangle()
                .fill(car.color)
                .frame(width: 3, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(driverCode)
                        .font(AppFont.custom(11, weight: .bold))
                        .foregroundColor(.white)
                    Text(car.name)
                        .font(AppFont.custom(10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(gapText)
                        .font(AppFont.custom(9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))

                    Text("L\(car.currentLap)")
                        .font(AppFont.custom(9, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))

                    drsBadge(fontSize: 8)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(speedKmh)")
                    .font(AppFont.custom(12, weight: .bold))
                    .foregroundColor(.white)
                Text("km/h")
                    .font(AppFont.custom(8, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(width: 48, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ersLabel)
                    .font(AppFont.custom(8, weight: .bold))
                    .foregroundColor(ersLabelColor)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: car.ersDeploying ? [AppColor.orange, AppColor.racingRed] : [AppColor.green, AppColor.gold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * car.ersCharge)
                    }
                }
                .frame(width: 52, height: 6)
                Text("\(ersPercent)%")
                    .font(AppFont.custom(8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 56, alignment: .trailing)
        }
    }

    private var compactBody: some View {
        HStack(spacing: 6) {
            positionBlock

            Rectangle()
                .fill(car.color)
                .frame(width: 3, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(driverCode)
                        .font(AppFont.custom(10, weight: .bold))
                        .foregroundColor(.white)
                    if movedUp || movedDown {
                        Text(movedUp ? "▲\(moveDelta)" : "▼\(-moveDelta)")
                            .font(AppFont.custom(7, weight: .bold))
                            .foregroundColor(movedUp ? AppColor.green : AppColor.racingRed)
                    }
                    Text(gapText)
                        .font(AppFont.custom(8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                HStack(spacing: 5) {
                    Text("L\(car.currentLap)")
                        .font(AppFont.custom(8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    drsBadge(fontSize: 7)
                    compactERSMeter
                }
            }

            Spacer(minLength: 4)

            Text("\(speedKmh)")
                .font(AppFont.custom(11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var compactERSMeter: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: car.ersDeploying ? [AppColor.orange, AppColor.racingRed] : [AppColor.green, AppColor.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * car.ersCharge)
                }
            }
            .frame(width: 24, height: 3)

            Text("\(ersPercent)%")
                .font(AppFont.custom(7, weight: .semibold))
                .foregroundColor(ersLabelColor)
        }
    }

    private var positionBlock: some View {
        VStack(spacing: 1) {
            Text("\(index + 1)")
                .font(AppFont.custom(isCompact ? 11 : 12, weight: .bold))
                .foregroundColor(index < 3 ? AppColor.gold : .white.opacity(0.8))
            if !isCompact {
                if movedUp || movedDown {
                    Text(movedUp ? "▲\(moveDelta)" : "▼\(-moveDelta)")
                        .font(AppFont.custom(8, weight: .bold))
                        .foregroundColor(movedUp ? AppColor.green : AppColor.racingRed)
                        .transition(.opacity)
                } else {
                    Color.clear.frame(width: 1, height: 8)
                }
            }
        }
        .frame(width: isCompact ? 14 : 18, alignment: .trailing)
    }

    private func drsBadge(fontSize: CGFloat) -> some View {
        Text("DRS")
            .font(AppFont.custom(fontSize, weight: .bold))
            .foregroundColor(car.drsActive ? AppColor.green : .white.opacity(0.35))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(car.drsActive ? AppColor.green.opacity(0.15) : Color.white.opacity(0.07))
            )
    }
}
