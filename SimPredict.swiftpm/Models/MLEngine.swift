import Foundation

// MARK: - ML Model Protocol

protocol MLModel {
    var type: ModelType { get }
    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo)
    func predict(driver: Driver) -> Double
    func featureImportances() -> [(String, Double)]
    func explanation(for driver: Driver) -> String
}

// MARK: - Helper: Feature Extraction

struct FeatureExtractor {
    static func features(for driver: Driver, maxDrivers: Int, noiseColumns: [NoiseColumn], track: TrackInfo) -> [Double] {
        let qualiScore = Double(maxDrivers + 1 - driver.qualifying)
        let modifiers = track.featureModifiers
        var features = [
            qualiScore * (modifiers["Qualifying"] ?? 1.0),
            Double(driver.wins) * (modifiers["Wins"] ?? 1.0),
            Double(driver.trackWins) * (modifiers["Track Wins"] ?? 1.0),
            Double(driver.dnfs) * (modifiers["DNFs"] ?? 1.0)
        ]
        for column in noiseColumns {
            let value = column.driverValues[driver.id] ?? ""
            features.append(noiseToNumeric(value, name: driver.name))
        }
        return features
    }

    static func featureNames(noiseColumns: [NoiseColumn]) -> [String] {
        var names = Driver.featureNames
        for column in noiseColumns {
            names.append(column.type.rawValue)
        }
        return names
    }

    static func compositeTarget(for driver: Driver, maxDrivers: Int) -> Double {
        let q = Double(maxDrivers + 1 - driver.qualifying)
        let w = Double(driver.wins)
        let tw = Double(driver.trackWins)
        let d = Double(driver.dnfs)
        return q * 0.4 + w * 0.3 + tw * 0.2 - d * 0.1
    }

    private static func noiseToNumeric(_ value: String, name: String) -> Double {
        let combined = value + name
        var hash = 0
        for scalar in combined.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) % 100000
        }
        return Double(hash % 2000) / 1000.0 - 1.0
    }
}

// MARK: - 1. Linear Regression

struct LinearRegressionModel: MLModel {
    let type: ModelType = .linearRegression
    private var weights: [Double] = []
    private var names: [String] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        self.names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)

        let n = drivers.count
        let p = names.count
        guard n > 0 && p > 0 else { weights = Array(repeating: 1.0, count: p); return }

        // Build X matrix and y vector
        var X = [[Double]]()
        var y = [Double]()
        for driver in drivers {
            X.append(FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track))
            y.append(FeatureExtractor.compositeTarget(for: driver, maxDrivers: maxDrivers))
        }

        // Normal equation: w = (X^T X + lambda*I)^{-1} X^T y  (ridge regression for stability)
        let lambda = 0.01
        var XtX = Array(repeating: Array(repeating: 0.0, count: p), count: p)
        var Xty = Array(repeating: 0.0, count: p)

        for i in 0..<n {
            for j in 0..<p {
                Xty[j] += X[i][j] * y[i]
                for k in 0..<p {
                    XtX[j][k] += X[i][j] * X[i][k]
                }
            }
        }

        // Add ridge regularization
        for j in 0..<p {
            XtX[j][j] += lambda
        }

        // Solve via Gauss-Jordan elimination
        weights = solveLinearSystem(XtX, Xty) ?? Array(repeating: 1.0 / Double(p), count: p)
    }

    func predict(driver: Driver) -> Double {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        return zip(features, weights).map(*).reduce(0, +)
    }

    func featureImportances() -> [(String, Double)] {
        zip(names, weights).map { ($0, $1) }
    }

    func explanation(for driver: Driver) -> String {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        let score = predict(driver: driver)
        var parts: [String] = []
        for i in 0..<min(names.count, weights.count) {
            parts.append(String(format: "%@(%.1f) x %.2f", names[i], features[i], weights[i]))
        }
        return String(format: "Score: %.2f\n%@", score, parts.joined(separator: " + "))
    }
}

// MARK: - 2. Decision Tree

indirect enum TreeNode {
    case leaf(score: Double, count: Int, driverNames: [String])
    case split(feature: String, featureIndex: Int, threshold: Double, left: TreeNode, right: TreeNode)

    func predict(features: [Double]) -> Double {
        switch self {
        case .leaf(let score, _, _):
            return score
        case .split(_, let idx, let threshold, let left, let right):
            return features[idx] <= threshold ? left.predict(features: features) : right.predict(features: features)
        }
    }

    func path(for features: [Double]) -> [String] {
        switch self {
        case .leaf(let score, _, _):
            return [String(format: "Leaf: score = %.2f", score)]
        case .split(let name, let idx, let threshold, let left, let right):
            let goLeft = features[idx] <= threshold
            let direction = goLeft ? "Yes" : "No"
            let condition = String(format: "%@ <= %.1f? %@", name, threshold, direction)
            let subtree = goLeft ? left.path(for: features) : right.path(for: features)
            return [condition] + subtree
        }
    }
}

struct DecisionTreeModel: MLModel {
    let type: ModelType = .decisionTree
    var root: TreeNode?
    private var names: [String] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza
    var maxDepth: Int = 3

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        self.names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)

        var data: [([Double], Double, String)] = drivers.map { driver in
            let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
            let target = FeatureExtractor.compositeTarget(for: driver, maxDrivers: maxDrivers)
            return (features, target, driver.name)
        }
        root = buildTree(data: &data, depth: 0)
    }

    private func buildTree(data: inout [([Double], Double, String)], depth: Int) -> TreeNode {
        let targets = data.map { $0.1 }
        let mean = targets.reduce(0, +) / max(Double(targets.count), 1)
        let driverNames = data.map { $0.2 }

        guard data.count >= 2 && depth < maxDepth else {
            return .leaf(score: mean, count: data.count, driverNames: driverNames)
        }

        let totalVariance = variance(targets)
        guard totalVariance > 0.001 else {
            return .leaf(score: mean, count: data.count, driverNames: driverNames)
        }

        var bestGain = 0.0
        var bestFeature = 0
        var bestThreshold = 0.0

        let featureCount = data.first?.0.count ?? 0
        for f in 0..<featureCount {
            let values = Set(data.map { $0.0[f] }).sorted()
            for i in 0..<max(values.count - 1, 0) {
                let threshold = (values[i] + values[i + 1]) / 2.0
                let left = data.filter { $0.0[f] <= threshold }.map { $0.1 }
                let right = data.filter { $0.0[f] > threshold }.map { $0.1 }
                guard !left.isEmpty && !right.isEmpty else { continue }

                let weightedVariance = (Double(left.count) * variance(left) + Double(right.count) * variance(right)) / Double(data.count)
                let gain = totalVariance - weightedVariance
                if gain > bestGain {
                    bestGain = gain
                    bestFeature = f
                    bestThreshold = threshold
                }
            }
        }

        guard bestGain > 0.001 else {
            return .leaf(score: mean, count: data.count, driverNames: driverNames)
        }

        var leftData = data.filter { $0.0[bestFeature] <= bestThreshold }
        var rightData = data.filter { $0.0[bestFeature] > bestThreshold }

        let featureName = bestFeature < names.count ? names[bestFeature] : "Feature \(bestFeature)"
        let leftNode = buildTree(data: &leftData, depth: depth + 1)
        let rightNode = buildTree(data: &rightData, depth: depth + 1)

        return .split(feature: featureName, featureIndex: bestFeature, threshold: bestThreshold, left: leftNode, right: rightNode)
    }

    func predict(driver: Driver) -> Double {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        return root?.predict(features: features) ?? 0
    }

    func featureImportances() -> [(String, Double)] {
        guard let root = root else { return [] }
        var importance = [String: Double]()
        collectImportance(node: root, depth: 0, importance: &importance)

        let maxImp = importance.values.max() ?? 1
        return names.map { name in
            (name, (importance[name] ?? 0) / max(maxImp, 0.001) * 2.0)
        }
    }

    private func collectImportance(node: TreeNode, depth: Int, importance: inout [String: Double]) {
        if case .split(let name, _, _, let left, let right) = node {
            let weight = pow(2.0, -Double(depth))
            importance[name, default: 0] += weight
            collectImportance(node: left, depth: depth + 1, importance: &importance)
            collectImportance(node: right, depth: depth + 1, importance: &importance)
        }
    }

    func explanation(for driver: Driver) -> String {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        let path = root?.path(for: features) ?? []
        let score = predict(driver: driver)
        return String(format: "Score: %.2f\nPath: %@", score, path.joined(separator: " -> "))
    }
}

// MARK: - 3. Random Forest

struct RandomForestModel: MLModel {
    let type: ModelType = .randomForest
    var trees: [DecisionTreeModel] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza
    let treeCount = 5

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        trees = []

        for _ in 0..<treeCount {
            // Bootstrap sample (70% of drivers with replacement)
            let sampleSize = max(Int(Double(drivers.count) * 0.7), 2)
            let sample = (0..<sampleSize).map { _ in drivers.randomElement()! }

            // Build tree with subset (max depth 2 for individual trees)
            var tree = DecisionTreeModel()
            tree.maxDepth = 2
            tree.train(drivers: sample, noiseColumns: noiseColumns, track: track)
            trees.append(tree)
        }
    }

    func predict(driver: Driver) -> Double {
        guard !trees.isEmpty else { return 0 }
        let predictions = trees.map { $0.predict(driver: driver) }
        return predictions.reduce(0, +) / Double(predictions.count)
    }

    func featureImportances() -> [(String, Double)] {
        guard !trees.isEmpty else { return [] }
        let names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)
        var combined = [String: Double]()

        for tree in trees {
            for (name, weight) in tree.featureImportances() {
                combined[name, default: 0] += weight
            }
        }

        return names.map { name in
            (name, (combined[name] ?? 0) / Double(trees.count))
        }
    }

    func explanation(for driver: Driver) -> String {
        let treePredictions = trees.enumerated().map { (i, tree) in
            String(format: "Tree %d: %.2f", i + 1, tree.predict(driver: driver))
        }
        let avg = predict(driver: driver)
        return String(format: "Score: %.2f (average of %d trees)\n%@", avg, trees.count, treePredictions.joined(separator: ", "))
    }
}

// MARK: - 4. K-Nearest Neighbors

struct KNNModel: MLModel {
    let type: ModelType = .knn
    var k: Int = 3
    private var trainData: [([Double], Double, String)] = []
    private var names: [String] = []
    private var minValues: [Double] = []
    private var maxValues: [Double] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        self.names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)

        trainData = drivers.map { driver in
            let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
            let target = FeatureExtractor.compositeTarget(for: driver, maxDrivers: maxDrivers)
            return (features, target, driver.name)
        }

        // Compute min/max for normalization
        let featureCount = trainData.first?.0.count ?? 0
        minValues = (0..<featureCount).map { f in trainData.map { $0.0[f] }.min() ?? 0 }
        maxValues = (0..<featureCount).map { f in trainData.map { $0.0[f] }.max() ?? 1 }
    }

    func predict(driver: Driver) -> Double {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        var neighbors = nearestNeighbors(features: features, k: k, excludingName: driver.name)
        if neighbors.isEmpty {
            neighbors = nearestNeighbors(features: features, k: k)
        }
        guard !neighbors.isEmpty else { return 0 }

        var weightedSum = 0.0
        var totalWeight = 0.0
        for (_, target, dist) in neighbors {
            let weight = 1.0 / max(dist, 0.001)
            weightedSum += target * weight
            totalWeight += weight
        }
        return weightedSum / max(totalWeight, 0.001)
    }

    func nearestNeighbors(features: [Double], k: Int, excludingName: String? = nil) -> [(String, Double, Double)] {
        let normalized = normalize(features)
        let distances = trainData.compactMap { (data, target, name) -> (String, Double, Double)? in
            if let excludingName, excludingName == name {
                return nil
            }
            let normalizedData = normalize(data)
            let dist = euclideanDistance(normalized, normalizedData)
            return (name, target, dist)
        }
        let clampedK = min(max(1, k), distances.count)
        guard clampedK > 0 else { return [] }
        return Array(distances.sorted { $0.2 < $1.2 }.prefix(clampedK))
    }

    func featureImportances() -> [(String, Double)] {
        // KNN treats all features equally in distance
        names.map { ($0, 1.0) }
    }

    func explanation(for driver: Driver) -> String {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        var neighbors = nearestNeighbors(features: features, k: k, excludingName: driver.name)
        if neighbors.isEmpty {
            neighbors = nearestNeighbors(features: features, k: k)
        }
        let score = predict(driver: driver)
        let neighborDescs = neighbors.map { String(format: "%@ (dist: %.2f)", $0.0, $0.2) }
        return String(format: "Score: %.2f\nK=%d nearest: %@", score, k, neighborDescs.joined(separator: ", "))
    }

    private func normalize(_ features: [Double]) -> [Double] {
        features.enumerated().map { i, v in
            let range = maxValues[i] - minValues[i]
            return range > 0.001 ? (v - minValues[i]) / range : 0.5
        }
    }

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        let sumSq = zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        return sqrt(sumSq)
    }
}

// MARK: - 5. Naive Bayes

struct NaiveBayesModel: MLModel {
    let type: ModelType = .naiveBayes
    private var names: [String] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza
    private var podiumLikelihoods: [[String: Double]] = []  // P(bin | podium) per feature
    private var nonPodiumLikelihoods: [[String: Double]] = []
    private var priorPodium: Double = 0.3
    private var binEdges: [[Double]] = []

    mutating func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        self.names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)

        let allFeatures = drivers.map { FeatureExtractor.features(for: $0, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track) }
        let targets = drivers.map { FeatureExtractor.compositeTarget(for: $0, maxDrivers: maxDrivers) }

        // Determine podium (top 3) vs non-podium
        let sortedIndices = targets.enumerated().sorted { $0.element > $1.element }.map { $0.offset }
        let podiumSet = Set(sortedIndices.prefix(3))

        let podiumCount = podiumSet.count
        priorPodium = Double(podiumCount) / Double(drivers.count)

        // Compute tercile bin edges for each feature
        let featureCount = allFeatures.first?.count ?? 0
        binEdges = (0..<featureCount).map { f in
            let values = allFeatures.map { $0[f] }.sorted()
            guard values.count >= 3 else { return [values.first ?? 0, values.last ?? 1] }
            let t1 = values[values.count / 3]
            let t2 = values[2 * values.count / 3]
            return [t1, t2]
        }

        // Compute likelihoods with Laplace smoothing
        podiumLikelihoods = []
        nonPodiumLikelihoods = []

        for f in 0..<featureCount {
            var podiumBins = ["Low": 1.0, "Medium": 1.0, "High": 1.0]
            var nonPodiumBins = ["Low": 1.0, "Medium": 1.0, "High": 1.0]

            for (i, features) in allFeatures.enumerated() {
                let bin = discretize(features[f], featureIndex: f)
                if podiumSet.contains(i) {
                    podiumBins[bin, default: 1.0] += 1
                } else {
                    nonPodiumBins[bin, default: 1.0] += 1
                }
            }

            let podiumTotal = podiumBins.values.reduce(0, +)
            let nonPodiumTotal = nonPodiumBins.values.reduce(0, +)

            podiumLikelihoods.append(podiumBins.mapValues { $0 / podiumTotal })
            nonPodiumLikelihoods.append(nonPodiumBins.mapValues { $0 / nonPodiumTotal })
        }
    }

    func predict(driver: Driver) -> Double {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)

        var logPodium = log(max(priorPodium, 0.001))
        var logNonPodium = log(max(1 - priorPodium, 0.001))

        for (f, value) in features.enumerated() {
            guard f < podiumLikelihoods.count else { continue }
            let bin = discretize(value, featureIndex: f)
            logPodium += log(max(podiumLikelihoods[f][bin] ?? 0.1, 0.001))
            logNonPodium += log(max(nonPodiumLikelihoods[f][bin] ?? 0.1, 0.001))
        }

        // Return posterior probability of podium (higher = better)
        let maxLog = max(logPodium, logNonPodium)
        let podiumProb = exp(logPodium - maxLog)
        let nonPodiumProb = exp(logNonPodium - maxLog)
        return podiumProb / (podiumProb + nonPodiumProb) * 100
    }

    func posteriorComponents(for driver: Driver) -> [(String, String, Double)] {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        var result: [(String, String, Double)] = []
        for (f, value) in features.enumerated() {
            guard f < podiumLikelihoods.count else { continue }
            let bin = discretize(value, featureIndex: f)
            let likelihood = podiumLikelihoods[f][bin] ?? 0.1
            let name = f < names.count ? names[f] : "Feature \(f)"
            result.append((name, bin, likelihood))
        }
        return result
    }

    func featureImportances() -> [(String, Double)] {
        var importances: [(String, Double)] = []
        for (f, name) in names.enumerated() {
            guard f < podiumLikelihoods.count && f < nonPodiumLikelihoods.count else { continue }
            // Importance = how much the likelihood differs between podium and non-podium
            var divergence = 0.0
            for bin in ["Low", "Medium", "High"] {
                let p = podiumLikelihoods[f][bin] ?? 0.33
                let q = nonPodiumLikelihoods[f][bin] ?? 0.33
                divergence += abs(p - q)
            }
            importances.append((name, divergence * 2))
        }
        return importances
    }

    func explanation(for driver: Driver) -> String {
        let score = predict(driver: driver)
        let components = posteriorComponents(for: driver)
        let parts = components.map { String(format: "P(%@=%@|Podium)=%.0f%%", $0.0, $0.1, $0.2 * 100) }
        return String(format: "Podium Probability: %.0f%%\n%@", score, parts.joined(separator: " x "))
    }

    private func discretize(_ value: Double, featureIndex: Int) -> String {
        guard featureIndex < binEdges.count, binEdges[featureIndex].count >= 2 else { return "Medium" }
        let edges = binEdges[featureIndex]
        if value <= edges[0] { return "Low" }
        if value <= edges[1] { return "Medium" }
        return "High"
    }
}

// MARK: - 6. Neural Network

class NeuralNetworkModel: MLModel {
    let type: ModelType = .neuralNetwork
    private var names: [String] = []
    private var maxDrivers: Int = 10
    private var noiseColumns: [NoiseColumn] = []
    private var track: TrackInfo = .monza

    // Network weights
    var weightsInputHidden1: [[Double]] = []   // 4 x 6 (or more with noise)
    var biasHidden1: [Double] = []             // 6
    var weightsHidden1Hidden2: [[Double]] = [] // 6 x 4
    var biasHidden2: [Double] = []             // 4
    var weightsHidden2Output: [Double] = []    // 4
    var biasOutput: Double = 0

    // Stored activations for visualization
    var lastInputActivations: [Double] = []
    var lastHidden1Activations: [Double] = []
    var lastHidden2Activations: [Double] = []
    var lastOutputActivation: Double = 0

    // Normalization state (must match between train and predict)
    private var featureMin: [Double] = []
    private var featureMax: [Double] = []
    private var targetMin: Double = 0
    private var targetRange: Double = 1

    let hidden1Size = 6
    let hidden2Size = 4
    var epochs = 30
    var learningRate = 0.01

    func train(drivers: [Driver], noiseColumns: [NoiseColumn], track: TrackInfo) {
        self.maxDrivers = drivers.count
        self.noiseColumns = noiseColumns
        self.track = track
        self.names = FeatureExtractor.featureNames(noiseColumns: noiseColumns)

        let inputSize = names.count

        // Initialize weights with small random values (deterministic seed for consistency)
        var rng = SeededRNG(seed: UInt64(drivers.count * 7 + noiseColumns.count * 13 + 42))
        weightsInputHidden1 = (0..<inputSize).map { _ in (0..<hidden1Size).map { _ in rng.nextDouble() * 0.4 - 0.2 } }
        biasHidden1 = (0..<hidden1Size).map { _ in rng.nextDouble() * 0.1 }
        weightsHidden1Hidden2 = (0..<hidden1Size).map { _ in (0..<hidden2Size).map { _ in rng.nextDouble() * 0.4 - 0.2 } }
        biasHidden2 = (0..<hidden2Size).map { _ in rng.nextDouble() * 0.1 }
        weightsHidden2Output = (0..<hidden2Size).map { _ in rng.nextDouble() * 0.4 - 0.2 }
        biasOutput = rng.nextDouble() * 0.1

        // Prepare training data
        let allFeatures = drivers.map { FeatureExtractor.features(for: $0, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track) }
        let targets = drivers.map { FeatureExtractor.compositeTarget(for: $0, maxDrivers: maxDrivers) }

        // Normalize targets to 0-1 range
        targetMin = targets.min() ?? 0
        let maxTarget = targets.max() ?? 1
        targetRange = max(maxTarget - targetMin, 0.001)
        let normalizedTargets = targets.map { ($0 - targetMin) / targetRange }

        // Normalize features
        let featureCount = inputSize
        featureMin = [Double](repeating: .infinity, count: featureCount)
        featureMax = [Double](repeating: -.infinity, count: featureCount)
        for features in allFeatures {
            for (i, v) in features.enumerated() {
                featureMin[i] = min(featureMin[i], v)
                featureMax[i] = max(featureMax[i], v)
            }
        }
        let normalizedFeatures = allFeatures.map { features in
            features.enumerated().map { i, v in
                let r = featureMax[i] - featureMin[i]
                return r > 0.001 ? (v - featureMin[i]) / r : 0.5
            }
        }

        // Training loop
        for _ in 0..<epochs {
            for (i, features) in normalizedFeatures.enumerated() {
                let target = normalizedTargets[i]

                // Forward pass
                let h1 = forwardHidden1(input: features)
                let h2 = forwardHidden2(input: h1)
                let output = forwardOutput(input: h2)

                // Backward pass (simple gradient descent)
                let outputError = output - target
                let outputGrad = outputError

                // Hidden2 -> Output gradients
                var h2Errors = [Double](repeating: 0, count: hidden2Size)
                for j in 0..<hidden2Size {
                    h2Errors[j] = outputGrad * weightsHidden2Output[j] * reluDerivative(h2[j])
                    weightsHidden2Output[j] -= learningRate * outputGrad * h2[j]
                }
                biasOutput -= learningRate * outputGrad

                // Hidden1 -> Hidden2 gradients
                var h1Errors = [Double](repeating: 0, count: hidden1Size)
                for j in 0..<hidden1Size {
                    for k in 0..<hidden2Size {
                        h1Errors[j] += h2Errors[k] * weightsHidden1Hidden2[j][k] * reluDerivative(h1[j])
                        weightsHidden1Hidden2[j][k] -= learningRate * h2Errors[k] * h1[j]
                    }
                }
                for k in 0..<hidden2Size {
                    biasHidden2[k] -= learningRate * h2Errors[k]
                }

                // Input -> Hidden1 gradients
                for j in 0..<min(features.count, weightsInputHidden1.count) {
                    for k in 0..<hidden1Size {
                        weightsInputHidden1[j][k] -= learningRate * h1Errors[k] * features[j]
                    }
                }
                for k in 0..<hidden1Size {
                    biasHidden1[k] -= learningRate * h1Errors[k]
                }
            }
        }
    }

    func predict(driver: Driver) -> Double {
        let features = FeatureExtractor.features(for: driver, maxDrivers: maxDrivers, noiseColumns: noiseColumns, track: track)
        let normalizedInput = normalizeInput(features)
        lastInputActivations = normalizedInput
        lastHidden1Activations = forwardHidden1(input: normalizedInput)
        lastHidden2Activations = forwardHidden2(input: lastHidden1Activations)
        lastOutputActivation = forwardOutput(input: lastHidden2Activations)
        return lastOutputActivation * targetRange + targetMin
    }

    func featureImportances() -> [(String, Double)] {
        // Approximate importance: sum of absolute weights from input to first hidden layer
        names.enumerated().map { (i, name) in
            let importance: Double
            if i < weightsInputHidden1.count {
                importance = weightsInputHidden1[i].map { abs($0) }.reduce(0, +) / Double(hidden1Size)
            } else {
                importance = 0
            }
            return (name, importance * 5)
        }
    }

    func explanation(for driver: Driver) -> String {
        let score = predict(driver: driver)
        return String(format: "Score: %.2f\nInput → Hidden1(%d nodes, ReLU) → Hidden2(%d nodes, ReLU) → Output",
                       score, hidden1Size, hidden2Size)
    }

    private func forwardHidden1(input: [Double]) -> [Double] {
        (0..<hidden1Size).map { k in
            var sum = biasHidden1[k]
            for j in 0..<min(input.count, weightsInputHidden1.count) {
                sum += input[j] * weightsInputHidden1[j][k]
            }
            return relu(sum)
        }
    }

    private func forwardHidden2(input: [Double]) -> [Double] {
        (0..<hidden2Size).map { k in
            var sum = biasHidden2[k]
            for j in 0..<hidden1Size {
                sum += input[j] * weightsHidden1Hidden2[j][k]
            }
            return relu(sum)
        }
    }

    private func forwardOutput(input: [Double]) -> Double {
        var sum = biasOutput
        for j in 0..<hidden2Size {
            sum += input[j] * weightsHidden2Output[j]
        }
        return sum // Linear output
    }

    private func normalizeInput(_ features: [Double]) -> [Double] {
        guard featureMin.count == features.count, featureMax.count == features.count else {
            return features
        }
        return features.enumerated().map { index, value in
            let range = featureMax[index] - featureMin[index]
            return range > 0.001 ? (value - featureMin[index]) / range : 0.5
        }
    }

    private func relu(_ x: Double) -> Double { max(0, x) }
    private func reluDerivative(_ x: Double) -> Double { x > 0 ? 1 : 0 }
}

// MARK: - Seeded Random Number Generator

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() % 10000) / 10000.0
    }
}

// MARK: - Linear System Solver (Gauss-Jordan)

func solveLinearSystem(_ A: [[Double]], _ b: [Double]) -> [Double]? {
    let n = b.count
    guard n > 0 else { return nil }

    // Augmented matrix
    var aug = A.enumerated().map { (i, row) in row + [b[i]] }

    for col in 0..<n {
        // Find pivot
        var maxRow = col
        for row in (col + 1)..<n {
            if abs(aug[row][col]) > abs(aug[maxRow][col]) {
                maxRow = row
            }
        }
        aug.swapAt(col, maxRow)

        let pivot = aug[col][col]
        guard abs(pivot) > 1e-12 else { return nil }

        // Scale pivot row
        for j in 0...(n) {
            aug[col][j] /= pivot
        }

        // Eliminate column
        for row in 0..<n where row != col {
            let factor = aug[row][col]
            for j in 0...(n) {
                aug[row][j] -= factor * aug[col][j]
            }
        }
    }

    return (0..<n).map { aug[$0][n] }
}

// MARK: - Helper

func variance(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    return values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
}

// MARK: - Model Factory

enum MLModelFactory {
    static func create(type: ModelType) -> any MLModel {
        switch type {
        case .linearRegression: return LinearRegressionModel()
        case .decisionTree: return DecisionTreeModel()
        case .randomForest: return RandomForestModel()
        case .knn: return KNNModel()
        case .naiveBayes: return NaiveBayesModel()
        case .neuralNetwork: return NeuralNetworkModel()
        }
    }
}
