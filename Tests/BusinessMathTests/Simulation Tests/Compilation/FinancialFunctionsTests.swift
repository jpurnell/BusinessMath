import Testing
import Foundation
@testable import BusinessMath

/// Tests for the eight prebuilt expression functions in ``FinancialFunctions``.
///
/// Every one of them shipped without a test, and six had no reference anywhere in the
/// library outside their own doc comments — which is how `blackScholesDiffusion` came to be
/// reported as unreachable. Each test evaluates the function through a
/// `MonteCarloExpressionModel`, the route a caller actually takes, and compares against a
/// value computed independently in the test rather than restating the implementation.
@Suite("Financial Expression Functions")
struct FinancialFunctionsTests {

    /// Evaluates a two-input function through a model, the route a caller takes.
    ///
    /// `call` is variadic and Swift cannot splat an array into it, so arity is spelled out
    /// rather than derived from `inputs.count`.
    ///
    /// - Parameters:
    ///   - function: The prebuilt function under test.
    ///   - inputs: Two inputs, in the order the function documents.
    /// - Returns: The evaluated result.
    private func evaluate(_ function: ExpressionFunction, _ inputs: (Double, Double)) throws -> Double {
        let model = try MonteCarloExpressionModel { builder in
            function.call(builder[0], builder[1])
        }
        return try model.evaluate(inputs: [inputs.0, inputs.1])
    }

    /// Evaluates a three-input function through a model.
    ///
    /// - Parameters:
    ///   - function: The prebuilt function under test.
    ///   - inputs: Three inputs, in the order the function documents.
    /// - Returns: The evaluated result.
    private func evaluate(_ function: ExpressionFunction, _ inputs: (Double, Double, Double)) throws -> Double {
        let model = try MonteCarloExpressionModel { builder in
            function.call(builder[0], builder[1], builder[2])
        }
        return try model.evaluate(inputs: [inputs.0, inputs.1, inputs.2])
    }

    // MARK: - Growth and Change

    @Test("percentChange reports the fractional change from old to new")
    func percentChange() throws {
        // 100 → 110 is a gain of a tenth
        let result = try evaluate(FinancialFunctions.percentChange, (100.0, 110.0))
        #expect(abs(result - 0.10) < 1e-12)

        // A fall is negative: 250 → 200 loses a fifth
        let decline = try evaluate(FinancialFunctions.percentChange, (250.0, 200.0))
        #expect(abs(decline - -0.20) < 1e-12)
    }

    @Test("compoundGrowth compounds the principal over whole periods")
    func compoundGrowth() throws {
        // 1,000 at 5% for 3 periods, computed independently
        let expected = 1_000.0 * pow(1.05, 3.0)
        let result = try evaluate(FinancialFunctions.compoundGrowth, (1_000.0, 0.05, 3.0))
        #expect(abs(result - expected) < 1e-9)

        // Zero periods leaves the principal untouched
        let unchanged = try evaluate(FinancialFunctions.compoundGrowth, (1_000.0, 0.05, 0.0))
        #expect(abs(unchanged - 1_000.0) < 1e-12)
    }

    @Test("presentValue inverts compoundGrowth")
    func presentValue() throws {
        let expected = 1_157.625 / pow(1.05, 3.0)
        let result = try evaluate(FinancialFunctions.presentValue, (1_157.625, 0.05, 3.0))
        #expect(abs(result - expected) < 1e-9)

        // Discounting the future value of a principal returns the principal — the two
        // functions are inverses, which is the property worth pinning rather than a figure.
        let grown = try evaluate(FinancialFunctions.compoundGrowth, (1_000.0, 0.07, 5.0))
        let roundTrip = try evaluate(FinancialFunctions.presentValue, (grown, 0.07, 5.0))
        #expect(abs(roundTrip - 1_000.0) < 1e-9)
    }

    @Test("afterTax withholds the stated rate")
    func afterTax() throws {
        let result = try evaluate(FinancialFunctions.afterTax, (100_000.0, 0.21))
        #expect(abs(result - 79_000.0) < 1e-9)

        // A zero rate is a pass-through
        let untaxed = try evaluate(FinancialFunctions.afterTax, (100_000.0, 0.0))
        #expect(abs(untaxed - 100_000.0) < 1e-12)
    }

    // MARK: - Black-Scholes Terms

    @Test("blackScholesDrift is the risk-neutral drift over the horizon")
    func blackScholesDrift() throws {
        // (r − σ²/2)·t with r = 5%, σ = 20%, t = 1
        let expected = (0.05 - 0.20 * 0.20 * 0.5) * 1.0
        let result = try evaluate(FinancialFunctions.blackScholesDrift, (0.05, 0.20, 1.0))
        #expect(abs(result - expected) < 1e-12)
    }

    @Test("blackScholesDiffusion scales the shock by volatility and root time")
    func blackScholesDiffusion() throws {
        // σ·√t·Z with σ = 20%, t = 4, Z = 1.5
        let expected = 0.20 * sqrt(4.0) * 1.5
        let result = try evaluate(FinancialFunctions.blackScholesDiffusion, (0.20, 4.0, 1.5))
        #expect(abs(result - expected) < 1e-12)

        // A zero shock leaves only the drift, which is what makes the pair a decomposition
        let noShock = try evaluate(FinancialFunctions.blackScholesDiffusion, (0.20, 4.0, 0.0))
        #expect(abs(noShock) < 1e-12)
    }

    @Test("drift and diffusion compose into one GBM step")
    func blackScholesTermsCompose() throws {
        let spot = 100.0, rate = 0.05, volatility = 0.20, time = 1.0, shock = 0.5

        let drift = try evaluate(FinancialFunctions.blackScholesDrift, (rate, volatility, time))
        let diffusion = try evaluate(
            FinancialFunctions.blackScholesDiffusion, (volatility, time, shock))

        // S = S₀ · exp(drift + diffusion) — the reason the two are a matched pair, and the
        // reason removing either one leaves the other unusable.
        let expected = spot * exp((rate - volatility * volatility * 0.5) * time
            + volatility * sqrt(time) * shock)
        #expect(abs(spot * exp(drift + diffusion) - expected) < 1e-9)
    }

    // MARK: - Risk

    @Test("sharpeRatio is excess return per unit of volatility")
    func sharpeRatio() throws {
        // (12% − 3%) / 15%
        let result = try evaluate(FinancialFunctions.sharpeRatio, (0.12, 0.03, 0.15))
        #expect(abs(result - 0.6) < 1e-12)

        // Earning exactly the risk-free rate scores zero
        let flat = try evaluate(FinancialFunctions.sharpeRatio, (0.03, 0.03, 0.15))
        #expect(abs(flat) < 1e-12)
    }

    @Test("valueAtRisk steps down from the mean by z standard deviations")
    func valueAtRisk() throws {
        // μ − z·σ at the 95% one-tailed z
        let expected = 0.08 - 1.645 * 0.20
        let result = try evaluate(FinancialFunctions.valueAtRisk, (0.08, 0.20, 1.645))
        #expect(abs(result - expected) < 1e-12)

        // A zero z-score is the mean itself
        let atMean = try evaluate(FinancialFunctions.valueAtRisk, (0.08, 0.20, 0.0))
        #expect(abs(atMean - 0.08) < 1e-12)
    }

    // MARK: - Arity

    @Test("every prebuilt function declares the arity its formula needs")
    func declaredArities() {
        #expect(FinancialFunctions.percentChange.inputCount == 2)
        #expect(FinancialFunctions.compoundGrowth.inputCount == 3)
        #expect(FinancialFunctions.presentValue.inputCount == 3)
        #expect(FinancialFunctions.afterTax.inputCount == 2)
        #expect(FinancialFunctions.blackScholesDrift.inputCount == 3)
        #expect(FinancialFunctions.blackScholesDiffusion.inputCount == 3)
        #expect(FinancialFunctions.sharpeRatio.inputCount == 3)
        #expect(FinancialFunctions.valueAtRisk.inputCount == 3)
    }
}
