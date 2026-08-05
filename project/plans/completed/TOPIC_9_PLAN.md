# Topic 9: Advanced Features - Detailed Implementation Plan

**Version:** v1.15.0
**Status:** Ready to Start
**Prerequisites:** Topics 1-6, 8 Complete ✅
**Created:** October 31, 2025

---

## Overview

Topic 9 adds sophisticated analytical capabilities for advanced financial modeling, including optimization, forecasting, portfolio theory, real options valuation, and comprehensive risk analytics. These features transform BusinessMath from a calculation library into a complete quantitative finance toolkit.

### Key Principles

1. **Research-Grade Quality**: Implementations should match academic/industry standards
2. **Numerical Stability**: Careful attention to floating-point precision and convergence
3. **Performance**: Optimize for large-scale computations
4. **Practical Application**: Focus on real-world use cases, not just theory
5. **Integration**: Leverage existing BusinessMath capabilities

---

## Implementation Phases

### Phase 1: Optimization & Solvers (Priority 1)
**Goal:** Find optimal values for business decisions under constraints

### Phase 2: Time Series Forecasting (Priority 2)
**Goal:** Predict future values using statistical methods

### Phase 3: Portfolio Optimization (Priority 3)
**Goal:** Optimal asset allocation using Modern Portfolio Theory

### Phase 4: Real Options Valuation (Priority 4)
**Goal:** Value flexibility and strategic options

### Phase 5: Advanced Risk Analytics (Priority 5)
**Goal:** Comprehensive risk measurement and stress testing

---

## Phase 1: Optimization & Solvers

### 1.1 Optimization Framework

**File:** `Sources/BusinessMath/Optimization/Optimizer.swift`

```swift
import Foundation

/// Protocol for optimization algorithms
public protocol Optimizer {
    associatedtype T: Real

    /// Optimize an objective function
    func optimize(
        objective: (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T>
}

/// Optimization result
public struct OptimizationResult<T: Real> {
    public let optimalValue: T
    public let objectiveValue: T
    public let iterations: Int
    public let converged: Bool
    public let history: [IterationHistory<T>]

    public var description: String {
        """
        Optimization Result:
          Optimal Value: \(optimalValue)
          Objective: \(objectiveValue)
          Iterations: \(iterations)
          Converged: \(converged ? "Yes" : "No")
        """
    }
}

public struct IterationHistory<T: Real> {
    public let iteration: Int
    public let value: T
    public let objective: T
    public let gradient: T?
}

/// Constraint for optimization
public struct Constraint<T: Real> {
    public let type: ConstraintType
    public let bound: T
    public let function: (T) -> T

    public init(
        type: ConstraintType,
        bound: T,
        function: @escaping (T) -> T = { $0 }
    ) {
        self.type = type
        self.bound = bound
        self.function = function
    }

    /// Check if constraint is satisfied
    public func isSatisfied(_ value: T) -> Bool {
        let result = function(value)
        switch type {
        case .lessThan:
            return result < bound
        case .lessThanOrEqual:
            return result <= bound
        case .greaterThan:
            return result > bound
        case .greaterThanOrEqual:
            return result >= bound
        case .equalTo:
            return abs(result - bound) < 0.0001
        }
    }
}

public enum ConstraintType {
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
    case equalTo
}
```

---

### 1.2 Newton-Raphson Solver (Enhanced)

**File:** `Sources/BusinessMath/Optimization/NewtonRaphson.swift`

We already have `goalSeek` - enhance it to be a full optimizer:

```swift
/// Newton-Raphson optimization (already exists, enhance it)
public class NewtonRaphsonOptimizer<T: Real>: Optimizer {

    public let tolerance: T
    public let maxIterations: Int
    public let stepSize: T  // For numerical derivatives

    public init(
        tolerance: T = 0.000001,
        maxIterations: Int = 100,
        stepSize: T = 0.0001
    ) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.stepSize = stepSize
    }

    public func optimize(
        objective: (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {

        var x = initialValue
        var history: [IterationHistory<T>] = []
        var converged = false

        for iteration in 0..<maxIterations {
            // Calculate objective and derivative
            let fx = objective(x)
            let derivative = numericalDerivative(objective, at: x)

            history.append(IterationHistory(
                iteration: iteration,
                value: x,
                objective: fx,
                gradient: derivative
            ))

            // Check convergence
            if abs(fx) < tolerance {
                converged = true
                break
            }

            // Newton step
            let step = fx / derivative
            x = x - step

            // Enforce bounds
            if let bounds = bounds {
                x = max(bounds.lower, min(bounds.upper, x))
            }

            // Check constraints
            let constraintsSatisfied = constraints.allSatisfy { $0.isSatisfied(x) }
            if !constraintsSatisfied {
                // Project back to feasible region
                x = projectToFeasibleRegion(x, constraints: constraints)
            }
        }

        return OptimizationResult(
            optimalValue: x,
            objectiveValue: objective(x),
            iterations: history.count,
            converged: converged,
            history: history
        )
    }

    private func numericalDerivative(
        _ f: (T) -> T,
        at x: T
    ) -> T {
        let h = stepSize
        return (f(x + h) - f(x - h)) / (T(2) * h)
    }

    private func projectToFeasibleRegion(
        _ x: T,
        constraints: [Constraint<T>]
    ) -> T {
        // Simple projection (can be enhanced)
        var result = x
        for constraint in constraints {
            if !constraint.isSatisfied(result) {
                // Adjust to satisfy constraint
                result = constraint.bound
            }
        }
        return result
    }
}
```

---

### 1.3 Gradient Descent

**File:** `Sources/BusinessMath/Optimization/GradientDescent.swift`

```swift
/// Gradient descent optimizer
public class GradientDescentOptimizer<T: Real>: Optimizer {

    public let learningRate: T
    public let tolerance: T
    public let maxIterations: Int
    public let momentum: T  // Momentum for faster convergence

    public init(
        learningRate: T = 0.01,
        tolerance: T = 0.000001,
        maxIterations: Int = 1000,
        momentum: T = 0.9
    ) {
        self.learningRate = learningRate
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.momentum = momentum
    }

    public func optimize(
        objective: (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {

        var x = initialValue
        var velocity: T = 0
        var history: [IterationHistory<T>] = []
        var converged = false
        var previousGradient: T = 0

        for iteration in 0..<maxIterations {
            let fx = objective(x)
            let gradient = numericalGradient(objective, at: x)

            history.append(IterationHistory(
                iteration: iteration,
                value: x,
                objective: fx,
                gradient: gradient
            ))

            // Check convergence
            if abs(gradient) < tolerance {
                converged = true
                break
            }

            // Update with momentum
            velocity = momentum * velocity - learningRate * gradient
            x = x + velocity

            // Enforce bounds
            if let bounds = bounds {
                x = max(bounds.lower, min(bounds.upper, x))
            }

            previousGradient = gradient
        }

        return OptimizationResult(
            optimalValue: x,
            objectiveValue: objective(x),
            iterations: history.count,
            converged: converged,
            history: history
        )
    }

    private func numericalGradient(
        _ f: (T) -> T,
        at x: T
    ) -> T {
        let h: T = 0.0001
        return (f(x + h) - f(x - h)) / (T(2) * h)
    }
}
```

---

### 1.4 Capital Allocation Optimizer

**File:** `Sources/BusinessMath/Optimization/CapitalAllocation.swift`

```swift
/// Optimize capital allocation across projects
public struct CapitalAllocationOptimizer<T: Real> {

    /// Project with NPV and capital requirement
    public struct Project {
        public let name: String
        public let npv: T
        public let capitalRequired: T
        public let risk: T?  // Optional risk measure

        public init(name: String, npv: T, capitalRequired: T, risk: T? = nil) {
            self.name = name
            self.npv = npv
            self.capitalRequired = capitalRequired
            self.risk = risk
        }

        /// Return on investment (NPV / Capital)
        public var roi: T {
            return npv / capitalRequired
        }
    }

    public struct AllocationResult {
        public let allocations: [String: T]  // Project name -> capital allocated
        public let totalNPV: T
        public let capitalUsed: T
        public let projectsSelected: [String]

        public var description: String {
            var desc = "Capital Allocation Result:\n"
            desc += "  Total NPV: \(totalNPV)\n"
            desc += "  Capital Used: \(capitalUsed)\n"
            desc += "  Projects Selected: \(projectsSelected.count)\n\n"
            desc += "Allocations:\n"
            for (project, capital) in allocations.sorted(by: { $0.value > $1.value }) {
                desc += "  \(project): \(capital)\n"
            }
            return desc
        }
    }

    /// Optimize capital allocation to maximize NPV
    /// Uses greedy approach: sort by ROI, allocate until budget exhausted
    public func optimize(
        projects: [Project],
        budget: T,
        constraints: [AllocationConstraint<T>] = []
    ) -> AllocationResult {

        // Sort projects by ROI (descending)
        let sortedProjects = projects.sorted { $0.roi > $1.roi }

        var allocations: [String: T] = [:]
        var remainingBudget = budget
        var totalNPV: T = 0

        for project in sortedProjects {
            // Check if we have enough budget
            let allocation = min(project.capitalRequired, remainingBudget)

            if allocation > 0 {
                allocations[project.name] = allocation
                totalNPV += (allocation / project.capitalRequired) * project.npv
                remainingBudget -= allocation
            }

            if remainingBudget <= 0 {
                break
            }
        }

        return AllocationResult(
            allocations: allocations,
            totalNPV: totalNPV,
            capitalUsed: budget - remainingBudget,
            projectsSelected: Array(allocations.keys)
        )
    }

    /// Integer programming version (all-or-nothing projects)
    public func optimizeIntegerProjects(
        projects: [Project],
        budget: T
    ) -> AllocationResult {
        // Use 0-1 knapsack algorithm
        let n = projects.count
        var dp = Array(repeating: Array(repeating: T(0), count: Int(budget) + 1), count: n + 1)

        // Build DP table
        for i in 1...n {
            let project = projects[i - 1]
            let capital = Int(project.capitalRequired)

            for b in 0...Int(budget) {
                // Don't include this project
                dp[i][b] = dp[i - 1][b]

                // Include if possible
                if capital <= b {
                    let includeValue = dp[i - 1][b - capital] + project.npv
                    dp[i][b] = max(dp[i][b], includeValue)
                }
            }
        }

        // Backtrack to find selected projects
        var allocations: [String: T] = [:]
        var remainingBudget = Int(budget)

        for i in (1...n).reversed() {
            if dp[i][remainingBudget] != dp[i - 1][remainingBudget] {
                let project = projects[i - 1]
                allocations[project.name] = project.capitalRequired
                remainingBudget -= Int(project.capitalRequired)
            }
        }

        let totalNPV = dp[n][Int(budget)]

        return AllocationResult(
            allocations: allocations,
            totalNPV: totalNPV,
            capitalUsed: budget - T(remainingBudget),
            projectsSelected: Array(allocations.keys)
        )
    }
}

public struct AllocationConstraint<T: Real> {
    public let type: ConstraintType
    public let limit: T

    public enum ConstraintType {
        case maxPerProject
        case minPerProject
        case maxRisk
        case diversification  // Max % to single project
    }
}
```

**Test Cases:**
- ✅ Maximize NPV with budget constraint
- ✅ Fractional allocation (continuous)
- ✅ Integer allocation (all-or-nothing projects)
- ✅ Compare greedy vs optimal solutions
- ✅ Handle edge cases (budget = 0, no projects, etc.)

---

## Phase 2: Time Series Forecasting

### 2.1 Forecasting Protocol

**File:** `Sources/BusinessMath/Forecasting/ForecastModel.swift`

```swift
/// Protocol for forecasting models
public protocol ForecastModel {
    associatedtype T: Real

    /// Train the model on historical data
    mutating func train(on series: TimeSeries<T>) throws

    /// Predict future values
    func predict(periods: Int) -> TimeSeries<T>

    /// Predict with confidence intervals
    func predictWithConfidence(
        periods: Int,
        confidenceLevel: Double
    ) -> ForecastWithConfidence<T>
}

/// Forecast with confidence bands
public struct ForecastWithConfidence<T: Real> {
    public let forecast: TimeSeries<T>
    public let lowerBound: TimeSeries<T>
    public let upperBound: TimeSeries<T>
    public let confidenceLevel: Double

    public init(
        forecast: TimeSeries<T>,
        lowerBound: TimeSeries<T>,
        upperBound: TimeSeries<T>,
        confidenceLevel: Double
    ) {
        self.forecast = forecast
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.confidenceLevel = confidenceLevel
    }
}
```

---

### 2.2 Exponential Smoothing (Holt-Winters)

**File:** `Sources/BusinessMath/Forecasting/ExponentialSmoothing.swift`

```swift
/// Holt-Winters exponential smoothing for forecasting
public struct HoltWintersModel<T: Real>: ForecastModel {

    // Smoothing parameters
    public var alpha: T  // Level
    public var beta: T   // Trend
    public var gamma: T  // Seasonality

    private var level: T?
    private var trend: T?
    private var seasonality: [T] = []
    private var periods: [Period] = []
    private let seasonalPeriods: Int

    public init(
        alpha: T = 0.2,
        beta: T = 0.1,
        gamma: T = 0.1,
        seasonalPeriods: Int = 12  // e.g., 12 for monthly data
    ) {
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.seasonalPeriods = seasonalPeriods
    }

    public mutating func train(on series: TimeSeries<T>) throws {
        let values = series.values

        guard values.count >= seasonalPeriods * 2 else {
            throw ForecastError.insufficientData(
                required: seasonalPeriods * 2,
                got: values.count
            )
        }

        // Initialize level (average of first season)
        let firstSeason = Array(values.prefix(seasonalPeriods))
        level = firstSeason.reduce(0, +) / T(seasonalPeriods)

        // Initialize trend (slope between first two seasons)
        let secondSeason = Array(values.dropFirst(seasonalPeriods).prefix(seasonalPeriods))
        let firstAvg = firstSeason.reduce(0, +) / T(seasonalPeriods)
        let secondAvg = secondSeason.reduce(0, +) / T(seasonalPeriods)
        trend = (secondAvg - firstAvg) / T(seasonalPeriods)

        // Initialize seasonality
        seasonality = Array(repeating: T(1), count: seasonalPeriods)
        for i in 0..<seasonalPeriods {
            let avgValue = (firstSeason[i] + secondSeason[i]) / T(2)
            seasonality[i] = avgValue / level!
        }

        // Update with actual data
        for (index, value) in values.enumerated() {
            let seasonalIndex = index % seasonalPeriods
            let oldLevel = level!
            let oldTrend = trend!

            // Update level
            level = alpha * (value / seasonality[seasonalIndex]) +
                    (T(1) - alpha) * (oldLevel + oldTrend)

            // Update trend
            trend = beta * (level! - oldLevel) +
                    (T(1) - beta) * oldTrend

            // Update seasonality
            seasonality[seasonalIndex] = gamma * (value / level!) +
                                         (T(1) - gamma) * seasonality[seasonalIndex]
        }

        periods = series.periods
    }

    public func predict(periods: Int) -> TimeSeries<T> {
        guard let level = level, let trend = trend else {
            fatalError("Model must be trained before prediction")
        }

        var forecasts: [T] = []
        var forecastPeriods: [Period] = []

        for h in 1...periods {
            let seasonalIndex = (self.periods.count + h - 1) % seasonalPeriods
            let forecast = (level + T(h) * trend) * seasonality[seasonalIndex]
            forecasts.append(forecast)

            // Generate future period
            if let lastPeriod = self.periods.last {
                forecastPeriods.append(lastPeriod + h)
            }
        }

        return TimeSeries(periods: forecastPeriods, values: forecasts)
    }

    public func predictWithConfidence(
        periods: Int,
        confidenceLevel: Double
    ) -> ForecastWithConfidence<T> {
        let forecast = predict(periods: periods)

        // Estimate prediction error (simplified)
        let errorStdDev = estimateErrorStdDev()
        let zScore = T(zScoreForConfidence(confidenceLevel))

        let lower = forecast.map { $0 - zScore * errorStdDev }
        let upper = forecast.map { $0 + zScore * errorStdDev }

        return ForecastWithConfidence(
            forecast: forecast,
            lowerBound: lower,
            upperBound: upper,
            confidenceLevel: confidenceLevel
        )
    }

    private func estimateErrorStdDev() -> T {
        // Simplified - use MAE or RMSE from training
        return T(0.1) * (level ?? T(0))
    }

    private func zScoreForConfidence(_ confidence: Double) -> Double {
        // Approximate z-scores
        switch confidence {
        case 0.90: return 1.645
        case 0.95: return 1.96
        case 0.99: return 2.576
        default: return 1.96
        }
    }
}

public enum ForecastError: Error {
    case insufficientData(required: Int, got: Int)
    case notTrained
    case invalidParameters
}
```

---

### 2.3 Moving Average Forecast

**File:** `Sources/BusinessMath/Forecasting/MovingAverage.swift`

```swift
/// Simple moving average forecast
public struct MovingAverageModel<T: Real>: ForecastModel {

    public let window: Int
    private var historicalValues: [T] = []
    private var periods: [Period] = []

    public init(window: Int = 12) {
        self.window = window
    }

    public mutating func train(on series: TimeSeries<T>) throws {
        historicalValues = series.values
        periods = series.periods

        guard historicalValues.count >= window else {
            throw ForecastError.insufficientData(
                required: window,
                got: historicalValues.count
            )
        }
    }

    public func predict(periods: Int) -> TimeSeries<T> {
        // Use last 'window' values to forecast
        let recentValues = Array(historicalValues.suffix(window))
        let average = recentValues.reduce(0, +) / T(window)

        // Constant forecast (naive)
        let forecasts = Array(repeating: average, count: periods)

        var forecastPeriods: [Period] = []
        if let lastPeriod = self.periods.last {
            for h in 1...periods {
                forecastPeriods.append(lastPeriod + h)
            }
        }

        return TimeSeries(periods: forecastPeriods, values: forecasts)
    }

    public func predictWithConfidence(
        periods: Int,
        confidenceLevel: Double
    ) -> ForecastWithConfidence<T> {
        let forecast = predict(periods: periods)

        // Estimate error from historical variance
        let recentValues = Array(historicalValues.suffix(window))
        let mean = recentValues.reduce(0, +) / T(window)
        let variance = recentValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / T(window)
        let stdDev = sqrt(variance)

        let zScore = T(zScoreForConfidence(confidenceLevel))

        let lower = forecast.map { $0 - zScore * stdDev }
        let upper = forecast.map { $0 + zScore * stdDev }

        return ForecastWithConfidence(
            forecast: forecast,
            lowerBound: lower,
            upperBound: upper,
            confidenceLevel: confidenceLevel
        )
    }

    private func zScoreForConfidence(_ confidence: Double) -> Double {
        switch confidence {
        case 0.90: return 1.645
        case 0.95: return 1.96
        case 0.99: return 2.576
        default: return 1.96
        }
    }
}
```

---

### 2.4 Anomaly Detection

**File:** `Sources/BusinessMath/Forecasting/AnomalyDetection.swift`

```swift
/// Detect anomalies in time series data
public protocol AnomalyDetector {
    associatedtype T: Real

    /// Detect anomalies in time series
    func detect(
        in series: TimeSeries<T>,
        threshold: Double
    ) -> [Anomaly<T>]
}

public struct Anomaly<T: Real> {
    public let period: Period
    public let value: T
    public let expectedValue: T
    public let deviationScore: T  // Z-score or similar
    public let severity: Severity

    public enum Severity {
        case mild      // 2-3 standard deviations
        case moderate  // 3-4 standard deviations
        case severe    // >4 standard deviations
    }
}

/// Z-score based anomaly detection
public struct ZScoreAnomalyDetector<T: Real>: AnomalyDetector {

    public let windowSize: Int

    public init(windowSize: Int = 30) {
        self.windowSize = windowSize
    }

    public func detect(
        in series: TimeSeries<T>,
        threshold: Double = 3.0
    ) -> [Anomaly<T>] {
        var anomalies: [Anomaly<T>] = []
        let values = series.values

        for i in windowSize..<values.count {
            // Calculate rolling statistics
            let window = Array(values[(i - windowSize)..<i])
            let mean = window.reduce(0, +) / T(windowSize)
            let variance = window.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / T(windowSize)
            let stdDev = sqrt(variance)

            // Calculate z-score
            let value = values[i]
            let zScore = abs((value - mean) / stdDev)

            // Check if anomaly
            if Double(zScore) > threshold {
                let severity: Anomaly<T>.Severity
                if Double(zScore) > 4.0 {
                    severity = .severe
                } else if Double(zScore) > 3.0 {
                    severity = .moderate
                } else {
                    severity = .mild
                }

                anomalies.append(Anomaly(
                    period: series.periods[i],
                    value: value,
                    expectedValue: mean,
                    deviationScore: zScore,
                    severity: severity
                ))
            }
        }

        return anomalies
    }
}
```

**Test Cases:**
- ✅ Holt-Winters forecast accuracy
- ✅ Moving average forecast
- ✅ Confidence interval coverage
- ✅ Anomaly detection (synthetic anomalies)
- ✅ Edge cases (short series, no seasonality)

---

## Phase 3: Portfolio Optimization

### 3.1 Portfolio Theory

**File:** `Sources/BusinessMath/Portfolio/Portfolio.swift`

```swift
/// Modern Portfolio Theory implementation
public struct Portfolio<T: Real> {

    public let assets: [String]
    public let returns: [TimeSeries<T>]  // Historical returns for each asset
    public let riskFreeRate: T

    public init(
        assets: [String],
        returns: [TimeSeries<T>],
        riskFreeRate: T = 0.03
    ) {
        precondition(assets.count == returns.count, "Assets and returns must match")
        self.assets = assets
        self.returns = returns
        self.riskFreeRate = riskFreeRate
    }

    /// Calculate expected returns for each asset
    public var expectedReturns: [T] {
        returns.map { series in
            let values = series.values
            return values.reduce(0, +) / T(values.count)
        }
    }

    /// Calculate covariance matrix
    public var covarianceMatrix: [[T]] {
        let n = assets.count
        var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)

        for i in 0..<n {
            for j in 0..<n {
                matrix[i][j] = covariance(returns[i].values, returns[j].values)
            }
        }

        return matrix
    }

    /// Calculate correlation matrix
    public var correlationMatrix: [[T]] {
        let n = assets.count
        var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)
        let cov = covarianceMatrix

        for i in 0..<n {
            for j in 0..<n {
                let stdI = sqrt(cov[i][i])
                let stdJ = sqrt(cov[j][j])
                matrix[i][j] = cov[i][j] / (stdI * stdJ)
            }
        }

        return matrix
    }

    /// Calculate portfolio return for given weights
    public func portfolioReturn(weights: [T]) -> T {
        precondition(weights.count == assets.count)
        let expectedRets = expectedReturns
        var portfolioReturn: T = 0

        for i in 0..<assets.count {
            portfolioReturn += weights[i] * expectedRets[i]
        }

        return portfolioReturn
    }

    /// Calculate portfolio risk (volatility) for given weights
    public func portfolioRisk(weights: [T]) -> T {
        precondition(weights.count == assets.count)
        let cov = covarianceMatrix
        var variance: T = 0

        for i in 0..<assets.count {
            for j in 0..<assets.count {
                variance += weights[i] * weights[j] * cov[i][j]
            }
        }

        return sqrt(variance)
    }

    /// Calculate Sharpe ratio for given weights
    public func sharpeRatio(weights: [T]) -> T {
        let ret = portfolioReturn(weights: weights)
        let risk = portfolioRisk(weights: weights)
        return (ret - riskFreeRate) / risk
    }

    /// Find optimal portfolio (maximize Sharpe ratio)
    public func optimizePortfolio() -> PortfolioAllocation<T> {
        // Use gradient descent to maximize Sharpe ratio
        let n = assets.count

        // Start with equal weights
        var weights = Array(repeating: T(1) / T(n), count: n)

        let learningRate: T = 0.01
        let iterations = 1000

        for _ in 0..<iterations {
            // Calculate gradient of Sharpe ratio
            let currentSharpe = sharpeRatio(weights: weights)
            var gradient = Array(repeating: T(0), count: n)

            for i in 0..<n {
                var weightsPlus = weights
                weightsPlus[i] += 0.001
                weightsPlus = normalizeWeights(weightsPlus)

                let sharpePlus = sharpeRatio(weights: weightsPlus)
                gradient[i] = (sharpePlus - currentSharpe) / 0.001
            }

            // Update weights
            for i in 0..<n {
                weights[i] += learningRate * gradient[i]
            }

            // Normalize and constrain
            weights = normalizeWeights(weights)
            weights = weights.map { max(0, min(1, $0)) }  // Constrain to [0, 1]
            weights = normalizeWeights(weights)
        }

        return PortfolioAllocation(
            assets: assets,
            weights: weights,
            expectedReturn: portfolioReturn(weights: weights),
            risk: portfolioRisk(weights: weights),
            sharpeRatio: sharpeRatio(weights: weights)
        )
    }

    /// Calculate efficient frontier
    public func efficientFrontier(points: Int = 100) -> [PortfolioAllocation<T>] {
        var frontier: [PortfolioAllocation<T>] = []
        let expectedRets = expectedReturns

        // Find min and max returns
        let minReturn = expectedRets.min() ?? T(0)
        let maxReturn = expectedRets.max() ?? T(0)

        let step = (maxReturn - minReturn) / T(points)

        for i in 0..<points {
            let targetReturn = minReturn + T(i) * step

            // Find minimum risk portfolio with this target return
            let weights = minimizeRiskForReturn(targetReturn: targetReturn)

            frontier.append(PortfolioAllocation(
                assets: assets,
                weights: weights,
                expectedReturn: portfolioReturn(weights: weights),
                risk: portfolioRisk(weights: weights),
                sharpeRatio: sharpeRatio(weights: weights)
            ))
        }

        return frontier
    }

    private func minimizeRiskForReturn(targetReturn: T) -> [T] {
        // Simplified: use quadratic programming or gradient descent
        // For now, return equal weights (placeholder)
        let n = assets.count
        return Array(repeating: T(1) / T(n), count: n)
    }

    private func normalizeWeights(_ weights: [T]) -> [T] {
        let sum = weights.reduce(0, +)
        return weights.map { $0 / sum }
    }

    private func covariance(_ x: [T], _ y: [T]) -> T {
        precondition(x.count == y.count)
        let n = T(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var cov: T = 0
        for i in 0..<x.count {
            cov += (x[i] - meanX) * (y[i] - meanY)
        }

        return cov / (n - 1)
    }
}

public struct PortfolioAllocation<T: Real> {
    public let assets: [String]
    public let weights: [T]
    public let expectedReturn: T
    public let risk: T  // Volatility
    public let sharpeRatio: T

    public var description: String {
        var desc = "Portfolio Allocation:\n"
        desc += "  Expected Return: \(expectedReturn * 100)%\n"
        desc += "  Risk (Volatility): \(risk * 100)%\n"
        desc += "  Sharpe Ratio: \(sharpeRatio)\n\n"
        desc += "Weights:\n"
        for (asset, weight) in zip(assets, weights) {
            desc += "  \(asset): \(weight * 100)%\n"
        }
        return desc
    }
}
```

---

### 3.2 Risk Parity

**File:** `Sources/BusinessMath/Portfolio/RiskParity.swift`

```swift
/// Risk parity portfolio allocation
public struct RiskParityOptimizer<T: Real> {

    /// Calculate risk parity weights
    /// Each asset contributes equally to total portfolio risk
    public func optimize(
        assets: [String],
        returns: [TimeSeries<T>]
    ) -> PortfolioAllocation<T> {

        let portfolio = Portfolio(assets: assets, returns: returns)
        let n = assets.count
        let cov = portfolio.covarianceMatrix

        // Start with equal weights
        var weights = Array(repeating: T(1) / T(n), count: n)

        // Iteratively adjust to equalize risk contributions
        let iterations = 100
        let learningRate: T = 0.01

        for _ in 0..<iterations {
            let riskContributions = calculateRiskContributions(
                weights: weights,
                covariance: cov
            )

            let avgRisk = riskContributions.reduce(0, +) / T(n)

            // Adjust weights to move toward equal risk
            for i in 0..<n {
                let diff = riskContributions[i] - avgRisk
                weights[i] -= learningRate * diff
                weights[i] = max(0, weights[i])  // No short selling
            }

            // Normalize
            let sum = weights.reduce(0, +)
            weights = weights.map { $0 / sum }
        }

        return PortfolioAllocation(
            assets: assets,
            weights: weights,
            expectedReturn: portfolio.portfolioReturn(weights: weights),
            risk: portfolio.portfolioRisk(weights: weights),
            sharpeRatio: portfolio.sharpeRatio(weights: weights)
        )
    }

    private func calculateRiskContributions(
        weights: [T],
        covariance: [[T]]
    ) -> [T] {
        let n = weights.count
        var contributions = Array(repeating: T(0), count: n)

        // Calculate total portfolio variance
        var totalVariance: T = 0
        for i in 0..<n {
            for j in 0..<n {
                totalVariance += weights[i] * weights[j] * covariance[i][j]
            }
        }

        let totalRisk = sqrt(totalVariance)

        // Calculate marginal contribution to risk for each asset
        for i in 0..<n {
            var marginalRisk: T = 0
            for j in 0..<n {
                marginalRisk += weights[j] * covariance[i][j]
            }
            contributions[i] = weights[i] * marginalRisk / totalRisk
        }

        return contributions
    }
}
```

**Test Cases:**
- ✅ Portfolio return calculation
- ✅ Portfolio risk calculation
- ✅ Sharpe ratio maximization
- ✅ Efficient frontier generation
- ✅ Risk parity allocation
- ✅ Two-asset vs multi-asset portfolios

---

## Phase 4: Real Options Valuation

### 4.1 Black-Scholes Model

**File:** `Sources/BusinessMath/Options/BlackScholes.swift`

```swift
import Foundation

/// Black-Scholes option pricing model
public struct BlackScholesModel<T: Real> {

    /// Calculate option price using Black-Scholes
    public static func price(
        optionType: OptionType,
        spotPrice: T,
        strikePrice: T,
        timeToExpiry: T,  // In years
        riskFreeRate: T,
        volatility: T
    ) -> T {

        let d1 = (log(spotPrice / strikePrice) +
                  (riskFreeRate + volatility * volatility / T(2)) * timeToExpiry) /
                 (volatility * sqrt(timeToExpiry))

        let d2 = d1 - volatility * sqrt(timeToExpiry)

        switch optionType {
        case .call:
            return spotPrice * cumulativeNormal(d1) -
                   strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)

        case .put:
            return strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2) -
                   spotPrice * cumulativeNormal(-d1)
        }
    }

    /// Calculate Greeks
    public static func greeks(
        optionType: OptionType,
        spotPrice: T,
        strikePrice: T,
        timeToExpiry: T,
        riskFreeRate: T,
        volatility: T
    ) -> Greeks<T> {

        let d1 = (log(spotPrice / strikePrice) +
                  (riskFreeRate + volatility * volatility / T(2)) * timeToExpiry) /
                 (volatility * sqrt(timeToExpiry))

        let d2 = d1 - volatility * sqrt(timeToExpiry)

        // Delta
        let delta: T
        if optionType == .call {
            delta = cumulativeNormal(d1)
        } else {
            delta = cumulativeNormal(d1) - 1
        }

        // Gamma
        let gamma = normalPDF(d1) / (spotPrice * volatility * sqrt(timeToExpiry))

        // Vega
        let vega = spotPrice * normalPDF(d1) * sqrt(timeToExpiry)

        // Theta
        let theta: T
        let term1 = -(spotPrice * normalPDF(d1) * volatility) / (T(2) * sqrt(timeToExpiry))
        if optionType == .call {
            let term2 = riskFreeRate * strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)
            theta = term1 - term2
        } else {
            let term2 = riskFreeRate * strikePrice * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2)
            theta = term1 + term2
        }

        // Rho
        let rho: T
        if optionType == .call {
            rho = strikePrice * timeToExpiry * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)
        } else {
            rho = -strikePrice * timeToExpiry * exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2)
        }

        return Greeks(delta: delta, gamma: gamma, vega: vega, theta: theta, rho: rho)
    }

    /// Cumulative normal distribution
    private static func cumulativeNormal(_ x: T) -> T {
        return (T(1) + erf(x / sqrt(T(2)))) / T(2)
    }

    /// Normal PDF
    private static func normalPDF(_ x: T) -> T {
        return exp(-x * x / T(2)) / sqrt(T(2) * T.pi)
    }

    /// Error function (simplified approximation)
    private static func erf(_ x: T) -> T {
        // Abramowitz and Stegun approximation
        let a1: T =  0.254829592
        let a2: T = -0.284496736
        let a3: T =  1.421413741
        let a4: T = -1.453152027
        let a5: T =  1.061405429
        let p: T  =  0.3275911

        let sign: T = x < 0 ? -1 : 1
        let absX = abs(x)

        let t = T(1) / (T(1) + p * absX)
        let y = T(1) - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)

        return sign * y
    }
}

public enum OptionType {
    case call
    case put
}

public struct Greeks<T: Real> {
    public let delta: T   // Price sensitivity to underlying
    public let gamma: T   // Delta sensitivity to underlying
    public let vega: T    // Price sensitivity to volatility
    public let theta: T   // Price sensitivity to time
    public let rho: T     // Price sensitivity to interest rate

    public var description: String {
        """
        Greeks:
          Delta: \(delta)
          Gamma: \(gamma)
          Vega: \(vega)
          Theta: \(theta)
          Rho: \(rho)
        """
    }
}
```

---

### 4.2 Binomial Tree Model

**File:** `Sources/BusinessMath/Options/BinomialTree.swift`

```swift
/// Binomial tree option pricing (for American options)
public struct BinomialTreeModel<T: Real> {

    public static func price(
        optionType: OptionType,
        americanStyle: Bool = false,
        spotPrice: T,
        strikePrice: T,
        timeToExpiry: T,
        riskFreeRate: T,
        volatility: T,
        steps: Int = 100
    ) -> T {

        let dt = timeToExpiry / T(steps)
        let u = exp(volatility * sqrt(dt))  // Up factor
        let d = T(1) / u  // Down factor
        let p = (exp(riskFreeRate * dt) - d) / (u - d)  // Risk-neutral probability

        // Build price tree
        var tree = Array(repeating: Array(repeating: T(0), count: steps + 1), count: steps + 1)

        // Initialize final nodes
        for i in 0...steps {
            let finalPrice = spotPrice * pow(u, T(steps - i)) * pow(d, T(i))
            tree[i][steps] = intrinsicValue(
                optionType: optionType,
                spotPrice: finalPrice,
                strikePrice: strikePrice
            )
        }

        // Backward induction
        for j in (0..<steps).reversed() {
            for i in 0...j {
                let nodePrice = spotPrice * pow(u, T(j - i)) * pow(d, T(i))

                // Expected value
                let expectedValue = (p * tree[i][j + 1] + (T(1) - p) * tree[i + 1][j + 1]) *
                                    exp(-riskFreeRate * dt)

                if americanStyle {
                    // American option: max of holding vs exercising
                    let exerciseValue = intrinsicValue(
                        optionType: optionType,
                        spotPrice: nodePrice,
                        strikePrice: strikePrice
                    )
                    tree[i][j] = max(expectedValue, exerciseValue)
                } else {
                    // European option
                    tree[i][j] = expectedValue
                }
            }
        }

        return tree[0][0]
    }

    private static func intrinsicValue(
        optionType: OptionType,
        spotPrice: T,
        strikePrice: T
    ) -> T {
        switch optionType {
        case .call:
            return max(T(0), spotPrice - strikePrice)
        case .put:
            return max(T(0), strikePrice - spotPrice)
        }
    }
}
```

---

### 4.3 Real Options Applications

**File:** `Sources/BusinessMath/Options/RealOptions.swift`

```swift
/// Real options for business decisions
public struct RealOptionsAnalysis<T: Real> {

    /// Value option to expand
    public static func expansionOption(
        baseNPV: T,
        expansionCost: T,
        expansionNPV: T,
        volatility: T,
        timeToDecision: T,
        riskFreeRate: T
    ) -> T {
        // Model as call option
        let spotPrice = expansionNPV  // Value of expansion
        let strikePrice = expansionCost  // Cost to expand

        let optionValue = BlackScholesModel<T>.price(
            optionType: .call,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToDecision,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        return baseNPV + optionValue
    }

    /// Value option to abandon
    public static func abandonmentOption(
        projectNPV: T,
        salvageValue: T,
        volatility: T,
        timeToDecision: T,
        riskFreeRate: T
    ) -> T {
        // Model as put option
        let spotPrice = projectNPV
        let strikePrice = salvageValue

        let optionValue = BlackScholesModel<T>.price(
            optionType: .put,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToDecision,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        return projectNPV + optionValue
    }

    /// Decision tree analysis
    public static func decisionTree(
        root: DecisionNode<T>
    ) -> T {
        return evaluateNode(root)
    }

    private static func evaluateNode(_ node: DecisionNode<T>) -> T {
        switch node.type {
        case .terminal:
            return node.value

        case .chance:
            // Expected value over branches
            var expectedValue: T = 0
            for branch in node.branches {
                expectedValue += branch.probability * evaluateNode(branch.node)
            }
            return expectedValue

        case .decision:
            // Choose best decision
            var bestValue: T = T(-Double.infinity)
            for branch in node.branches {
                let value = evaluateNode(branch.node)
                bestValue = max(bestValue, value)
            }
            return bestValue
        }
    }
}

public struct DecisionNode<T: Real> {
    public let type: NodeType
    public let value: T
    public let branches: [Branch<T>]

    public enum NodeType {
        case terminal
        case chance     // Random outcome
        case decision   // Choice point
    }

    public init(type: NodeType, value: T = 0, branches: [Branch<T>] = []) {
        self.type = type
        self.value = value
        self.branches = branches
    }
}

public struct Branch<T: Real> {
    public let probability: T
    public let node: DecisionNode<T>

    public init(probability: T, node: DecisionNode<T>) {
        self.probability = probability
        self.node = node
    }
}
```

**Test Cases:**
- ✅ Black-Scholes call and put prices
- ✅ Greeks calculation
- ✅ Binomial tree (European and American)
- ✅ Real options (expansion, abandonment)
- ✅ Decision tree analysis

---

## Phase 5: Advanced Risk Analytics

### 5.1 Stress Testing

**File:** `Sources/BusinessMath/Risk/StressTesting.swift`

```swift
/// Stress testing framework
public struct StressTest<T: Real> {

    public let scenarios: [StressScenario<T>]

    public init(scenarios: [StressScenario<T>]) {
        self.scenarios = scenarios
    }

    /// Run stress tests on financial projection
    public func run(
        baseline: FinancialProjection<T>,
        drivers: [String: Driver<T>]
    ) -> StressTestReport<T> {

        var results: [ScenarioResult<T>] = []

        for scenario in scenarios {
            // Apply shocks to drivers
            var shockedDrivers = drivers

            for (driverName, shock) in scenario.shocks {
                if var driver = shockedDrivers[driverName] {
                    // Apply shock (multiply by 1 + shock)
                    // This is simplified - real implementation would modify driver
                    shockedDrivers[driverName] = driver.scaled(by: T(1) + shock)
                }
            }

            // Re-run projection with shocked drivers
            // (Simplified - actual implementation depends on model structure)
            let shockedProjection = baseline  // Placeholder

            results.append(ScenarioResult(
                scenario: scenario,
                projection: shockedProjection,
                baselineNPV: calculateNPV(baseline),
                scenarioNPV: calculateNPV(shockedProjection),
                impact: calculateNPV(shockedProjection) - calculateNPV(baseline)
            ))
        }

        return StressTestReport(
            baseline: baseline,
            results: results
        )
    }

    private func calculateNPV(_ projection: FinancialProjection<T>) -> T {
        // Simplified NPV calculation
        return T(0)  // Placeholder
    }
}

public struct StressScenario<T: Real> {
    public let name: String
    public let description: String
    public let shocks: [String: T]  // Driver name -> % change

    public init(name: String, description: String, shocks: [String: T]) {
        self.name = name
        self.description = description
        self.shocks = shocks
    }

    /// Pre-defined scenarios
    public static var recession: StressScenario<T> {
        StressScenario(
            name: "Recession",
            description: "Economic recession scenario",
            shocks: [
                "Revenue": -0.15,      // -15%
                "COGS": 0.05,          // +5% (costs rise)
                "InterestRate": 0.02   // +2% points
            ]
        )
    }

    public static var crisis: StressScenario<T> {
        StressScenario(
            name: "Financial Crisis",
            description: "Severe financial crisis (2008-style)",
            shocks: [
                "Revenue": -0.30,
                "COGS": 0.10,
                "InterestRate": 0.05,
                "CustomerChurn": 0.20
            ]
        )
    }

    public static var supplyShock: StressScenario<T> {
        StressScenario(
            name: "Supply Chain Shock",
            description: "Major supply chain disruption",
            shocks: [
                "COGS": 0.25,
                "DeliveryTime": 0.50,
                "InventoryLevel": -0.30
            ]
        )
    }
}

public struct ScenarioResult<T: Real> {
    public let scenario: StressScenario<T>
    public let projection: FinancialProjection<T>
    public let baselineNPV: T
    public let scenarioNPV: T
    public let impact: T

    public var description: String {
        """
        Scenario: \(scenario.name)
        Baseline NPV: \(baselineNPV)
        Scenario NPV: \(scenarioNPV)
        Impact: \(impact) (\(impact / baselineNPV * 100)%)
        """
    }
}

public struct StressTestReport<T: Real> {
    public let baseline: FinancialProjection<T>
    public let results: [ScenarioResult<T>]

    public var summary: String {
        var report = "Stress Test Summary\n"
        report += "===================\n\n"

        for result in results.sorted(by: { $0.impact < $1.impact }) {
            report += result.description + "\n\n"
        }

        return report
    }

    public var worstCase: ScenarioResult<T>? {
        results.min(by: { $0.scenarioNPV < $1.scenarioNPV })
    }

    public var bestCase: ScenarioResult<T>? {
        results.max(by: { $0.scenarioNPV < $1.scenarioNPV })
    }
}
```

---

### 5.2 Risk Aggregation

**File:** `Sources/BusinessMath/Risk/RiskAggregation.swift`

```swift
/// Aggregate risk across multiple entities/portfolios
public struct RiskAggregator<T: Real> {

    /// Aggregate VaR across entities
    public static func aggregateVaR(
        entities: [Entity],
        individualVaRs: [T],
        correlations: [[T]],
        confidenceLevel: Double = 0.95
    ) -> T {

        let n = entities.count
        precondition(individualVaRs.count == n)
        precondition(correlations.count == n && correlations[0].count == n)

        // Variance-covariance approach
        var totalVariance: T = 0

        for i in 0..<n {
            for j in 0..<n {
                totalVariance += individualVaRs[i] * individualVaRs[j] * correlations[i][j]
            }
        }

        return sqrt(totalVariance)
    }

    /// Marginal VaR contribution
    public static func marginalVaR(
        entity: Int,
        individualVaRs: [T],
        correlations: [[T]]
    ) -> T {

        let n = individualVaRs.count
        let portfolioVaR = aggregateVaR(
            entities: [],  // Not used in calculation
            individualVaRs: individualVaRs,
            correlations: correlations
        )

        var contribution: T = 0
        for j in 0..<n {
            contribution += individualVaRs[j] * correlations[entity][j]
        }

        return individualVaRs[entity] * contribution / portfolioVaR
    }

    /// Component VaR
    public static func componentVaR(
        entities: [Entity],
        individualVaRs: [T],
        weights: [T],
        correlations: [[T]]
    ) -> [T] {

        let n = entities.count
        var components = Array(repeating: T(0), count: n)

        for i in 0..<n {
            let marginal = marginalVaR(
                entity: i,
                individualVaRs: individualVaRs,
                correlations: correlations
            )
            components[i] = weights[i] * marginal
        }

        return components
    }
}
```

---

### 5.3 Comprehensive Risk Metrics

**File:** `Sources/BusinessMath/Risk/RiskMetrics.swift`

```swift
/// Comprehensive risk metrics
public struct ComprehensiveRiskMetrics<T: Real> {

    public let var95: T       // Value at Risk (95%)
    public let var99: T       // Value at Risk (99%)
    public let cvar95: T      // Conditional VaR (Expected Shortfall)
    public let maxDrawdown: T
    public let sharpeRatio: T
    public let sortinoRatio: T
    public let tailRisk: T
    public let skewness: T
    public let kurtosis: T

    public init(returns: TimeSeries<T>, riskFreeRate: T = 0) {
        let values = returns.values.sorted()
        let n = values.count

        // VaR
        let var95Index = Int(Double(n) * 0.05)
        let var99Index = Int(Double(n) * 0.01)
        self.var95 = values[var95Index]
        self.var99 = values[var99Index]

        // CVaR (average of losses beyond VaR)
        let tailLosses = values[0...var95Index]
        self.cvar95 = tailLosses.reduce(0, +) / T(tailLosses.count)

        // Max drawdown
        self.maxDrawdown = Self.calculateMaxDrawdown(values)

        // Sharpe ratio
        let mean = values.reduce(0, +) / T(n)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / T(n)
        let stdDev = sqrt(variance)
        self.sharpeRatio = (mean - riskFreeRate) / stdDev

        // Sortino ratio (downside deviation only)
        let downsideReturns = values.filter { $0 < riskFreeRate }
        let downsideVariance = downsideReturns.map { ($0 - riskFreeRate) * ($0 - riskFreeRate) }.reduce(0, +) / T(downsideReturns.count)
        let downsideDeviation = sqrt(downsideVariance)
        self.sortinoRatio = (mean - riskFreeRate) / downsideDeviation

        // Tail risk
        self.tailRisk = abs(cvar95 / var95)

        // Skewness
        let skew = values.map { pow(($0 - mean) / stdDev, 3) }.reduce(0, +) / T(n)
        self.skewness = skew

        // Kurtosis
        let kurt = values.map { pow(($0 - mean) / stdDev, 4) }.reduce(0, +) / T(n)
        self.kurtosis = kurt - 3  // Excess kurtosis
    }

    private static func calculateMaxDrawdown(_ values: [T]) -> T {
        var maxDrawdown: T = 0
        var peak: T = values[0]

        for value in values {
            if value > peak {
                peak = value
            }
            let drawdown = (peak - value) / peak
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }

        return maxDrawdown
    }

    public var description: String {
        """
        Comprehensive Risk Metrics:
          VaR (95%): \(var95)
          VaR (99%): \(var99)
          CVaR (95%): \(cvar95)
          Max Drawdown: \(maxDrawdown * 100)%
          Sharpe Ratio: \(sharpeRatio)
          Sortino Ratio: \(sortinoRatio)
          Tail Risk: \(tailRisk)
          Skewness: \(skewness)
          Kurtosis: \(kurtosis)
        """
    }
}
```

**Test Cases:**
- ✅ Stress test scenarios
- ✅ VaR aggregation with correlations
- ✅ Marginal and component VaR
- ✅ Comprehensive risk metrics
- ✅ Max drawdown calculation

---

## Testing Strategy

### Unit Tests (Per Phase)

**Phase 1: Optimization**
- Newton-Raphson convergence
- Gradient descent optimization
- Capital allocation (greedy and optimal)
- Constraint satisfaction

**Phase 2: Forecasting**
- Holt-Winters accuracy
- Moving average forecast
- Confidence intervals
- Anomaly detection sensitivity

**Phase 3: Portfolio**
- Return and risk calculations
- Sharpe ratio optimization
- Efficient frontier shape
- Risk parity equal contributions

**Phase 4: Real Options**
- Black-Scholes vs binomial tree
- Greeks accuracy
- American vs European options
- Real options applications

**Phase 5: Risk Analytics**
- Stress test impacts
- VaR aggregation
- Risk metric calculations
- Max drawdown accuracy

---

## Implementation Checklist

### Phase 1: Optimization & Solvers ✅
- [ ] Optimization Framework
  - [ ] Optimizer protocol
  - [ ] OptimizationResult
  - [ ] Constraint types
  - [ ] Tests (5 cases)
- [ ] Newton-Raphson
  - [ ] Enhance existing goalSeek
  - [ ] Add bounds and constraints
  - [ ] Tests (5 cases)
- [ ] Gradient Descent
  - [ ] Basic implementation
  - [ ] Momentum
  - [ ] Tests (5 cases)
- [ ] Capital Allocation
  - [ ] Greedy algorithm
  - [ ] Integer programming (0-1 knapsack)
  - [ ] Tests (8 cases)

### Phase 2: Time Series Forecasting ✅
- [ ] Forecasting Framework
  - [ ] ForecastModel protocol
  - [ ] ForecastWithConfidence
  - [ ] Tests (3 cases)
- [ ] Holt-Winters
  - [ ] Triple exponential smoothing
  - [ ] Confidence intervals
  - [ ] Tests (8 cases)
- [ ] Moving Average
  - [ ] Simple MA forecast
  - [ ] Confidence intervals
  - [ ] Tests (5 cases)
- [ ] Anomaly Detection
  - [ ] Z-score detector
  - [ ] Anomaly struct
  - [ ] Tests (5 cases)

### Phase 3: Portfolio Optimization ✅
- [ ] Portfolio Theory
  - [ ] Returns and risk calculation
  - [ ] Sharpe ratio
  - [ ] Efficient frontier
  - [ ] Tests (10 cases)
- [ ] Risk Parity
  - [ ] Equal risk contribution
  - [ ] Iterative optimization
  - [ ] Tests (5 cases)

### Phase 4: Real Options ✅
- [ ] Black-Scholes
  - [ ] Call and put pricing
  - [ ] Greeks calculation
  - [ ] Tests (8 cases)
- [ ] Binomial Tree
  - [ ] European options
  - [ ] American options
  - [ ] Tests (6 cases)
- [ ] Real Options
  - [ ] Expansion option
  - [ ] Abandonment option
  - [ ] Decision tree
  - [ ] Tests (6 cases)

### Phase 5: Advanced Risk ✅
- [ ] Stress Testing
  - [ ] Scenario framework
  - [ ] Pre-defined scenarios
  - [ ] Stress test report
  - [ ] Tests (5 cases)
- [ ] Risk Aggregation
  - [ ] VaR aggregation
  - [ ] Marginal VaR
  - [ ] Component VaR
  - [ ] Tests (5 cases)
- [ ] Risk Metrics
  - [ ] Comprehensive metrics
  - [ ] Max drawdown
  - [ ] Sharpe and Sortino
  - [ ] Tests (8 cases)

---

## Directory Structure

```
Sources/BusinessMath/
├── Optimization/
│   ├── Optimizer.swift
│   ├── NewtonRaphson.swift
│   ├── GradientDescent.swift
│   └── CapitalAllocation.swift
├── Forecasting/
│   ├── ForecastModel.swift
│   ├── ExponentialSmoothing.swift
│   ├── MovingAverage.swift
│   └── AnomalyDetection.swift
├── Portfolio/
│   ├── Portfolio.swift
│   └── RiskParity.swift
├── Options/
│   ├── BlackScholes.swift
│   ├── BinomialTree.swift
│   └── RealOptions.swift
└── Risk/
    ├── StressTesting.swift
    ├── RiskAggregation.swift
    └── RiskMetrics.swift

Tests/BusinessMathTests/
├── Optimization Tests/
│   ├── OptimizerTests.swift
│   ├── NewtonRaphsonTests.swift
│   ├── GradientDescentTests.swift
│   └── CapitalAllocationTests.swift
├── Forecasting Tests/
│   ├── HoltWintersTests.swift
│   ├── MovingAverageTests.swift
│   └── AnomalyDetectionTests.swift
├── Portfolio Tests/
│   ├── PortfolioTests.swift
│   └── RiskParityTests.swift
├── Options Tests/
│   ├── BlackScholesTests.swift
│   ├── BinomialTreeTests.swift
│   └── RealOptionsTests.swift
└── Risk Tests/
    ├── StressTestingTests.swift
    ├── RiskAggregationTests.swift
    └── RiskMetricsTests.swift
```

---

## Success Criteria

Topic 9 is complete when:

✅ **Optimization**
- Can find optimal values under constraints
- Capital allocation maximizes NPV
- Convergence is reliable

✅ **Forecasting**
- Holt-Winters produces reasonable forecasts
- Confidence intervals are calibrated
- Anomalies are detected accurately

✅ **Portfolio**
- Efficient frontier is computed
- Sharpe ratio is maximized
- Risk parity works

✅ **Real Options**
- Black-Scholes matches known values
- Binomial tree converges to Black-Scholes
- Real options applications work

✅ **Risk Analytics**
- Stress tests show meaningful impacts
- VaR aggregation accounts for correlation
- Risk metrics are comprehensive

✅ **Testing**
- All phases have comprehensive tests
- Numerical accuracy is verified
- Performance is acceptable

---

## Timeline Estimate

**Phase 1: Optimization** - 2-3 days
**Phase 2: Forecasting** - 2-3 days
**Phase 3: Portfolio** - 2-3 days
**Phase 4: Real Options** - 2-3 days
**Phase 5: Risk Analytics** - 1-2 days

**Total:** 9-14 days for complete implementation

---

## Release as v1.15.0

Once all phases are complete and tests pass:

1. Update CHANGELOG.md with Topic 9 features
2. Update Master Plan to mark Topic 9 complete
3. Run full test suite
4. Commit and tag as v1.15.0
5. Push to GitHub
6. Update MCP server to expose optimization and forecasting tools

---

## Integration with Existing Features

Topic 9 builds on:
- **TimeSeries** (Topic 1) - for historical data and forecasts
- **Monte Carlo** (existing) - for risk metrics
- **Financial Statements** (Topic 3) - for stress testing
- **Scenario Analysis** (Topic 4) - enhanced with optimization

---

## Next Steps After Topic 9

With Topics 1-6, 8, and 9 complete, BusinessMath will be a **world-class quantitative finance library**. The only remaining topic is Topic 10 (User Experience & API Design), which focuses on polish, templates, and developer experience.

But first, let's build these advanced features! 🚀
