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
		print("  \(name): \(ret.formatted())% return, \(vol.formatted())% volatility")
	}
	print()

	let optimizer = PortfolioOptimizer()
	let returns = VectorN(expectedReturns)

	// 1. Minimum Variance Portfolio
	print("1. Minimum Variance Portfolio (lowest risk):")
	let minVar = try optimizer.minimumVariancePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		allowShortSelling: false
	)
	print("   Expected Return: \((minVar.expectedReturn * 100).formatted())%")
	print("   Risk (Std Dev): \((minVar.volatility * 100).formatted())%")
	print("   Weights:")
	for (i, weight) in minVar.weights.toArray().enumerated() {
		if weight > 0.01 {
			print("\(assets[i].paddingLeft(toLength: 12)): \((weight * 100).formatted())%")
		}
	}
	print()

	// 2. Maximum Sharpe Ratio
	print("2. Maximum Sharpe Ratio (best risk-adjusted return):")
	let riskFreeRate = 0.02  // 2%
	let maxSharpe = try optimizer.maximumSharpePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: riskFreeRate,
		constraintSet: .longOnly
	)
	print("   Sharpe Ratio: \(maxSharpe.sharpeRatio.formatted())")
	print("   Expected Return: \((maxSharpe.expectedReturn * 100).formatted())%")
	print("   Risk (Std Dev): \((maxSharpe.volatility * 100).formatted())%")
	print("   Weights:")
	for (i, weight) in maxSharpe.weights.toArray().enumerated() {
		if weight > 0.01 {
			print("\(assets[i].paddingLeft(toLength: 12)): \((weight * 100).formatted())%")
		}
	}
	print()

	// 3. Target Return Portfolio
	print("3. Target Return Portfolio (achieve 12% with minimum risk):")
	let targetRet = try optimizer.portfolioForTargetReturn(
		targetReturn: 0.12,
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: riskFreeRate
	)
	print("   Expected Return: \((targetRet.expectedReturn * 100).formatted())% (target: 12.0%%)")
	print("   Risk (Std Dev): \((targetRet.volatility * 100).formatted())%")
	print("   Weights:")
	for (i, weight) in targetRet.weights.toArray().enumerated() {
		if weight > 0.01 {
			print("\(assets[i].paddingLeft(toLength: 12)): \((weight * 100).formatted())%")
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

	let optimizer = PortfolioOptimizer()
	let returns = VectorN(expectedReturns)

	print("Generating efficient frontier (20 portfolios)...\n")

	let frontier = try optimizer.efficientFrontier(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.02,
		numberOfPoints: 20
	)

	print("Efficient Frontier:")
	print(String(repeating: "-", count: 50))
	print("\("Risk".paddingLeft(toLength: 12)) | \("Return".paddingLeft(toLength: 12)) | \("Sharpe (rf=2%)".paddingLeft(toLength: 14))")
	print(String(repeating: "-", count: 50))

	for portfolio in frontier.portfolios {
		let risk = portfolio.volatility * 100
		let ret = portfolio.expectedReturn * 100
		let sharpe = portfolio.sharpeRatio

		print("\(risk.formatted().paddingLeft(toLength: 11))% | \(ret.formatted().paddingLeft(toLength: 11))% | \(sharpe.formatted().paddingLeft(toLength: 14))")
	}
	print(String(repeating: "-", count: 50))
	print()

	let minRisk = frontier.minimumVariancePortfolio
	print("Minimum Risk Portfolio:")
	print("  Risk: \((minRisk.volatility * 100).formatted())%, Return: \((minRisk.expectedReturn * 100).formatted())%")

	let maxSharpe = frontier.maximumSharpePortfolio
	print("Maximum Sharpe Portfolio:")
	print("  Risk: \((maxSharpe.volatility * 100).formatted())%, Return: \((maxSharpe.expectedReturn * 100).formatted())%, Sharpe: \(maxSharpe.sharpeRatio.formatted())")

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
		print("  \(name): \(vol.formatted())% volatility")
	}
	print()

	let optimizer = PortfolioOptimizer()
	let returns = VectorN(expectedReturns)

	// Risk parity: Each asset contributes equally to portfolio risk
	let riskParity = try optimizer.riskParityPortfolio(
		expectedReturns: returns,
		covariance: covariance,
		constraintSet: .longOnly
	)

	print("Risk Parity Portfolio:")
	print("Each asset contributes ~33% of total risk")
	print()
	print("Weights:")
	for (i, weight) in riskParity.weights.toArray().enumerated() {
		print("  \(assets[i]): \((weight * 100).formatted())%")
	}

	print()
	print("Portfolio Risk: \((riskParity.volatility * 100).formatted())%")
	print("Portfolio Return: \((riskParity.expectedReturn * 100).formatted())%")
	print()
	print("Note: Risk contributions can be calculated from the weights and covariance matrix")

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

	let optimizer = PortfolioOptimizer()
	let returns = VectorN(expectedReturns)

	print("Comparing different constraint sets:\n")

	// 1. Long-only (no short-selling)
	print("1. Long-Only Portfolio (no short-selling):")
	let longOnly = try optimizer.maximumSharpePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.02,
		constraintSet: .longOnly
	)
	print("   Sharpe: \(longOnly.sharpeRatio.formatted()), Return: \((longOnly.expectedReturn * 100).formatted())%, Risk: \((longOnly.volatility * 100).formatted())%")
	print("   Weights: \(longOnly.weights.toArray().map{ "\(($0 * 100).formatted())%" })")
	print()

	// 2. Long-short with leverage limit
	print("2. Long-Short with 130/30 strategy (30% short, 130% long):")
	let longShort = try optimizer.maximumSharpePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.02,
		constraintSet: .longShort(maxLeverage: 1.3)
	)
	print("   Sharpe: \(longShort.sharpeRatio.formatted()), Return: \((longShort.expectedReturn * 100).formatted())%, Risk: \((longShort.volatility * 100).formatted())%")
	print("   Weights: \(longShort.weights.toArray().map{ "\(($0 * 100).formatted())%" })")
	print()

	// 3. Box constraints (position limits)
	print("3. Box Constrained (min 5%, max 40% per position):")
	let boxConstrained = try optimizer.maximumSharpePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.02,
		constraintSet: .boxConstrained(min: 0.05, max: 0.40)
	)
	print("   Sharpe: \(boxConstrained.sharpeRatio.formatted()), Return: \((boxConstrained.expectedReturn * 100).formatted())%, Risk: \((boxConstrained.volatility * 100).formatted())%")
	print("   Weights: \(boxConstrained.weights.toArray().map{ "\(($0 * 100).formatted())%" })")
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
		print("  \(name.paddingLeft(toLength: 14)): \(ret.formatted())% return, \(vol.formatted())% vol")
	}
	print()

	let optimizer = PortfolioOptimizer()
	let returns = VectorN(expectedReturns)

	// Conservative investor (minimize risk)
	print("Conservative Portfolio (minimum variance):")
	let conservative = try optimizer.minimumVariancePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		allowShortSelling: false
	)
	print("  Expected Return: \((conservative.expectedReturn * 100).formatted())%")
	print("  Risk: \((conservative.volatility * 100).formatted())%")
	print("  Allocation:")
	for (i, weight) in conservative.weights.toArray().enumerated() {
		if weight > 0.01 {
			let allocation = 1_000_000 * weight
			print("    \(assets[i].paddingLeft(toLength: 14)): \(allocation.currency()) (\((weight * 100).formatted())%)")
		}
	}
	print()

	// Moderate investor (max Sharpe)
	print("Moderate Portfolio (maximum risk-adjusted return):")
	let moderate = try optimizer.maximumSharpePortfolio(
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.03,
		constraintSet: .longOnly
	)
	print("  Sharpe Ratio: \(moderate.sharpeRatio.formatted())")
	print("  Expected Return: \((moderate.expectedReturn * 100).formatted())%")
	print("  Risk: \((moderate.volatility * 100).formatted())%")
	print("  Allocation:")
	for (i, weight) in moderate.weights.toArray().enumerated() {
		if weight > 0.01 {
			let allocation = 1_000_000 * weight
			print("    \(assets[i].paddingLeft(toLength: 14)): \(allocation.currency()) (\((weight * 100).formatted())%)")
		}
	}
	print()

	// Aggressive investor (target high return)
	print("Aggressive Portfolio (target 10% return, minimum risk):")
	let aggressive = try optimizer.portfolioForTargetReturn(
		targetReturn: 0.10,
		expectedReturns: returns,
		covariance: covariance,
		riskFreeRate: 0.03
	)
	print("  Expected Return: \((aggressive.expectedReturn * 100).formatted())%")
	print("  Risk: \((aggressive.volatility * 100).formatted())%")
	print("  Allocation:")
	for (i, weight) in aggressive.weights.toArray().enumerated() {
		if weight > 0.01 {
			let allocation = 1_000_000 * weight
			print("    \(assets[i].paddingLeft(toLength: 14)): \(allocation.currency()) (\((weight * 100).formatted())%)")
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
