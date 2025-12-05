//
//  PortfolioOptimizationExample.swift
//  BusinessMath Examples
//
//  Demonstrates portfolio optimization using Modern Portfolio Theory
//

import Foundation
@testable import BusinessMath

/// Example: Basic portfolio optimization
func basicPortfolioExample() throws {
    print("=== Basic Portfolio Optimization ===\n")

    // Define 4 assets with expected returns and covariance
    let assets = ["Stock A", "Stock B", "Stock C", "Bond"]
    let expectedReturns = [0.12, 0.15, 0.18, 0.05]  // 12%, 15%, 18%, 5%

    // Covariance matrix (volatilities and correlations)
    let covariance = [
        [0.04, 0.01, 0.02, 0.00],  // Stock A: 20% vol
        [0.01, 0.09, 0.03, 0.01],  // Stock B: 30% vol
        [0.02, 0.03, 0.16, 0.02],  // Stock C: 40% vol
        [0.00, 0.01, 0.02, 0.01]   // Bond: 10% vol
    ]

    print("Assets:")
    for (i, name) in assets.enumerated() {
        let ret = expectedReturns[i] * 100
        let vol = sqrt(covariance[i][i]) * 100
        print(String(format: "  %s: %.0f%% return, %.0f%% volatility", name, ret, vol))
    }
    print()

    let optimizer = PortfolioOptimizer(
        expectedReturns: expectedReturns,
        covarianceMatrix: covariance
    )

    // 1. Minimum Variance Portfolio
    print("1. Minimum Variance Portfolio (lowest risk):")
    let minVar = try optimizer.minimumVariance(constraints: .longOnly)
    print(String(format: "   Expected Return: %.2f%%", minVar.expectedReturn * 100))
    print(String(format: "   Risk (Std Dev): %.2f%%", minVar.risk * 100))
    print("   Weights:")
    for (i, weight) in minVar.weights.enumerated() {
        if weight > 0.01 {
            print(String(format: "     %s: %.1f%%", assets[i], weight * 100))
        }
    }
    print()

    // 2. Maximum Sharpe Ratio
    print("2. Maximum Sharpe Ratio (best risk-adjusted return):")
    let riskFreeRate = 0.02  // 2%
    let maxSharpe = try optimizer.maximizeSharpe(
        riskFreeRate: riskFreeRate,
        constraints: .longOnly
    )
    print(String(format: "   Sharpe Ratio: %.2f", maxSharpe.sharpeRatio))
    print(String(format: "   Expected Return: %.2f%%", maxSharpe.expectedReturn * 100))
    print(String(format: "   Risk (Std Dev): %.2f%%", maxSharpe.risk * 100))
    print("   Weights:")
    for (i, weight) in maxSharpe.weights.enumerated() {
        if weight > 0.01 {
            print(String(format: "     %s: %.1f%%", assets[i], weight * 100))
        }
    }
    print()

    // 3. Target Return Portfolio
    print("3. Target Return Portfolio (achieve 12% with minimum risk):")
    let targetRet = try optimizer.targetReturn(0.12, constraints: .longOnly)
    print(String(format: "   Expected Return: %.2f%% (target: 12.0%%)", targetRet.expectedReturn * 100))
    print(String(format: "   Risk (Std Dev): %.2f%%", targetRet.risk * 100))
    print("   Weights:")
    for (i, weight) in targetRet.weights.enumerated() {
        if weight > 0.01 {
            print(String(format: "     %s: %.1f%%", assets[i], weight * 100))
        }
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Efficient Frontier generation
func efficientFrontierExample() throws {
    print("=== Efficient Frontier Example ===\n")

    let expectedReturns = [0.08, 0.12, 0.16]
    let covariance = [
        [0.04, 0.01, 0.02],
        [0.01, 0.09, 0.03],
        [0.02, 0.03, 0.16]
    ]

    let optimizer = PortfolioOptimizer(
        expectedReturns: expectedReturns,
        covarianceMatrix: covariance
    )

    print("Generating efficient frontier (20 portfolios)...\n")

    let frontier = try optimizer.efficientFrontier(
        numberOfPoints: 20,
        constraints: .longOnly
    )

    print("Efficient Frontier:")
    print(String(repeating: "-", count: 50))
    print(String(format: "%-12s | %-12s | %s", "Risk", "Return", "Sharpe (rf=2%)"))
    print(String(repeating: "-", count: 50))

    for portfolio in frontier.portfolios {
        let risk = portfolio.risk * 100
        let ret = portfolio.expectedReturn * 100
        let sharpe = (portfolio.expectedReturn - 0.02) / portfolio.risk

        print(String(format: "%10.2f%% | %10.2f%% | %10.2f", risk, ret, sharpe))
    }
    print(String(repeating: "-", count: 50))
    print()

    if let minRisk = frontier.minRiskPortfolio {
        print("Minimum Risk Portfolio:")
        print(String(format: "  Risk: %.2f%%, Return: %.2f%%",
                      minRisk.risk * 100, minRisk.expectedReturn * 100))
    }

    if let maxReturn = frontier.maxReturnPortfolio {
        print("Maximum Return Portfolio:")
        print(String(format: "  Risk: %.2f%%, Return: %.2f%%",
                      maxReturn.risk * 100, maxReturn.expectedReturn * 100))
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Risk Parity portfolio
func riskParityExample() throws {
    print("=== Risk Parity Portfolio ===\n")

    // 3 assets with different risk profiles
    let assets = ["Low Vol Stock", "Medium Vol Stock", "High Vol Stock"]
    let expectedReturns = [0.08, 0.10, 0.12]
    let covariance = [
        [0.01, 0.00, 0.01],  // 10% vol
        [0.00, 0.04, 0.02],  // 20% vol
        [0.01, 0.02, 0.09]   // 30% vol
    ]

    print("Assets:")
    for (i, name) in assets.enumerated() {
        let vol = sqrt(covariance[i][i]) * 100
        print(String(format: "  %s: %.0f%% volatility", name, vol))
    }
    print()

    let optimizer = PortfolioOptimizer(
        expectedReturns: expectedReturns,
        covarianceMatrix: covariance
    )

    // Risk parity: Each asset contributes equally to portfolio risk
    let riskParity = try optimizer.riskParity()

    print("Risk Parity Portfolio:")
    print("Each asset contributes ~33% of total risk")
    print()
    print("Weights:")
    for (i, weight) in riskParity.weights.enumerated() {
        print(String(format: "  %s: %.1f%%", assets[i], weight * 100))
    }
    print()

    if let contributions = riskParity.riskContributions {
        print("Risk Contributions:")
        for (i, contribution) in contributions.enumerated() {
            print(String(format: "  %s: %.1f%%", assets[i], contribution * 100))
        }
    }

    print()
    print(String(format: "Portfolio Risk: %.2f%%", riskParity.risk * 100))
    print(String(format: "Portfolio Return: %.2f%%", riskParity.expectedReturn * 100))

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Constrained portfolios
func constrainedPortfolioExample() throws {
    print("=== Constrained Portfolio Optimization ===\n")

    let expectedReturns = [0.10, 0.12, 0.15, 0.18]
    let covariance = [
        [0.04, 0.01, 0.02, 0.01],
        [0.01, 0.09, 0.03, 0.02],
        [0.02, 0.03, 0.16, 0.04],
        [0.01, 0.02, 0.04, 0.25]
    ]

    let optimizer = PortfolioOptimizer(
        expectedReturns: expectedReturns,
        covarianceMatrix: covariance
    )

    print("Comparing different constraint sets:\n")

    // 1. Long-only (no short-selling)
    print("1. Long-Only Portfolio (no short-selling):")
    let longOnly = try optimizer.maximizeSharpe(
        riskFreeRate: 0.02,
        constraints: .longOnly
    )
    print(String(format: "   Sharpe: %.2f, Return: %.2f%%, Risk: %.2f%%",
                  longOnly.sharpeRatio, longOnly.expectedReturn * 100, longOnly.risk * 100))
    print("   Weights: \(longOnly.weights.map { String(format: "%.1f%%", $0 * 100) })")
    print()

    // 2. Long-short with leverage limit
    print("2. Long-Short with 130/30 strategy (30% short, 130% long):")
    let longShort = try optimizer.maximizeSharpe(
        riskFreeRate: 0.02,
        constraints: .longShort(maxLeverage: 1.3)
    )
    print(String(format: "   Sharpe: %.2f, Return: %.2f%%, Risk: %.2f%%",
                  longShort.sharpeRatio, longShort.expectedReturn * 100, longShort.risk * 100))
    print("   Weights: \(longShort.weights.map { String(format: "%.1f%%", $0 * 100) })")
    print()

    // 3. Box constraints (position limits)
    print("3. Box Constrained (min 5%, max 40% per position):")
    let boxConstrained = try optimizer.maximizeSharpe(
        riskFreeRate: 0.02,
        constraints: .boxConstrained(min: 0.05, max: 0.40)
    )
    print(String(format: "   Sharpe: %.2f, Return: %.2f%%, Risk: %.2f%%",
                  boxConstrained.sharpeRatio, boxConstrained.expectedReturn * 100, boxConstrained.risk * 100))
    print("   Weights: \(boxConstrained.weights.map { String(format: "%.1f%%", $0 * 100) })")
    print()

    print("Note: More flexibility (long-short, wider limits) typically improves Sharpe ratio")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Real-world portfolio scenario
func realWorldPortfolioExample() throws {
    print("=== Real-World Portfolio Example ===\n")

    print("Scenario: $1M portfolio with 5 asset classes")
    print()

    let assets = [
        "US Large Cap",
        "US Small Cap",
        "International",
        "Bonds",
        "Real Estate"
    ]

    // Historical estimates
    let expectedReturns = [0.10, 0.12, 0.11, 0.04, 0.09]
    let covariance = [
        [0.0225, 0.0180, 0.0150, 0.0020, 0.0100],  // US Large: 15% vol
        [0.0180, 0.0400, 0.0200, 0.0010, 0.0150],  // US Small: 20% vol
        [0.0150, 0.0200, 0.0400, 0.0030, 0.0120],  // Intl: 20% vol
        [0.0020, 0.0010, 0.0030, 0.0016, 0.0010],  // Bonds: 4% vol
        [0.0100, 0.0150, 0.0120, 0.0010, 0.0256]   // RE: 16% vol
    ]

    print("Asset Classes:")
    for (i, name) in assets.enumerated() {
        let ret = expectedReturns[i] * 100
        let vol = sqrt(covariance[i][i]) * 100
        print(String(format: "  %s: %.1f%% return, %.1f%% vol", name, ret, vol))
    }
    print()

    let optimizer = PortfolioOptimizer(
        expectedReturns: expectedReturns,
        covarianceMatrix: covariance
    )

    // Conservative investor (minimize risk)
    print("Conservative Portfolio (minimum variance):")
    let conservative = try optimizer.minimumVariance(constraints: .longOnly)
    print(String(format: "  Expected Return: %.2f%%", conservative.expectedReturn * 100))
    print(String(format: "  Risk: %.2f%%", conservative.risk * 100))
    print("  Allocation:")
    for (i, weight) in conservative.weights.enumerated() {
        if weight > 0.01 {
            let allocation = 1_000_000 * weight
            print(String(format: "    %s: $%,.0f (%.1f%%)", assets[i], allocation, weight * 100))
        }
    }
    print()

    // Moderate investor (max Sharpe)
    print("Moderate Portfolio (maximum risk-adjusted return):")
    let moderate = try optimizer.maximizeSharpe(
        riskFreeRate: 0.03,
        constraints: .longOnly
    )
    print(String(format: "  Sharpe Ratio: %.2f", moderate.sharpeRatio))
    print(String(format: "  Expected Return: %.2f%%", moderate.expectedReturn * 100))
    print(String(format: "  Risk: %.2f%%", moderate.risk * 100))
    print("  Allocation:")
    for (i, weight) in moderate.weights.enumerated() {
        if weight > 0.01 {
            let allocation = 1_000_000 * weight
            print(String(format: "    %s: $%,.0f (%.1f%%)", assets[i], allocation, weight * 100))
        }
    }
    print()

    // Aggressive investor (target high return)
    print("Aggressive Portfolio (target 10% return, minimum risk):")
    let aggressive = try optimizer.targetReturn(0.10, constraints: .longOnly)
    print(String(format: "  Expected Return: %.2f%%", aggressive.expectedReturn * 100))
    print(String(format: "  Risk: %.2f%%", aggressive.risk * 100))
    print("  Allocation:")
    for (i, weight) in aggressive.weights.enumerated() {
        if weight > 0.01 {
            let allocation = 1_000_000 * weight
            print(String(format: "    %s: $%,.0f (%.1f%%)", assets[i], allocation, weight * 100))
        }
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Portfolio Optimization Examples")
print(String(repeating: "=", count: 50))
print("\n")

try basicPortfolioExample()
try efficientFrontierExample()
try riskParityExample()
try constrainedPortfolioExample()
try realWorldPortfolioExample()

print("Examples complete!")
print()
print("Key Concepts:")
print("  • Minimum Variance: Lowest risk portfolio")
print("  • Maximum Sharpe: Best risk-adjusted return")
print("  • Efficient Frontier: Risk-return trade-off curve")
print("  • Risk Parity: Equal risk contribution from each asset")
print("  • Constraints: Long-only, leverage limits, position limits")
