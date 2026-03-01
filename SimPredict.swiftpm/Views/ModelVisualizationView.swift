import SwiftUI
import Charts

struct ModelVisualizationView: View {
    let modelType: ModelType
    @ObservedObject var labVM: LabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: modelType.icon)
                    .foregroundColor(modelType.accent)
                Text("How \(modelType.shortName) Works")
                    .font(AppFont.custom(16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(modelType.detail)
                    .font(AppFont.custom(11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Group {
                switch modelType {
                case .linearRegression:
                    LinearRegressionViz(labVM: labVM)
                case .decisionTree:
                    DecisionTreeViz(labVM: labVM)
                case .randomForest:
                    RandomForestViz(labVM: labVM)
                case .knn:
                    KNNViz(labVM: labVM)
                case .naiveBayes:
                    NaiveBayesViz(labVM: labVM)
                case .neuralNetwork:
                    NeuralNetworkViz(labVM: labVM)
                }
            }
            .frame(minHeight: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(modelType.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private enum ModelDemoData {
    static let drivers: [Driver] = [
        Driver(id: UUID(), name: "Alex", team: "Aether Velocity Racing", color: Color(red: 0.0, green: 0.83, blue: 0.71), qualifying: 2, wins: 25, trackWins: 3, dnfs: 1),
        Driver(id: UUID(), name: "Ben", team: "Aether Velocity Racing", color: Color(red: 0.0, green: 0.83, blue: 0.71), qualifying: 1, wins: 32, trackWins: 6, dnfs: 0),
        Driver(id: UUID(), name: "Chloe", team: "Titan Apex Motorsport", color: Color(red: 0.13, green: 0.15, blue: 0.49), qualifying: 3, wins: 20, trackWins: 4, dnfs: 2),
        Driver(id: UUID(), name: "Dan", team: "Titan Apex Motorsport", color: Color(red: 0.13, green: 0.15, blue: 0.49), qualifying: 4, wins: 18, trackWins: 3, dnfs: 2),
        Driver(id: UUID(), name: "Emma", team: "Meridian GP Engineering", color: Color(red: 0.86, green: 0.0, blue: 0.0), qualifying: 5, wins: 12, trackWins: 1, dnfs: 3),
        Driver(id: UUID(), name: "Finn", team: "Meridian GP Engineering", color: Color(red: 0.86, green: 0.0, blue: 0.0), qualifying: 6, wins: 14, trackWins: 2, dnfs: 3)
    ]

    static let linearRegressionPoints: [(String, Double, Double, Color)] = [
        ("EMM", 1.4, 48.0, Color(red: 0.86, green: 0.0, blue: 0.0)),
        ("FIN", 2.8, 58.0, Color(red: 0.86, green: 0.0, blue: 0.0)),
        ("DAN", 4.4, 67.0, Color(red: 0.13, green: 0.15, blue: 0.49)),
        ("CHL", 6.1, 75.0, Color(red: 0.13, green: 0.15, blue: 0.49)),
        ("ALE", 7.9, 84.0, Color(red: 0.0, green: 0.83, blue: 0.71)),
        ("BEN", 9.6, 92.0, Color(red: 0.0, green: 0.83, blue: 0.71))
    ]
}

// MARK: - Linear Regression Visualization

private struct LinearRegressionViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var selectedDriverCode: String? = ModelDemoData.linearRegressionPoints.first?.0
    @State private var lineProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A demo dataset is projected as points. The fit line animates once to show trend estimation.")
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.6))

            let dataPoints = ModelDemoData.linearRegressionPoints
            let xValues = dataPoints.map(\.1)
            let yValues = dataPoints.map(\.2)
            let xDomainMin = (xValues.min() ?? 0) - 0.4
            let xDomainMax = (xValues.max() ?? 10) + 0.4
            let yDomainMin = max(0, (yValues.min() ?? 0) - 8)
            let yDomainMax = min(100, (yValues.max() ?? 100) + 8)

            GeometryReader { geo in
                ZStack {
                    // Background grid
                    Canvas { context, size in
                        for i in 0..<5 {
                            let x = size.width * CGFloat(i) / 4
                            let y = size.height * CGFloat(i) / 4
                            var vLine = Path()
                            vLine.move(to: CGPoint(x: x, y: 0))
                            vLine.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(vLine, with: .color(Color.white.opacity(0.05)), lineWidth: 1)

                            var hLine = Path()
                            hLine.move(to: CGPoint(x: 0, y: y))
                            hLine.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(hLine, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
                        }
                    }

                    Chart {
                        // Regression line with animation
                        if let minX = dataPoints.map({ $0.1 }).min(),
                           let maxX = dataPoints.map({ $0.1 }).max() {
                            let minY = dataPoints.filter { $0.1 == minX }.first?.2 ?? 0
                            let maxY = dataPoints.filter { $0.1 == maxX }.first?.2 ?? 0

                            // Animated regression line
                            let currentMaxX = minX + (maxX - minX) * Double(lineProgress)
                            let currentMaxY = minY + (maxY - minY) * Double(lineProgress)
                            let linePoints: [(Double, Double)] = [
                                (minX, minY),
                                (currentMaxX, currentMaxY)
                            ]

                            ForEach(Array(linePoints.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("X", point.0),
                                    y: .value("Y", point.1)
                                )
                                .foregroundStyle(ModelType.linearRegression.accent)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .interpolationMethod(.linear)
                            }
                        }

                        // Data points
                        ForEach(dataPoints, id: \.0) { name, x, y, color in
                            PointMark(
                                x: .value("Qualifying", x),
                                y: .value("Score", y)
                            )
                            .foregroundStyle(color)
                            .symbolSize(selectedDriverCode == name ? 140 : 80)
                            .annotation(position: .top, spacing: 4) {
                                if selectedDriverCode == name {
                                    Text(name)
                                        .font(AppFont.custom(9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(color.opacity(0.8))
                                        )
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel()
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel()
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .chartXScale(domain: xDomainMin...xDomainMax)
                    .chartYScale(domain: yDomainMin...yDomainMax)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    withAnimation(.spring(response: 0.3)) {
                                        let closest = dataPoints.min { d1, d2 in
                                            let q1 = d1.1
                                            let q2 = d2.1
                                            guard let p1 = proxy.position(forX: q1 as Double),
                                                  let p2 = proxy.position(forX: q2 as Double) else { return false }
                                            return abs(p1 - location.x) < abs(p2 - location.x)
                                        }
                                        selectedDriverCode = closest?.0
                                        HapticsManager.shared.buttonPress()
                                    }
                                }
                        }
                    }
                }
            }
            .frame(height: 230)
            .onAppear {
                selectedDriverCode = dataPoints.first?.0
                lineProgress = 0
                withAnimation(.easeInOut(duration: 1.35)) {
                    lineProgress = 1.0
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ModelType.linearRegression.accent)
                        .frame(width: 8, height: 8)
                    Text("Best Fit Line")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                    Text("Drivers")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Decision Tree Visualization

private struct DecisionTreeViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var highlightedDriverIndex = 0
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Each node asks a yes/no question. The reveal runs once when this model is opened.")
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.6))

            let tree = buildTree()
            let demoDrivers = ModelDemoData.drivers

            GeometryReader { geo in
                let leafCount = max(countLeaves(in: tree), 1)
                let canvasWidth = max(geo.size.width, CGFloat(leafCount) * 170)

                ScrollView(.horizontal, showsIndicators: false) {
                    Canvas { context, size in
                        let topPadding: CGFloat = 24
                        let sidePadding: CGFloat = 56
                        let bottomPadding: CGFloat = 24
                        let depth = max(treeDepth(of: tree), 1)
                        let levelSpacing = depth > 1
                            ? (size.height - topPadding - bottomPadding) / CGFloat(depth - 1)
                            : 0

                        var nextLeafIndex = 0
                        _ = drawTree(
                            context: context,
                            node: tree,
                            y: topPadding,
                            levelSpacing: levelSpacing,
                            nextLeafIndex: &nextLeafIndex,
                            totalLeafCount: leafCount,
                            minLeafX: sidePadding,
                            maxLeafX: size.width - sidePadding
                        )
                    }
                    .frame(width: canvasWidth, height: 300)
                    .mask(alignment: .top) {
                        Rectangle()
                            .frame(height: max(36, 300 * animationProgress))
                    }
                }
            }
            .frame(height: 300)
            .onAppear {
                highlightedDriverIndex = 0
                restartTreeReveal()
            }

            // Driver spotlight
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(demoDrivers.enumerated()), id: \.offset) { index, driver in
                        Button(action: {
                            highlightedDriverIndex = index
                            restartTreeReveal()
                            HapticsManager.shared.buttonPress()
                        }) {
                            HStack(spacing: 4) {
                                Circle().fill(driver.color).frame(width: 8, height: 8)
                                Text(driver.name)
                                    .font(AppFont.custom(10, weight: highlightedDriverIndex == index ? .bold : .medium))
                                    .foregroundColor(.white.opacity(highlightedDriverIndex == index ? 0.95 : 0.65))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(highlightedDriverIndex == index ? ModelType.decisionTree.accent.opacity(0.2) : Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(highlightedDriverIndex == index ? ModelType.decisionTree.accent.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private func buildTree() -> TreeNode {
        .split(
            feature: "Wins",
            featureIndex: 1,
            threshold: 18.0,
            left: .split(
                feature: "Qualifying",
                featureIndex: 0,
                threshold: 3.0,
                left: .leaf(score: 8.2, count: 2, driverNames: ["Ben", "Alex"]),
                right: .leaf(score: 6.4, count: 1, driverNames: ["Chloe"])
            ),
            right: .split(
                feature: "Track Wins",
                featureIndex: 2,
                threshold: 2.0,
                left: .leaf(score: 4.8, count: 2, driverNames: ["Dan", "Finn"]),
                right: .leaf(score: 3.1, count: 1, driverNames: ["Emma"])
            )
        )
    }

    private func restartTreeReveal() {
        animationProgress = 0
        withAnimation(.easeInOut(duration: 1.25)) {
            animationProgress = 1.0
        }
    }

    private func countLeaves(in node: TreeNode) -> Int {
        switch node {
        case .leaf:
            return 1
        case .split(_, _, _, let left, let right):
            return countLeaves(in: left) + countLeaves(in: right)
        }
    }

    private func treeDepth(of node: TreeNode) -> Int {
        switch node {
        case .leaf:
            return 1
        case .split(_, _, _, let left, let right):
            return 1 + max(treeDepth(of: left), treeDepth(of: right))
        }
    }

    // Draw tree using leaf-based layout so branches never clip at the edges.
    @discardableResult
    private func drawTree(
        context: GraphicsContext,
        node: TreeNode,
        y: CGFloat,
        levelSpacing: CGFloat,
        nextLeafIndex: inout Int,
        totalLeafCount: Int,
        minLeafX: CGFloat,
        maxLeafX: CGFloat
    ) -> CGFloat {
        switch node {
        case .leaf(let score, let count, _):
            let x: CGFloat
            if totalLeafCount <= 1 {
                x = (minLeafX + maxLeafX) / 2
            } else {
                let step = (maxLeafX - minLeafX) / CGFloat(totalLeafCount - 1)
                x = minLeafX + CGFloat(nextLeafIndex) * step
            }
            nextLeafIndex += 1

            // Draw leaf node
            let rect = CGRect(x: x - 30, y: y - 15, width: 60, height: 30)
            let path = RoundedRectangle(cornerRadius: 8).path(in: rect)
            context.fill(path, with: .color(score > 0 ? AppColor.green.opacity(0.2) : AppColor.racingRed.opacity(0.2)))
            context.stroke(path, with: .color(score > 0 ? AppColor.green : AppColor.racingRed), lineWidth: 2)

            context.draw(Text(String(format: "%.1f", score)).font(AppFont.custom(12, weight: .bold)).foregroundColor(score > 0 ? AppColor.green : AppColor.racingRed), at: CGPoint(x: x, y: y - 5))
            context.draw(Text("\(count)").font(AppFont.custom(8)).foregroundColor(.white.opacity(0.5)), at: CGPoint(x: x, y: y + 8))
            return x

        case .split(let feature, _, let threshold, let left, let right):
            let childY = y + levelSpacing
            let leftX = drawTree(
                context: context,
                node: left,
                y: childY,
                levelSpacing: levelSpacing,
                nextLeafIndex: &nextLeafIndex,
                totalLeafCount: totalLeafCount,
                minLeafX: minLeafX,
                maxLeafX: maxLeafX
            )
            let rightX = drawTree(
                context: context,
                node: right,
                y: childY,
                levelSpacing: levelSpacing,
                nextLeafIndex: &nextLeafIndex,
                totalLeafCount: totalLeafCount,
                minLeafX: minLeafX,
                maxLeafX: maxLeafX
            )
            let x = (leftX + rightX) / 2

            // Draw decision node
            let rect = CGRect(x: x - 40, y: y - 18, width: 80, height: 36)
            let path = RoundedRectangle(cornerRadius: 8).path(in: rect)
            context.fill(path, with: .color(Color.white.opacity(0.15)))
            context.stroke(path, with: .color(ModelType.decisionTree.accent), lineWidth: 2)

            context.draw(Text(feature).font(AppFont.custom(10, weight: .semibold)).foregroundColor(.white), at: CGPoint(x: x, y: y - 8))
            context.draw(Text(String(format: "≤ %.1f?", threshold)).font(AppFont.custom(9)).foregroundColor(ModelType.decisionTree.accent), at: CGPoint(x: x, y: y + 6))

            // Left branch
            var leftPath = Path()
            leftPath.move(to: CGPoint(x: x, y: y + 18))
            leftPath.addLine(to: CGPoint(x: leftX, y: childY - 18))
            context.stroke(leftPath, with: .color(AppColor.green.opacity(0.4)), lineWidth: 2)
            context.draw(Text("Yes").font(AppFont.custom(9, weight: .bold)).foregroundColor(AppColor.green), at: CGPoint(x: (x + leftX) / 2 - 8, y: y + 30))

            // Right branch
            var rightPath = Path()
            rightPath.move(to: CGPoint(x: x, y: y + 18))
            rightPath.addLine(to: CGPoint(x: rightX, y: childY - 18))
            context.stroke(rightPath, with: .color(AppColor.racingRed.opacity(0.4)), lineWidth: 2)
            context.draw(Text("No").font(AppFont.custom(9, weight: .bold)).foregroundColor(AppColor.racingRed), at: CGPoint(x: (x + rightX) / 2 + 8, y: y + 30))
            return x
        }
    }
}

// MARK: - Random Forest Visualization

private struct RandomForestViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var animatedTreeIndex = -1
    @State private var showVoting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("5 trees vote independently. Majority vote becomes the final prediction.")
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(spacing: 6) {
                            Text("Tree \(index + 1)")
                                .font(AppFont.custom(10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))

                            // Mini tree structure
                            Canvas { context, size in
                                drawMiniTree(context: context, size: size, treeIndex: index, isActive: index <= animatedTreeIndex)
                            }
                            .frame(width: 70, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(index <= animatedTreeIndex ? 0.08 : 0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(ModelType.randomForest.accent.opacity(index <= animatedTreeIndex ? 0.4 : 0.1), lineWidth: 1.5)
                                    )
                            )

                            // Vote arrow and result
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10))
                                .foregroundColor(index <= animatedTreeIndex ? ModelType.randomForest.accent : Color.white.opacity(0.2))

                            Text(index % 2 == 0 ? "Class A" : "Class B")
                                .font(AppFont.custom(9, weight: .bold))
                                .foregroundColor(index <= animatedTreeIndex ? (index % 2 == 0 ? AppColor.green : AppColor.racingRed) : .white.opacity(0.3))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .opacity(index <= animatedTreeIndex ? 1 : 0.4)
                        .scaleEffect(index <= animatedTreeIndex ? 1.0 : 0.9)
                    }
                }
                .padding(.vertical, 8)
            }

            // Majority voting result
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ModelType.randomForest.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Majority Vote: 3 × Class A, 2 × Class B")
                        .font(AppFont.custom(11, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Final Prediction: Class A")
                        .font(AppFont.custom(10, weight: .bold))
                        .foregroundColor(AppColor.gold)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColor.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColor.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(showVoting ? 1 : 0)
            .scaleEffect(showVoting ? 1.0 : 0.9)
        }
        .onAppear {
            animateForestOnce()
        }
    }

    private func animateForestOnce() {
        animatedTreeIndex = -1
        showVoting = false

        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    animatedTreeIndex = i
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showVoting = true
            }
        }
    }

    private func drawMiniTree(context: GraphicsContext, size: CGSize, treeIndex: Int, isActive: Bool) {
        let centerX = size.width / 2
        let nodeRadius: CGFloat = 6
        let opacity = isActive ? 1.0 : 0.3

        // Root node
        let rootY: CGFloat = 15
        context.fill(Circle().path(in: CGRect(x: centerX - nodeRadius, y: rootY - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)), with: .color(ModelType.randomForest.accent.opacity(opacity)))

        // Two branches
        let branchY: CGFloat = 35
        let branchSpacing: CGFloat = 18

        // Left branch line
        var leftBranchPath = Path()
        leftBranchPath.move(to: CGPoint(x: centerX, y: rootY + nodeRadius))
        leftBranchPath.addLine(to: CGPoint(x: centerX - branchSpacing, y: branchY - nodeRadius))
        context.stroke(leftBranchPath, with: .color(Color.white.opacity(0.3 * opacity)), lineWidth: 1.5)

        // Right branch line
        var rightBranchPath = Path()
        rightBranchPath.move(to: CGPoint(x: centerX, y: rootY + nodeRadius))
        rightBranchPath.addLine(to: CGPoint(x: centerX + branchSpacing, y: branchY - nodeRadius))
        context.stroke(rightBranchPath, with: .color(Color.white.opacity(0.3 * opacity)), lineWidth: 1.5)

        // Decision nodes
        context.fill(Circle().path(in: CGRect(x: centerX - branchSpacing - nodeRadius, y: branchY - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)), with: .color(Color.cyan.opacity(0.6 * opacity)))
        context.fill(Circle().path(in: CGRect(x: centerX + branchSpacing - nodeRadius, y: branchY - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)), with: .color(Color.cyan.opacity(0.6 * opacity)))

        // Leaf nodes
        let leafY: CGFloat = 60
        let leafSpacing: CGFloat = 12

        // Lines to leaves
        for xOffset in [-branchSpacing - leafSpacing, -branchSpacing + leafSpacing, branchSpacing - leafSpacing, branchSpacing + leafSpacing] {
            var leafPath = Path()
            let parentX = xOffset < 0 ? centerX - branchSpacing : centerX + branchSpacing
            leafPath.move(to: CGPoint(x: parentX, y: branchY + nodeRadius))
            leafPath.addLine(to: CGPoint(x: centerX + xOffset, y: leafY - nodeRadius))
            context.stroke(leafPath, with: .color(Color.white.opacity(0.2 * opacity)), lineWidth: 1)
        }

        // Draw leaf nodes
        for xOffset in [-branchSpacing - leafSpacing, -branchSpacing + leafSpacing, branchSpacing - leafSpacing, branchSpacing + leafSpacing] {
            let leafColor = (treeIndex + Int(xOffset)) % 2 == 0 ? AppColor.green : AppColor.racingRed
            context.fill(Circle().path(in: CGRect(x: centerX + xOffset - nodeRadius/2, y: leafY - nodeRadius/2, width: nodeRadius, height: nodeRadius)), with: .color(leafColor.opacity(0.8 * opacity)))
        }
    }
}

// MARK: - KNN Visualization

private struct KNNDemoPoint: Identifiable {
    let id = UUID()
    let code: String
    let position: CGPoint  // Normalized 0...1 on the demo field
    let isClassA: Bool
}

private struct KNNViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var queryPoint = CGPoint(x: 0.73, y: 0.54)
    @State private var highlightPulse = false

    private let demoPoints: [KNNDemoPoint] = [
        KNNDemoPoint(code: "ALE", position: CGPoint(x: 0.66, y: 0.67), isClassA: true),
        KNNDemoPoint(code: "BEN", position: CGPoint(x: 0.83, y: 0.77), isClassA: true),
        KNNDemoPoint(code: "CHL", position: CGPoint(x: 0.72, y: 0.60), isClassA: true),
        KNNDemoPoint(code: "DAN", position: CGPoint(x: 0.58, y: 0.56), isClassA: true),
        KNNDemoPoint(code: "EMM", position: CGPoint(x: 0.51, y: 0.49), isClassA: true),
        KNNDemoPoint(code: "FIN", position: CGPoint(x: 0.62, y: 0.42), isClassA: false),
        KNNDemoPoint(code: "GRA", position: CGPoint(x: 0.47, y: 0.34), isClassA: false),
        KNNDemoPoint(code: "HUG", position: CGPoint(x: 0.39, y: 0.44), isClassA: false),
        KNNDemoPoint(code: "IRI", position: CGPoint(x: 0.31, y: 0.30), isClassA: false),
        KNNDemoPoint(code: "JAC", position: CGPoint(x: 0.24, y: 0.24), isClassA: false)
    ]

    private var maxModelK: Int {
        max(1, labVM.drivers.count - 1)
    }

    private var currentK: Int {
        min(max(labVM.knnK, 1), maxModelK)
    }

    private var orderedNeighbors: [(point: KNNDemoPoint, distance: Double)] {
        demoPoints
            .map { point in
                let dx = Double(point.position.x - queryPoint.x)
                let dy = Double(point.position.y - queryPoint.y)
                return (point, sqrt(dx * dx + dy * dy))
            }
            .sorted { $0.distance < $1.distance }
    }

    private var nearestNeighbors: [(point: KNNDemoPoint, distance: Double)] {
        Array(orderedNeighbors.prefix(min(currentK, demoPoints.count)))
    }

    private var weightedVotes: (classA: Double, classB: Double) {
        nearestNeighbors.reduce(into: (classA: 0.0, classB: 0.0)) { result, item in
            let weight = 1.0 / max(item.distance, 0.02)
            if item.point.isClassA {
                result.classA += weight
            } else {
                result.classB += weight
            }
        }
    }

    private var predictedClassA: Bool {
        weightedVotes.classA >= weightedVotes.classB
    }

    private var confidence: Double {
        let total = weightedVotes.classA + weightedVotes.classB
        guard total > 0 else { return 0.5 }
        let winning = max(weightedVotes.classA, weightedVotes.classB)
        return min(max(winning / total, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Move the yellow query point. K controls how many neighbors vote, and this same K is used by the real race prediction.")
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.6))

            HStack {
                Text("K = \(currentK)")
                    .font(AppFont.custom(13, weight: .bold))
                    .foregroundColor(ModelType.knn.accent)
                Slider(value: knnKBinding, in: 1...Double(maxModelK), step: 1)
                    .tint(ModelType.knn.accent)
                Text("Max \(maxModelK)")
                    .font(AppFont.custom(10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            GeometryReader { geo in
                let inset: CGFloat = 20
                let queryViewPoint = boardPoint(for: queryPoint, size: geo.size, inset: inset)
                let rankedIDs = Dictionary(
                    uniqueKeysWithValues: nearestNeighbors.enumerated().map { ($0.element.point.id, $0.offset + 1) }
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    Canvas { context, size in
                        // Grid
                        for i in 0...4 {
                            let x = inset + (size.width - inset * 2) * CGFloat(i) / 4
                            let y = inset + (size.height - inset * 2) * CGFloat(i) / 4

                            var vPath = Path()
                            vPath.move(to: CGPoint(x: x, y: inset))
                            vPath.addLine(to: CGPoint(x: x, y: size.height - inset))
                            context.stroke(vPath, with: .color(Color.white.opacity(0.08)), lineWidth: 1)

                            var hPath = Path()
                            hPath.move(to: CGPoint(x: inset, y: y))
                            hPath.addLine(to: CGPoint(x: size.width - inset, y: y))
                            context.stroke(hPath, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
                        }

                        for entry in nearestNeighbors {
                            let target = boardPoint(for: entry.point.position, size: size, inset: inset)
                            var path = Path()
                            path.move(to: queryViewPoint)
                            path.addLine(to: target)
                            context.stroke(
                                path,
                                with: .color(entry.point.isClassA ? AppColor.green.opacity(0.55) : AppColor.racingRed.opacity(0.55)),
                                style: StrokeStyle(lineWidth: highlightPulse ? 2.4 : 1.8, lineCap: .round, dash: [5, 5])
                            )
                        }
                    }

                    ForEach(demoPoints) { point in
                        let position = boardPoint(for: point.position, size: geo.size, inset: inset)
                        let rank = rankedIDs[point.id]

                        ZStack {
                            Circle()
                                .fill(point.isClassA ? AppColor.green : AppColor.racingRed)
                                .frame(width: rank == nil ? 14 : 18, height: rank == nil ? 14 : 18)

                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                .frame(width: rank == nil ? 14 : 18, height: rank == nil ? 14 : 18)

                            if let rank {
                                Text("\(rank)")
                                    .font(AppFont.custom(9, weight: .bold))
                                    .foregroundColor(.black.opacity(0.85))
                                    .padding(2)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.9))
                                    )
                                    .offset(y: -13)
                            }
                        }
                        .position(position)
                        .overlay(
                            Text(point.code)
                                .font(AppFont.custom(8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .offset(y: 14),
                            alignment: .center
                        )
                    }

                    // Query point
                    ZStack {
                        Circle()
                            .stroke(AppColor.gold.opacity(0.6), lineWidth: highlightPulse ? 10 : 6)
                            .frame(width: 28, height: 28)
                            .blur(radius: highlightPulse ? 1 : 0)

                        Circle()
                            .fill(AppColor.gold)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("?")
                                    .font(AppFont.custom(10, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    .position(queryViewPoint)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            queryPoint = normalizedPoint(for: value.location, size: geo.size, inset: inset)
                        }
                        .onEnded { _ in
                            triggerPulse()
                            HapticsManager.shared.buttonPress()
                        }
                )
            }
            .frame(height: 220)
            .onAppear {
                if labVM.knnK != currentK {
                    labVM.knnK = currentK
                }
                triggerPulse()
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(predictedClassA ? "Prediction: Class A" : "Prediction: Class B")
                        .font(AppFont.custom(11, weight: .bold))
                        .foregroundColor(predictedClassA ? AppColor.green : AppColor.racingRed)
                    Text("\(Int(confidence * 100))% vote confidence")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nearest Set")
                        .font(AppFont.custom(10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(nearestNeighbors.map { $0.point.code }.joined(separator: ", "))
                        .font(AppFont.custom(10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColor.green)
                        .frame(width: 10, height: 10)
                    Text("Class A")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColor.racingRed)
                        .frame(width: 10, height: 10)
                    Text("Class B")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColor.gold)
                        .frame(width: 10, height: 10)
                    Text("Query")
                        .font(AppFont.custom(10))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text("Nearest vote decides class")
                    .font(AppFont.custom(10))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private var knnKBinding: Binding<Double> {
        Binding(
            get: { Double(currentK) },
            set: { newValue in
                let next = min(max(1, Int(newValue.rounded())), maxModelK)
                if labVM.knnK != next {
                    labVM.knnK = next
                    labVM.updateLivePreview()
                    triggerPulse()
                }
            }
        )
    }

    private func boardPoint(for normalized: CGPoint, size: CGSize, inset: CGFloat) -> CGPoint {
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        return CGPoint(
            x: inset + normalized.x * width,
            y: inset + (1 - normalized.y) * height
        )
    }

    private func normalizedPoint(for location: CGPoint, size: CGSize, inset: CGFloat) -> CGPoint {
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        let normalizedX = min(max((location.x - inset) / width, 0), 1)
        let normalizedY = min(max(1 - ((location.y - inset) / height), 0), 1)
        return CGPoint(x: normalizedX, y: normalizedY)
    }

    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.22)) {
            highlightPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeIn(duration: 0.25)) {
                highlightPulse = false
            }
        }
    }
}

// MARK: - Naive Bayes Visualization

private struct NaiveBayesViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var selectedDriverIndex = 0
    @State private var animatedBars: [Bool] = Array(repeating: false, count: 4)

    var body: some View {
        let demoDrivers = ModelDemoData.drivers

        VStack(alignment: .leading, spacing: 10) {
            Text("Uses probability theory: P(Podium|Features) = P(F1|Podium) × P(F2|Podium) × ... × P(Podium)")
                .font(AppFont.custom(11))
                .foregroundColor(.white.opacity(0.65))
                .italic()

            // Train model and get components
            let driver = demoDrivers.indices.contains(selectedDriverIndex) ? demoDrivers[selectedDriverIndex] : nil

            if let driver = driver {
                var model = NaiveBayesModel()
                let _ = { model.train(drivers: demoDrivers, noiseColumns: [], track: .monza) }()
                let components = model.posteriorComponents(for: driver)

                VStack(spacing: 4) {
                    Text("Feature Likelihoods for \(driver.name)")
                        .font(AppFont.custom(12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.bottom, 4)

                    ForEach(Array(components.prefix(4).enumerated()), id: \.offset) { index, item in
                        let (name, bin, likelihood) = item
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Text(name)
                                    .font(AppFont.custom(11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 80, alignment: .leading)

                                Text(bin)
                                    .font(AppFont.custom(10, weight: .bold))
                                    .foregroundColor(ModelType.naiveBayes.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(ModelType.naiveBayes.accent.opacity(0.15))
                                    )

                                Spacer()

                                Text(String(format: "%.0f%%", likelihood * 100))
                                    .font(AppFont.custom(11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, alignment: .trailing)
                            }

                            // Animated probability bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white.opacity(0.08))

                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    ModelType.naiveBayes.accent,
                                                    ModelType.naiveBayes.accent.opacity(0.6)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animatedBars[index] ? geo.size.width * likelihood : 0)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animatedBars[index])
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(ModelType.naiveBayes.accent.opacity(0.4), lineWidth: 1)
                                        )
                                        .shadow(color: ModelType.naiveBayes.accent.opacity(0.3), radius: 3, x: 0, y: 1)
                                }
                            }
                            .frame(height: 16)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )

                // Calculation visualization
                VStack(alignment: .leading, spacing: 6) {
                    Text("Probability Calculation")
                        .font(AppFont.custom(11, weight: .semibold))
                        .foregroundColor(AppColor.gold)

                    HStack(spacing: 4) {
                        ForEach(0..<min(components.count, 4), id: \.self) { i in
                            Text(String(format: "%.0f%%", components[i].2 * 100))
                                .font(AppFont.custom(10, weight: .bold))
                                .foregroundColor(ModelType.naiveBayes.accent)
                            if i < min(components.count, 4) - 1 {
                                Image(systemName: "multiply")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Image(systemName: "equal")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Final Score")
                            .font(AppFont.custom(10, weight: .bold))
                            .foregroundColor(AppColor.gold)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColor.gold.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColor.gold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }

            // Driver selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(demoDrivers.enumerated()), id: \.offset) { index, driver in
                        Button(action: {
                            selectedDriverIndex = index
                            restartBarAnimation()
                            HapticsManager.shared.buttonPress()
                        }) {
                            HStack(spacing: 4) {
                                Circle().fill(driver.color).frame(width: 8, height: 8)
                                Text(driver.name)
                                    .font(AppFont.custom(10, weight: selectedDriverIndex == index ? .bold : .medium))
                                    .foregroundColor(selectedDriverIndex == index ? .white : .white.opacity(0.6))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedDriverIndex == index ? ModelType.naiveBayes.accent.opacity(0.2) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedDriverIndex == index ? ModelType.naiveBayes.accent : Color.clear, lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedDriverIndex = 0
            restartBarAnimation()
        }
    }

    private func restartBarAnimation() {
        animatedBars = Array(repeating: false, count: 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            animatedBars = Array(repeating: true, count: 4)
        }
    }
}

// MARK: - Neural Network Visualization

private struct NeuralNetworkViz: View {
    @ObservedObject var labVM: LabViewModel
    @State private var animationProgress: CGFloat = 0
    @State private var flowTask: Task<Void, Never>?

    let inputLabels = ["Quali", "Wins", "T.Wins", "DNFs"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signals flow once from input to output through two hidden layers.")
                .font(AppFont.custom(12))
                .foregroundColor(.white.opacity(0.6))

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let layers = [4, 6, 4, 1]
                let layerX = layers.enumerated().map { i, _ in
                    CGFloat(i) / CGFloat(layers.count - 1) * (width - 40) + 20
                }

                Canvas { context, _ in
                    // Draw connections
                    for l in 0..<(layers.count - 1) {
                        for i in 0..<layers[l] {
                            for j in 0..<layers[l + 1] {
                                let from = nodePosition(layer: l, index: i, layerSize: layers[l], x: layerX[l], height: height)
                                let to = nodePosition(layer: l + 1, index: j, layerSize: layers[l + 1], x: layerX[l + 1], height: height)

                                var path = Path()
                                path.move(to: from)
                                path.addLine(to: to)

                                // Strictly staged propagation:
                                // stage 0: Input -> Hidden 1
                                // stage 1: Hidden 1 -> Hidden 2
                                // stage 2: Hidden 2 -> Output
                                let progress = stageProgress(stage: l)
                                context.stroke(path, with: .color(Color.white.opacity(0.09)), lineWidth: 0.9)

                                let activeColor: Color = l == layers.count - 2 ? AppColor.gold : ModelType.neuralNetwork.accent
                                let highlightOpacity = 0.18 + progress * 0.82
                                let width = 1.1 + progress * 1.9
                                let currentPoint = CGPoint(
                                    x: from.x + (to.x - from.x) * progress,
                                    y: from.y + (to.y - from.y) * progress
                                )

                                var activePath = Path()
                                activePath.move(to: from)
                                activePath.addLine(to: currentPoint)
                                context.stroke(activePath, with: .color(activeColor.opacity(highlightOpacity)), lineWidth: width)

                                if progress > 0.02 && progress < 0.98 {
                                    let pulseRect = CGRect(x: currentPoint.x - 3.8, y: currentPoint.y - 3.8, width: 7.6, height: 7.6)
                                    context.fill(Circle().path(in: pulseRect), with: .color(activeColor.opacity(0.96)))
                                }
                            }
                        }
                    }

                    // Draw nodes
                    for (l, count) in layers.enumerated() {
                        for i in 0..<count {
                            let pos = nodePosition(layer: l, index: i, layerSize: count, x: layerX[l], height: height)
                            let progress = layerActivation(layer: l)
                            let color = l == 0 ? ModelType.neuralNetwork.accent :
                                        l == layers.count - 1 ? AppColor.gold :
                                        Color.white

                            let diameter: CGFloat = 18 + progress * 5
                            let rect = CGRect(
                                x: pos.x - diameter / 2,
                                y: pos.y - diameter / 2,
                                width: diameter,
                                height: diameter
                            )
                            context.fill(Circle().path(in: rect), with: .color(color.opacity(0.2 + progress * 0.65)))
                            context.stroke(Circle().path(in: rect), with: .color(color.opacity(0.45 + progress * 0.48)), lineWidth: 1.2 + progress * 0.9)

                            let glowRect = rect.insetBy(dx: -4, dy: -4)
                            context.stroke(
                                Circle().path(in: glowRect),
                                with: .color(color.opacity(0.12 + progress * 0.18)),
                                lineWidth: 1
                            )
                        }
                    }
                }

                // Layer labels
                VStack {
                    Spacer()
                    HStack {
                        Text("Input")
                            .frame(maxWidth: .infinity)
                        Text("Hidden 1")
                            .frame(maxWidth: .infinity)
                        Text("Hidden 2")
                            .frame(maxWidth: .infinity)
                        Text("Output")
                            .frame(maxWidth: .infinity)
                    }
                    .font(AppFont.custom(9))
                    .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(height: 230)
            .onAppear {
                restartFlowAnimation()
            }
            .onDisappear {
                flowTask?.cancel()
                flowTask = nil
            }

            HStack(spacing: 4) {
                Circle().fill(ModelType.neuralNetwork.accent).frame(width: 8, height: 8)
                Text("Input features")
                    .font(AppFont.custom(10)).foregroundColor(.white.opacity(0.5))
                Spacer()
                Circle().fill(Color.white).frame(width: 8, height: 8)
                Text("Hidden (ReLU)")
                    .font(AppFont.custom(10)).foregroundColor(.white.opacity(0.5))
                Spacer()
                Circle().fill(AppColor.gold).frame(width: 8, height: 8)
                Text("Prediction")
                    .font(AppFont.custom(10)).foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private func nodePosition(layer: Int, index: Int, layerSize: Int, x: CGFloat, height: CGFloat) -> CGPoint {
        let spacing = (height - 40) / max(CGFloat(layerSize), 1)
        let yOffset = (height - spacing * CGFloat(layerSize - 1)) / 2
        return CGPoint(x: x, y: yOffset + CGFloat(index) * spacing)
    }

    private func stageProgress(stage: Int) -> CGFloat {
        let stageCount: CGFloat = 3
        let segment = 1.0 / stageCount
        let start = CGFloat(stage) * segment
        let raw = (animationProgress - start) / segment
        let clamped = min(1, max(0, raw))
        // Smoothstep for non-jittery easing within each stage.
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func layerActivation(layer: Int) -> CGFloat {
        switch layer {
        case 0:
            return 1.0
        case 1:
            return stageProgress(stage: 0)
        case 2:
            return stageProgress(stage: 1)
        default:
            return stageProgress(stage: 2)
        }
    }

    private func restartFlowAnimation() {
        flowTask?.cancel()
        animationProgress = 0

        let frames = 300
        let totalDuration: Double = 3.6
        let frameDelayNanos = UInt64((totalDuration / Double(frames)) * 1_000_000_000)

        flowTask = Task { @MainActor in
            for frame in 0...frames {
                if Task.isCancelled { return }
                animationProgress = CGFloat(frame) / CGFloat(frames)
                if frame < frames {
                    try? await Task.sleep(nanoseconds: frameDelayNanos)
                }
            }
        }
    }
}
