import SwiftUI

@MainActor
final class RaceViewModel: ObservableObject {
    @Published var raceCars: [RaceCar] = []
    @Published var raceNotes: [String] = []
    @Published var runCount: Int = 0
    @Published var isRaceActive: Bool = false
    @Published var raceElapsedTime: Double = 0
    @Published var raceStartCountdown: Int = 5
    @Published var startLightsOn: Int = 0
    @Published var raceStarted: Bool = false
    @Published var actualTop3: [Driver] = []
    @Published var selectedTrack: TrackInfo = .monza

    let maxRunCount = 3
    private var raceDriverSnapshotByID: [UUID: Driver] = [:]
    private var raceStartHoldDelay: Double = 0
    private enum RaceSpacing {
        static let desiredGapStraight: Double = 0.0115
        static let desiredGapCorner: Double = 0.0145
        static let attackGapStraight: Double = 0.0035
        static let attackGapCorner: Double = 0.0046
        static let noOverlapGap: Double = 0.0130
        static let overtakeOverlapGap: Double = 0.0022
        static let lanePassThreshold: Double = 7.2
        static let attackLaneDeltaDRS: Double = 9.2
        static let attackLaneDeltaStandard: Double = 8.0
        static let overtakeLaneSteerRate: Double = 0.62
        static let slipstreamStartGap: Double = 0.0080
        static let slipstreamEndGap: Double = 0.050
    }

    private enum LaunchPhase {
        static let duration: Double = 2.8
        static let baseFactor: Double = 0.62
        static let skillReactionWeight: Double = 0.22
        static let maxReactionDelay: Double = 0.34
    }

    func beginRace(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo, runAgain: Bool) {
        if runAgain {
            runCount = min(runCount + 1, maxRunCount)
        } else {
            runCount = 0
        }
        selectedTrack = track
        raceNotes = []
        raceDriverSnapshotByID = [:]
        raceCars = buildRaceCars(drivers: drivers, runCount: runCount)
        actualTop3 = []
        isRaceActive = true
        raceElapsedTime = 0
        raceStartCountdown = 5
        startLightsOn = 0
        raceStartHoldDelay = Double.random(in: 0.25...1.05)
        raceStarted = false
    }

    func tickRace(delta: Double) {
        guard isRaceActive else { return }

        if !raceStarted {
            raceElapsedTime += delta
            let lightInterval = 0.8
            let fullLightsTime = lightInterval * 5.0
            let newLights = min(5, max(0, Int(raceElapsedTime / lightInterval)))

            if newLights != startLightsOn {
                startLightsOn = newLights
                raceStartCountdown = max(0, 5 - startLightsOn)
                HapticsManager.shared.countdown()
            }

            if raceElapsedTime >= fullLightsTime + raceStartHoldDelay {
                startLightsOn = 0
                raceStarted = true
                raceElapsedTime = 0
                HapticsManager.shared.raceStart()
            }
            return
        }

        raceElapsedTime += delta

        // Pass 1: Update basic car state and check for DNF
        for index in raceCars.indices {
            if raceCars[index].finished { continue }
            raceCars[index].currentLap = min(3, Int(raceCars[index].progress) + 1)

            if let dnfPoint = raceCars[index].dnfAtProgress, raceCars[index].progress >= dnfPoint {
                raceCars[index].didDNF = true
                raceCars[index].finished = true
                raceCars[index].finishTime = raceElapsedTime
                raceCars[index].progress = dnfPoint
                raceCars[index].drsActive = false
                raceCars[index].ersDeploying = false
                raceCars[index].ersRecovering = false
                HapticsManager.shared.dnf()
                continue
            }

            if raceCars[index].overtakingCooldown > 0 {
                raceCars[index].overtakingCooldown -= delta
            }
            if raceCars[index].overtakeAttemptCooldown > 0 {
                raceCars[index].overtakeAttemptCooldown -= delta
            }
            if !raceCars[index].isOvertaking {
                raceCars[index].overtakeLaneTarget = nil
                raceCars[index].laneOffset = raceCars[index].baseLaneOffset
            }
            if raceCars[index].justOvertook && raceCars[index].overtakingCooldown <= 0 {
                raceCars[index].justOvertook = false
            }
        }

        // Pass 2: Determine current positions and gap to car ahead
        let activeCars = raceCars.enumerated().filter { !$0.element.finished && !$0.element.didDNF }
        let activeOrderBeforeByPosition = activeCars
            .sorted { $0.element.position < $1.element.position }
            .map(\.offset)
        let sortedByProgress = activeCars.sorted { $0.element.progress > $1.element.progress }
        let activeOrderBefore = sortedByProgress.map(\.offset)
        var gapToAheadSeconds = Array(repeating: Double.infinity, count: raceCars.count)
        for index in 1..<sortedByProgress.count {
            let ahead = sortedByProgress[index - 1]
            let behind = sortedByProgress[index]
            let gapProgress = ahead.element.progress - behind.element.progress
            let refSpeed = max((ahead.element.speed + behind.element.speed) * 0.5, 0.001)
            gapToAheadSeconds[behind.offset] = gapProgress / refSpeed
        }

        for index in raceCars.indices where !raceCars[index].finished {
            raceCars[index].drsActive = false
            raceCars[index].ersDeploying = false
        }

        // Pass 3: DRS/ERS strategy and overtake setup
        // Only one attacker can engage one defender at a time to avoid 3-wide pileups.
        var reservedDefenderIDs = Set<UUID>()
        for i in 1..<sortedByProgress.count {
            let attackerIndex = sortedByProgress[i].offset
            let defenderIndex = sortedByProgress[i - 1].offset
            let defenderID = raceCars[defenderIndex].id

            let gap = raceCars[defenderIndex].progress - raceCars[attackerIndex].progress
            let gapSeconds = gapToAheadSeconds[attackerIndex]
            let lapProgress = raceCars[attackerIndex].progress.truncatingRemainder(dividingBy: 1.0)
            let isDRSZone = isInDRSZone(lapProgress: lapProgress)
            let isCornerZone = isInCornerZone(lapProgress: lapProgress)
            let drsEnabledForRaceState = raceElapsedTime > 6.0
            let drsEligible = drsEnabledForRaceState
                && isDRSZone
                && gapSeconds.isFinite
                && gapSeconds > 0
                && gapSeconds <= 1.0
            let attackWindow = gapSeconds.isFinite && gapSeconds > 0 && gapSeconds < 3.6

            let wasTargetingThisDefender = raceCars[attackerIndex].overtakeTargetID == defenderID
            let defenderAlreadyReserved = reservedDefenderIDs.contains(defenderID)

            if raceCars[attackerIndex].isOvertaking && !wasTargetingThisDefender && raceCars[attackerIndex].overtakeElapsed > 0.2 {
                raceCars[attackerIndex].isOvertaking = false
                raceCars[attackerIndex].overtakeTargetID = nil
                raceCars[attackerIndex].overtakeElapsed = 0
                raceCars[attackerIndex].overtakeLaneTarget = nil
            }

                if drsEligible {
                    raceCars[attackerIndex].drsActive = true
                    if raceCars[attackerIndex].drsBoost < 0.0002 {
                        raceCars[attackerIndex].drsBoost = Double.random(in: 0.0007...0.0012)
                    }
                }

            if attackWindow && raceCars[attackerIndex].ersCharge > 0.12 && !isCornerZone {
                raceCars[attackerIndex].ersDeploying = true
            }
            if gapSeconds < 0.75 && raceCars[defenderIndex].ersCharge > 0.2 && !isCornerZone {
                raceCars[defenderIndex].ersDeploying = true
            }

            if gap > 0 && gap < 0.045 && (isDRSZone || attackWindow) && (!defenderAlreadyReserved || wasTargetingThisDefender) {
                let attackerSkill = raceCars[attackerIndex].driverSkill
                let defenderSkill = raceCars[defenderIndex].driverSkill
                let paceAdvantage = raceCars[attackerIndex].baseSpeed - raceCars[defenderIndex].baseSpeed
                let gapPressure = max(0, 1.0 - min(gapSeconds, 2.2) / 2.2)
                let eliteAttackerBonus = attackerSkill > 0.78 && raceCars[attackerIndex].position > 1 ? 0.24 : 0.0

                var overtakeChance = 0.32
                overtakeChance += (attackerSkill - defenderSkill) * 1.0
                overtakeChance += paceAdvantage * 420
                overtakeChance += gapPressure * 0.34
                overtakeChance += eliteAttackerBonus
                if drsEligible { overtakeChance += 0.40 }
                if raceCars[attackerIndex].ersDeploying { overtakeChance += 0.24 }
                if isCornerZone { overtakeChance -= 0.08 }
                overtakeChance += Double.random(in: -0.02...0.02)

                if !raceCars[attackerIndex].isOvertaking
                    && overtakeChance > 0.22
                    && raceCars[attackerIndex].overtakeAttemptCooldown <= 0 {
                    raceCars[attackerIndex].overtakeBoost = max(
                        raceCars[attackerIndex].overtakeBoost,
                        drsEligible ? 0.15 : 0.11
                    )
                    raceCars[attackerIndex].isOvertaking = true
                    raceCars[attackerIndex].overtakeTargetID = defenderID
                    raceCars[attackerIndex].overtakeElapsed = 0

                    let attackLaneDelta = drsEligible ? RaceSpacing.attackLaneDeltaDRS : RaceSpacing.attackLaneDeltaStandard
                    raceCars[attackerIndex].overtakeLaneTarget = raceCars[attackerIndex].baseLaneOffset + attackLaneDelta
                    raceCars[attackerIndex].overtakeAttemptCooldown = drsEligible ? 0.45 : 0.8
                }
            }

            if raceCars[attackerIndex].isOvertaking && raceCars[attackerIndex].overtakeTargetID == defenderID {
                reservedDefenderIDs.insert(defenderID)
            }

            if raceCars[attackerIndex].isOvertaking {
                let targetOffset = raceCars[attackerIndex].overtakeLaneTarget
                    ?? (raceCars[attackerIndex].baseLaneOffset + RaceSpacing.attackLaneDeltaStandard)
                let diff = targetOffset - raceCars[attackerIndex].laneOffset
                raceCars[attackerIndex].laneOffset += diff * RaceSpacing.overtakeLaneSteerRate
                if abs(diff) < 0.35 {
                    raceCars[attackerIndex].laneOffset = targetOffset
                }
            }

            // Return to base lane position after attack is resolved.
            if !raceCars[attackerIndex].isOvertaking {
                raceCars[attackerIndex].overtakeLaneTarget = nil
                raceCars[attackerIndex].laneOffset = raceCars[attackerIndex].baseLaneOffset
            }
        }

        // Pass 4: Update progress and speed
        for index in activeOrderBefore {
            if raceCars[index].finished || raceCars[index].didDNF { continue }

            let lapProgress = raceCars[index].progress.truncatingRemainder(dividingBy: 1.0)
            let isInCorner = isInCornerZone(lapProgress: lapProgress)
            let gapInfo = gapInfoForCar(index)
            let currentGap = gapInfo?.gapProgress ?? Double.infinity
            let aheadIndex = gapInfo?.aheadIndex ?? -1

            if raceCars[index].ersDeploying {
                raceCars[index].ersCharge = max(0, raceCars[index].ersCharge - 0.085 * delta)
                raceCars[index].ersRecovering = false
                if raceCars[index].ersCharge <= 0.08 {
                    raceCars[index].ersDeploying = false
                }
            } else {
                let recoveryRate = isInCorner ? 0.11 : 0.03
                raceCars[index].ersCharge = min(1, raceCars[index].ersCharge + recoveryRate * delta)
                raceCars[index].ersRecovering = recoveryRate > 0.06
            }

            if !raceCars[index].drsActive {
                raceCars[index].drsBoost *= 0.9
                if raceCars[index].drsBoost < 0.0002 {
                    raceCars[index].drsBoost = 0
                }
            }

            let degradationFactor = 1.0 - min(0.03, raceCars[index].progress * 0.0045)
            let randomFactor = 1.0 + Double.random(in: -0.004...0.004)
            let cornerMultiplier = isInCorner ? 0.62 : 1.0
            let overtakeMultiplier = 1.0 + raceCars[index].overtakeBoost
            let ersBonus = raceCars[index].ersDeploying ? 0.0014 : 0
            let drsBonus = raceCars[index].drsActive ? (raceCars[index].drsBoost + 0.00025) : 0
            var currentSpeed = raceCars[index].baseSpeed * degradationFactor * cornerMultiplier * randomFactor * overtakeMultiplier
            currentSpeed += ersBonus + drsBonus

            // Controlled launch to prevent "instant scatter" right after lights out.
            if raceElapsedTime < LaunchPhase.duration {
                let skillReaction = (1.0 - raceCars[index].driverSkill) * LaunchPhase.maxReactionDelay
                let reactionDelay = max(0, min(LaunchPhase.maxReactionDelay, skillReaction))
                let raw = (raceElapsedTime - reactionDelay) / LaunchPhase.duration
                let t = max(0, min(1, raw))
                let smooth = t * t * (3.0 - 2.0 * t)
                let launchFactor = LaunchPhase.baseFactor + (1.0 - LaunchPhase.baseFactor) * smooth
                currentSpeed *= launchFactor
                currentSpeed += raceCars[index].driverSkill * LaunchPhase.skillReactionWeight * 0.0012
            }

            let hasActivePass = raceCars[index].isOvertaking && raceCars[index].overtakeBoost > 0.006
            let isAttackState = hasActivePass || raceCars[index].justOvertook

            if currentGap.isFinite && !isInCorner
                && currentGap > RaceSpacing.slipstreamStartGap
                && currentGap < RaceSpacing.slipstreamEndGap {
                let slipstreamRatio = 1.0 - ((currentGap - RaceSpacing.slipstreamStartGap) / (RaceSpacing.slipstreamEndGap - RaceSpacing.slipstreamStartGap))
                let slipstream = 0.0016 * max(0, min(1, slipstreamRatio))
                currentSpeed += max(0, slipstream)
            }

            let desiredGap = isAttackState
                ? (isInCorner ? RaceSpacing.attackGapCorner : RaceSpacing.attackGapStraight)
                : (isInCorner ? RaceSpacing.desiredGapCorner : RaceSpacing.desiredGapStraight)
            if currentGap.isFinite && currentGap < desiredGap {
                let pressure = max(0, min(1, (desiredGap - currentGap) / desiredGap))
                if isAttackState {
                    currentSpeed *= (1.0 - 0.07 * pressure)
                } else {
                    currentSpeed *= (1.0 - 0.36 * pressure)
                }
            }

            if aheadIndex >= 0, currentGap.isFinite {
                let laneDelta = abs(raceCars[index].laneOffset - raceCars[aheadIndex].laneOffset)
                let isTargetingAhead = raceCars[index].overtakeTargetID == raceCars[aheadIndex].id
                let canUseParallelPassLane = laneDelta >= RaceSpacing.lanePassThreshold
                    && (isTargetingAhead || raceCars[index].isOvertaking)
                let minimumGap = canUseParallelPassLane ? RaceSpacing.overtakeOverlapGap : RaceSpacing.noOverlapGap
                if currentGap > 0 && currentGap < minimumGap {
                    let safeTail = raceCars[aheadIndex].progress - minimumGap
                    raceCars[index].progress = min(raceCars[index].progress, safeTail)
                    if !canUseParallelPassLane {
                        currentSpeed = min(currentSpeed, raceCars[aheadIndex].speed * 0.99)
                        currentSpeed *= 0.94
                    }
                }
            }

            let maxSpeed = isInCorner ? 0.033 : 0.051
            let baseMinSpeed = isInCorner ? 0.022 : 0.032
            let minSpeed: Double
            if currentGap.isFinite && currentGap < desiredGap && !hasActivePass {
                minSpeed = isInCorner ? 0.007 : 0.010
            } else {
                minSpeed = baseMinSpeed
            }
            currentSpeed = min(maxSpeed, max(minSpeed, currentSpeed))

            raceCars[index].speed = currentSpeed
            raceCars[index].progress += currentSpeed * delta

            if raceCars[index].isOvertaking {
                raceCars[index].overtakeElapsed += delta
                if let targetID = raceCars[index].overtakeTargetID,
                    let targetIndex = raceCars.firstIndex(where: { $0.id == targetID }),
                    !raceCars[targetIndex].didDNF,
                    !raceCars[targetIndex].finished {
                    let gapToTarget = raceCars[targetIndex].progress - raceCars[index].progress
                    if gapToTarget <= -0.0002 {
                        raceCars[index].isOvertaking = false
                        raceCars[index].overtakeTargetID = nil
                        raceCars[index].overtakeElapsed = 0
                        raceCars[index].overtakeLaneTarget = nil
                    } else if raceCars[index].overtakeElapsed >= 0.65 {
                        if gapToTarget < 0.009 {
                            raceCars[index].progress = max(
                                raceCars[index].progress,
                                raceCars[targetIndex].progress + (RaceSpacing.overtakeOverlapGap * 0.9)
                            )
                            raceCars[index].overtakeBoost = max(raceCars[index].overtakeBoost, 0.02)
                        } else {
                            raceCars[index].overtakeBoost *= 0.5
                        }
                        raceCars[index].isOvertaking = false
                        raceCars[index].overtakeTargetID = nil
                        raceCars[index].overtakeElapsed = 0
                        raceCars[index].overtakeLaneTarget = nil
                    }
                } else {
                    raceCars[index].isOvertaking = false
                    raceCars[index].overtakeTargetID = nil
                    raceCars[index].overtakeElapsed = 0
                    raceCars[index].overtakeLaneTarget = nil
                }
            } else {
                raceCars[index].overtakeElapsed = 0
                if raceCars[index].overtakeBoost == 0 {
                    raceCars[index].overtakeTargetID = nil
                }
            }

            if raceCars[index].overtakeBoost > 0 {
                raceCars[index].overtakeBoost *= 0.94
                if raceCars[index].overtakeBoost < 0.005 {
                    raceCars[index].overtakeBoost = 0
                }
            }

            if raceCars[index].progress >= 3.0 {
                raceCars[index].progress = 3.0
                raceCars[index].finished = true
                raceCars[index].finishTime = raceElapsedTime
            }
        }

        // Final position update for this tick
        let passThreshold = 0.00035
        let sortedByRaceOrder = raceCars.indices.sorted { lhs, rhs in
            let left = raceCars[lhs]
            let right = raceCars[rhs]
            if left.finished || right.finished || left.didDNF || right.didDNF {
                return raceOrderKey(for: left) < raceOrderKey(for: right)
            }

            let diff = left.progress - right.progress
            if abs(diff) > passThreshold {
                return diff > 0
            }
            return left.position < right.position
        }

        var nextPositions: [(Int, Int)] = []
        var didPositionChange = false
        for (position, index) in sortedByRaceOrder.enumerated() {
            let newPosition = position + 1
            if raceCars[index].position != newPosition {
                didPositionChange = true
            }
            nextPositions.append((index, newPosition))
        }

        if didPositionChange {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                for (index, newPosition) in nextPositions {
                    raceCars[index].previousPosition = raceCars[index].position
                    raceCars[index].position = newPosition
                }
            }
        } else {
            for (index, newPosition) in nextPositions {
                raceCars[index].previousPosition = raceCars[index].position
                raceCars[index].position = newPosition
            }
        }

        let activeOrderAfterByPosition = raceCars.enumerated()
            .filter { !$0.element.finished && !$0.element.didDNF }
            .sorted { $0.element.position < $1.element.position }
            .map(\.offset)

        emitOvertakeEvents(before: activeOrderBeforeByPosition, after: activeOrderAfterByPosition)

        if raceCars.allSatisfy({ $0.finished }) {
            HapticsManager.shared.raceFinish()
            finalizeRace()
        }
    }

    func finalizeRace() {
        isRaceActive = false
        let sorted = raceCars.sorted { raceOrderKey(for: $0) < raceOrderKey(for: $1) }
        actualTop3 = sorted.prefix(3).map { car in
            raceDriverSnapshotByID[car.id] ??
            Driver(
                id: car.id,
                name: car.name,
                team: car.team,
                color: car.color,
                qualifying: 0,
                wins: 0,
                trackWins: 0,
                dnfs: 0
            )
        }
    }

    // MARK: - Track Zone Helpers

    private func isInDRSZone(lapProgress: Double) -> Bool {
        selectedTrack.drsZones.contains { zone in
            lapProgress >= zone.0 && lapProgress <= zone.1
        }
    }

    private func isInCornerZone(lapProgress: Double) -> Bool {
        selectedTrack.cornerZones.contains { zone in
            lapProgress >= zone.0 && lapProgress <= zone.1
        }
    }

    private func raceOrderKey(for car: RaceCar) -> (Int, Double, Int) {
        if car.didDNF {
            return (2, car.finishTime ?? Double.greatestFiniteMagnitude, car.gridOrder)
        }
        if car.finished {
            return (0, car.finishTime ?? Double.greatestFiniteMagnitude, car.gridOrder)
        }
        return (1, -car.progress, car.gridOrder)
    }

    private func emitOvertakeEvents(before: [Int], after: [Int]) {
        guard before.count > 1, after.count > 1 else { return }
        var beforeIndexByCar: [Int: Int] = [:]
        for (index, carIndex) in before.enumerated() {
            beforeIndexByCar[carIndex] = index
        }

        for index in 0..<(after.count - 1) {
            let leadIndex = after[index]
            let trailIndex = after[index + 1]
            guard let beforeLead = beforeIndexByCar[leadIndex], let beforeTrail = beforeIndexByCar[trailIndex] else { continue }
            guard beforeLead > beforeTrail else { continue }
            guard raceCars[leadIndex].overtakingCooldown <= 0 else { continue }

            raceCars[leadIndex].justOvertook = true
            raceCars[leadIndex].overtakingCooldown = 1.2
            let settleLane = raceCars[leadIndex].baseLaneOffset
            raceCars[leadIndex].laneOffset += (settleLane - raceCars[leadIndex].laneOffset) * 0.5
            HapticsManager.shared.overtake()

            let event = "\(raceCars[leadIndex].name) overtakes \(raceCars[trailIndex].name)"
            if raceNotes.last != event {
                raceNotes.append(event)
            }
        }
    }

    private func gapInfoForCar(_ carIndex: Int) -> (aheadIndex: Int, gapProgress: Double, gapSeconds: Double)? {
        guard raceCars.indices.contains(carIndex) else { return nil }
        let car = raceCars[carIndex]
        guard !car.finished && !car.didDNF else { return nil }

        var bestGap = Double.greatestFiniteMagnitude
        var bestIndex = -1

        for (index, other) in raceCars.enumerated() {
            if index == carIndex || other.finished || other.didDNF { continue }
            let gap = other.progress - car.progress
            if gap > 0 && gap < bestGap {
                bestGap = gap
                bestIndex = index
            }
        }

        guard bestIndex >= 0 else { return nil }
        let ahead = raceCars[bestIndex]
        let refSpeed = max((ahead.speed + car.speed) * 0.5, 0.001)
        return (bestIndex, bestGap, bestGap / refSpeed)
    }

    // MARK: - Build Race Cars

    private func buildRaceCars(drivers: [Driver], runCount: Int) -> [RaceCar] {
        let workingDrivers = drivers

        var snapshot: [UUID: Driver] = [:]
        for driver in workingDrivers {
            snapshot[driver.id] = driver
        }
        raceDriverSnapshotByID = snapshot

        let scores = workingDrivers.map { trueRaceScore($0, maxDrivers: workingDrivers.count, runCount: runCount) }
        let minScore = scores.min() ?? 0
        let maxScore = scores.max() ?? 1

        let eventCount = runCount > 0 ? Int.random(in: 0...1) : 0
        var dnfDrivers = Set<UUID>()
        if eventCount > 0 {
            var pool = workingDrivers.shuffled()
            for _ in 0..<eventCount {
                guard let pick = pool.popLast() else { break }
                dnfDrivers.insert(pick.id)
            }
        }

        return workingDrivers.enumerated().map { (index, driver) in
            let score = scores[index]
            let normalized = (score - minScore) / (maxScore - minScore + 0.01)
            // Performance spread tuned to preserve raceability while still rewarding stronger drivers.
            let baseSpeed = 0.0436 + (normalized * 0.0048)
            let driverSkill = 0.3 + (normalized * 0.7)
            // Better qualifying starts further ahead on the opening grid.
            let startOffset = Double(max(workingDrivers.count - driver.qualifying, 0)) * 0.0045

            let dnfPoint: Double?
            if dnfDrivers.contains(driver.id) {
                dnfPoint = Double.random(in: 1.3...2.4)
                raceNotes.append("Mechanical issue: \(driver.name)")
            } else {
                dnfPoint = nil
            }

            // Keep all cars centered by default; temporary lane offsets are used only during overtakes.
            let baseOffset = 0.0

            return RaceCar(
                id: driver.id,
                name: driver.name,
                team: driver.team,
                color: driver.color,
                progress: startOffset,
                speed: baseSpeed,
                baseSpeed: baseSpeed,
                dnfAtProgress: dnfPoint,
                finished: false,
                didDNF: false,
                finishTime: nil,
                laneOffset: baseOffset,
                baseLaneOffset: baseOffset,
                gridOrder: index,
                isOvertaking: false,
                overtakeBoost: 0.0,
                tireDegradation: 1.0,
                overtakingCooldown: 0.0,
                position: index + 1,
                previousPosition: index + 1,
                currentLap: 1,
                justOvertook: false,
                driverSkill: driverSkill,
                overtakeAttemptCooldown: 0.0,
                overtakeTargetID: nil,
                overtakeElapsed: 0.0,
                overtakeLaneTarget: nil,
                drsActive: false,
                drsBoost: 0.0,
                ersCharge: Double.random(in: 0.65...0.95),
                ersDeploying: false,
                ersRecovering: false
            )
        }
    }

    private func trueRaceScore(_ driver: Driver, maxDrivers: Int, runCount: Int) -> Double {
        let modifiers = selectedTrack.featureModifiers
        let qualiNorm = Double(maxDrivers + 1 - driver.qualifying) / Double(max(maxDrivers, 1))
        let winsNorm = Double(driver.wins) / 60.0
        let trackWinsNorm = Double(driver.trackWins) / 8.0
        let dnfNorm = Double(driver.dnfs) / 15.0

        let qualifyingWeight = 0.38 * (modifiers["Qualifying"] ?? 1.0)
        let winsWeight = 0.33 * (modifiers["Wins"] ?? 1.0)
        let trackWeight = 0.23 * (modifiers["Track Wins"] ?? 1.0)
        let dnfWeight = 0.28 * (modifiers["DNFs"] ?? 1.0)

        let raw = (qualiNorm * qualifyingWeight)
            + (winsNorm * winsWeight)
            + (trackWinsNorm * trackWeight)
            - (dnfNorm * dnfWeight)
            + ((1.0 - dnfNorm) * 0.06)

        let bounded = max(0.02, min(1.2, raw))
        let varianceRange = runCount == 0 ? 0.012 : 0.02
        let raceVariance = Double.random(in: -varianceRange...varianceRange)
        return bounded + raceVariance
    }
}
