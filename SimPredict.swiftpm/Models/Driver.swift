import SwiftUI

struct Driver: Identifiable {
    let id: UUID
    var name: String
    var team: String
    var color: Color
    var qualifying: Int
    var wins: Int
    var trackWins: Int
    var dnfs: Int

    /// Extract feature values as an array for ML models
    func featureVector(maxDrivers: Int) -> [Double] {
        let qualiScore = Double(maxDrivers + 1 - qualifying)
        return [qualiScore, Double(wins), Double(trackWins), Double(dnfs)]
    }

    static let featureNames = ["Qualifying", "Wins", "Track Wins", "DNFs"]

    static func defaultDrivers() -> [Driver] {
        let roster = driverPool
        return roster.prefix(5).enumerated().map { index, item in
            Driver(
                id: UUID(),
                name: item.0,
                team: item.1,
                color: item.2,
                qualifying: index + 1,
                wins: Int.random(in: 3...38),
                trackWins: Int.random(in: 0...6),
                dnfs: Int.random(in: 0...6)
            )
        }
    }

    static let driverPool: [(String, String, Color)] = [
        ("Alex", "Aether Velocity Racing", Color(red: 0.0, green: 0.83, blue: 0.71)),
        ("Ben", "Aether Velocity Racing", Color(red: 0.0, green: 0.83, blue: 0.71)),
        ("Chloe", "Titan Apex Motorsport", Color(red: 0.13, green: 0.15, blue: 0.49)),
        ("Dan", "Titan Apex Motorsport", Color(red: 0.13, green: 0.15, blue: 0.49)),
        ("Emma", "Meridian GP Engineering", Color(red: 0.86, green: 0.0, blue: 0.0)),
        ("Finn", "Meridian GP Engineering", Color(red: 0.86, green: 0.0, blue: 0.0)),
        ("Grace", "Falcon Dynamics Racing", Color(red: 1.0, green: 0.55, blue: 0.0)),
        ("Hugo", "Falcon Dynamics Racing", Color(red: 1.0, green: 0.55, blue: 0.0)),
        ("Iris", "Nova Circuit Team", Color(red: 0.0, green: 0.42, blue: 0.28)),
        ("Jack", "Nova Circuit Team", Color(red: 0.0, green: 0.42, blue: 0.28)),
        ("Kai", "Atlas Performance Racing", Color(red: 0.0, green: 0.58, blue: 0.85)),
        ("Leo", "Atlas Performance Racing", Color(red: 0.0, green: 0.58, blue: 0.85)),
        ("Maya", "Zenith Racing Works", Color(red: 0.58, green: 0.39, blue: 0.88)),
        ("Nia", "Zenith Racing Works", Color(red: 0.58, green: 0.39, blue: 0.88)),
        ("Oli", "Stratos Drift Motorsport", Color(red: 0.98, green: 0.71, blue: 0.22)),
        ("Pia", "Stratos Drift Motorsport", Color(red: 0.98, green: 0.71, blue: 0.22)),
        ("Rae", "Vertex Grand Prix", Color(red: 0.72, green: 0.72, blue: 0.72)),
        ("Sam", "Vertex Grand Prix", Color(red: 0.72, green: 0.72, blue: 0.72)),
        ("Tia", "Horizon Prime Racing", Color(red: 0.84, green: 0.32, blue: 0.48)),
        ("Zoe", "Horizon Prime Racing", Color(red: 0.84, green: 0.32, blue: 0.48))
    ]
}
