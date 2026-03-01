import SwiftUI

// MARK: - App Phase

enum AppPhase: Equatable {
    case welcome
    case lab
    case simulation
    case results
    case buildModel
}

// MARK: - Lab Step

enum LabStep: Int, CaseIterable {
    case modelSelection = 0
    case dataPlayground = 1
    case trackSelection = 2
    case dataQuality = 3
    case predict = 4

    var title: String {
        switch self {
        case .modelSelection: return "Model"
        case .dataPlayground: return "Data"
        case .trackSelection: return "Track"
        case .dataQuality: return "Quality"
        case .predict: return "Predict"
        }
    }

    var icon: String {
        switch self {
        case .modelSelection: return "cpu"
        case .dataPlayground: return "slider.horizontal.3"
        case .trackSelection: return "flag.checkered"
        case .dataQuality: return "waveform.path"
        case .predict: return "sparkles"
        }
    }
}

// MARK: - Model Type

enum ModelType: String, CaseIterable, Identifiable {
    case linearRegression = "Linear Regression"
    case decisionTree = "Decision Tree"
    case randomForest = "Random Forest"
    case knn = "K-Nearest Neighbors"
    case naiveBayes = "Naive Bayes"
    case neuralNetwork = "Neural Network"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .linearRegression: return "Linear"
        case .decisionTree: return "Tree"
        case .randomForest: return "Forest"
        case .knn: return "KNN"
        case .naiveBayes: return "Bayes"
        case .neuralNetwork: return "Neural"
        }
    }

    var icon: String {
        switch self {
        case .linearRegression: return "chart.xyaxis.line"
        case .decisionTree: return "point.topleft.down.to.point.bottomright.curvepath"
        case .randomForest: return "leaf.fill"
        case .knn: return "dot.radiowaves.left.and.right"
        case .naiveBayes: return "chart.bar.fill"
        case .neuralNetwork: return "brain"
        }
    }

    var summary: String {
        switch self {
        case .linearRegression:
            return "Finds the best straight-line fit through your data."
        case .decisionTree:
            return "Splits data with yes/no questions to classify drivers."
        case .randomForest:
            return "Combines many trees and averages their votes."
        case .knn:
            return "Finds the most similar drivers to predict outcomes."
        case .naiveBayes:
            return "Uses probability to predict based on feature likelihood."
        case .neuralNetwork:
            return "Learns patterns through layers of connected nodes."
        }
    }

    var detail: String {
        switch self {
        case .linearRegression:
            return "Great for clear trends, struggles with non-linear patterns."
        case .decisionTree:
            return "Easy to interpret, but can overfit noisy data."
        case .randomForest:
            return "More stable than a single tree, still sensitive to noise."
        case .knn:
            return "Simple and intuitive, but slows with many dimensions."
        case .naiveBayes:
            return "Fast and effective, assumes features are independent."
        case .neuralNetwork:
            return "Powerful pattern finder, but needs more data to shine."
        }
    }

    var accent: Color {
        switch self {
        case .linearRegression: return Color(red: 0.98, green: 0.71, blue: 0.22)
        case .decisionTree: return Color(red: 0.25, green: 0.75, blue: 0.56)
        case .randomForest: return Color(red: 0.23, green: 0.52, blue: 0.92)
        case .knn: return Color(red: 0.84, green: 0.32, blue: 0.48)
        case .naiveBayes: return Color(red: 0.58, green: 0.39, blue: 0.88)
        case .neuralNetwork: return Color(red: 0.95, green: 0.45, blue: 0.25)
        }
    }
}

// MARK: - Stat Column

enum StatColumn: String, CaseIterable, Identifiable {
    case qualifying = "Quali Position"
    case wins = "Wins"
    case trackWins = "Track Wins"
    case dnfs = "DNFs"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .qualifying: return "Quali"
        case .wins: return "Wins"
        case .trackWins: return "Track Wins"
        case .dnfs: return "DNFs"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .qualifying: return 1...20
        case .wins: return 0...60
        case .trackWins: return 0...8
        case .dnfs: return 0...15
        }
    }
}

// MARK: - Track Info

enum TrackInfo: String, CaseIterable, Identifiable {
    case monza = "Italy"
    case abuDhabi = "UAE"
    case greatBritain = "UK"

    var id: String { rawValue }

    var svgName: String {
        switch self {
        case .monza: return "italy"
        case .abuDhabi: return "abudhabi"
        case .greatBritain: return "greatbritain"
        }
    }

    var viewBox: CGSize {
        switch self {
        case .monza: return CGSize(width: 629.8, height: 1031.3)
        case .abuDhabi: return CGSize(width: 1546.2, height: 970.2)
        case .greatBritain: return CGSize(width: 587, height: 995.6)
        }
    }

    var subtitle: String {
        switch self {
        case .monza: return "High-Speed National Circuit"
        case .abuDhabi: return "Desert Night Circuit"
        case .greatBritain: return "Fast Flowing Circuit"
        }
    }

    var characteristics: String {
        switch self {
        case .monza: return "Long straights and heavy braking zones. Rewards top-end pace."
        case .abuDhabi: return "Mixed layout with traction zones and long acceleration phases."
        case .greatBritain: return "Flowing high-speed corners that reward stability and confidence."
        }
    }

    var icon: String {
        switch self {
        case .monza: return "bolt.fill"
        case .abuDhabi: return "sun.max.fill"
        case .greatBritain: return "cloud.rain.fill"
        }
    }

    var defaultWeather: String {
        switch self {
        case .monza: return "Clear"
        case .abuDhabi: return "Hot & Dry"
        case .greatBritain: return "Overcast"
        }
    }

    var weatherIcon: String {
        switch self {
        case .monza: return "sun.max.fill"
        case .abuDhabi: return "sun.haze.fill"
        case .greatBritain: return "cloud.fill"
        }
    }

    var airTemperatureC: Int {
        switch self {
        case .monza: return 27
        case .abuDhabi: return 34
        case .greatBritain: return 20
        }
    }

    var trackTemperatureC: Int {
        switch self {
        case .monza: return 41
        case .abuDhabi: return 48
        case .greatBritain: return 29
        }
    }

    var baseGripPercent: Int {
        switch self {
        case .monza: return 94
        case .abuDhabi: return 92
        case .greatBritain: return 90
        }
    }

    /// Feature weight modifiers per track — affects how the ML models weight features
    var featureModifiers: [String: Double] {
        switch self {
        case .monza:
            return ["Qualifying": 1.0, "Wins": 1.2, "Track Wins": 1.4, "DNFs": 1.0]
        case .abuDhabi:
            return ["Qualifying": 1.1, "Wins": 1.0, "Track Wins": 1.2, "DNFs": 1.1]
        case .greatBritain:
            return ["Qualifying": 1.3, "Wins": 0.9, "Track Wins": 1.3, "DNFs": 0.8]
        }
    }

    /// DRS zones as ranges of lap progress (0.0 - 1.0)
    var drsZones: [(Double, Double)] {
        switch self {
        case .monza:
            return [(0.15, 0.35), (0.7, 0.95)]
        case .abuDhabi:
            return [(0.05, 0.2), (0.55, 0.75)]
        case .greatBritain:
            return [(0.1, 0.25), (0.65, 0.8)]
        }
    }

    /// Corner zones as ranges of lap progress (0.0 - 1.0)
    var cornerZones: [(Double, Double)] {
        switch self {
        case .monza:
            return [(0.0, 0.1), (0.4, 0.5), (0.95, 1.0)]
        case .abuDhabi:
            return [(0.2, 0.35), (0.45, 0.55), (0.85, 0.95)]
        case .greatBritain:
            return [(0.0, 0.1), (0.3, 0.45), (0.5, 0.65), (0.85, 1.0)]
        }
    }
}

// MARK: - Noise Column Type

enum NoiseColumnType: String, CaseIterable, Identifiable {
    case favoriteColor = "Favorite Color"
    case luckyNumber = "Lucky Number"
    case birthMonth = "Birth Month"
    case shoeSize = "Shoe Size"
    case coffeePreference = "Coffee Preference"
    case zodiacSign = "Zodiac Sign"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .favoriteColor: return "paintpalette.fill"
        case .luckyNumber: return "number.circle.fill"
        case .birthMonth: return "calendar"
        case .shoeSize: return "shoeprints.fill"
        case .coffeePreference: return "cup.and.saucer.fill"
        case .zodiacSign: return "star.circle.fill"
        }
    }

    func randomValue() -> String {
        switch self {
        case .favoriteColor:
            return ["Red", "Blue", "Green", "Yellow", "Purple", "Orange"].randomElement()!
        case .luckyNumber:
            return "\(Int.random(in: 1...99))"
        case .birthMonth:
            return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].randomElement()!
        case .shoeSize:
            return "\(Int.random(in: 7...13))"
        case .coffeePreference:
            return ["Espresso", "Latte", "Cappuccino", "Americano", "None"].randomElement()!
        case .zodiacSign:
            return ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"].randomElement()!
        }
    }
}

// MARK: - Noise Column

struct NoiseColumn: Identifiable {
    let id = UUID()
    var type: NoiseColumnType
    var driverValues: [UUID: String] = [:]
}
