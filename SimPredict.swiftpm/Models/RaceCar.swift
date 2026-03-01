import SwiftUI

struct RaceCar: Identifiable {
    let id: UUID
    var name: String
    var team: String
    var color: Color
    var progress: Double
    var speed: Double
    var baseSpeed: Double
    var dnfAtProgress: Double?
    var finished: Bool
    var didDNF: Bool
    var finishTime: Double?
    var laneOffset: Double
    var baseLaneOffset: Double  // Permanent visual spacing
    var gridOrder: Int
    var isOvertaking: Bool
    var overtakeBoost: Double
    var tireDegradation: Double
    var overtakingCooldown: Double
    var position: Int
    var previousPosition: Int
    var currentLap: Int
    var justOvertook: Bool
    var driverSkill: Double
    var overtakeAttemptCooldown: Double
    var overtakeTargetID: UUID?
    var overtakeElapsed: Double
    var overtakeLaneTarget: Double?
    var drsActive: Bool
    var drsBoost: Double
    var ersCharge: Double
    var ersDeploying: Bool
    var ersRecovering: Bool
}
