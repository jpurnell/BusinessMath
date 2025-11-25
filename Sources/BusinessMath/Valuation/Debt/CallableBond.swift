//
//  CallableBond.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Call Provision

/// A call provision specifying when and at what price a bond can be called
///
/// Call provisions allow the issuer to redeem bonds before maturity,
/// typically when interest rates decline. The call price is usually at
/// a premium to face value to compensate investors.
///
/// ## Example
///
/// ```swift
/// // Callable at 105% of par after 3 years
/// let provision = CallProvision(
///     date: callDate,
///     callPrice: 1050.0
/// )
/// ```
public struct CallProvision<T: Real> where T: Sendable {
    /// Date when the bond becomes callable
    public let date: Date

    /// Price at which the bond can be called
    public let callPrice: T

    public init(date: Date, callPrice: T) {
        self.date = date
        self.callPrice = callPrice
    }
}

// MARK: - Callable Bond

/// Bond with embedded call option allowing issuer to redeem early
///
/// A callable bond gives the issuer the right (but not the obligation) to
/// redeem the bond before maturity at specified call prices. This embedded
/// call option has value to the issuer, making callable bonds trade at lower
/// prices than equivalent non-callable bonds.
///
/// ## Pricing Approach
///
/// Uses a binomial interest rate tree with backward induction:
/// 1. Model interest rate evolution using short rate process
/// 2. At each node, calculate continuation value
/// 3. At call dates, take minimum of continuation value and call price
/// 4. Discount back to present
///
/// ## Option-Adjusted Spread (OAS)
///
/// OAS is the constant spread over the risk-free rate that, when added to
/// all discount rates in the tree, produces the observed market price.
/// It represents the credit spread after removing the embedded option value.
///
/// ```
/// Market Price = Price(Risk-Free Rate + OAS, Volatility)
/// OAS = Credit Spread - Option Value
/// ```
///
/// ## Usage Example
///
/// ```swift
/// let bond = Bond(
///     faceValue: 1000.0,
///     couponRate: 0.06,
///     maturityDate: maturity,
///     paymentFrequency: .semiAnnual,
///     issueDate: today
/// )
///
/// let callSchedule = [
///     CallProvision(date: year3, callPrice: 1050.0),
///     CallProvision(date: year5, callPrice: 1030.0),
///     CallProvision(date: year7, callPrice: 1010.0)
/// ]
///
/// let callableBond = CallableBond(
///     bond: bond,
///     callSchedule: callSchedule
/// )
///
/// let price = callableBond.price(
///     riskFreeRate: 0.03,
///     spread: 0.02,
///     volatility: 0.15,
///     asOf: today
/// )
///
/// let oas = try callableBond.optionAdjustedSpread(
///     marketPrice: price,
///     riskFreeRate: 0.03,
///     volatility: 0.15,
///     asOf: today
/// )
/// ```
///
/// ## Important Notes
///
/// - Callable bonds trade at prices **below** non-callable equivalents
/// - Call option value **increases** with volatility
/// - OAS isolates credit risk from option risk
/// - Effective duration accounts for early call possibility
///
/// - SeeAlso:
///   - ``Bond`` for underlying bond specifications
///   - ``CallProvision`` for call schedule details
public struct CallableBond<T: Real> where T: Sendable {

    /// Underlying bond without call feature
    public let bond: Bond<T>

    /// Schedule of call dates and prices
    public let callSchedule: [CallProvision<T>]

    public init(bond: Bond<T>, callSchedule: [CallProvision<T>]) {
        self.bond = bond
        self.callSchedule = callSchedule
    }

    /// Price callable bond using interest rate tree
    ///
    /// Builds a binomial tree for interest rate evolution and applies
    /// backward induction with call option exercise logic at each call date.
    ///
    /// - Parameters:
    ///   - riskFreeRate: Current risk-free short rate
    ///   - spread: Credit spread to add to risk-free rate
    ///   - volatility: Interest rate volatility (annualized)
    ///   - asOf: Valuation date
    ///   - steps: Number of time steps in the tree (default: 100)
    /// - Returns: Callable bond price
    ///
    /// ## Pricing Logic
    ///
    /// At each call date:
    /// - If bond value > call price: Issuer calls, bondholders receive call price
    /// - If bond value ≤ call price: Bond continues (not called)
    ///
    /// Result: Bond value = min(continuation value, call price) at call dates
    public func price(
        riskFreeRate: T,
        spread: T,
        volatility: T,
        asOf: Date = Date(),
        steps: Int = 50
    ) -> T {
        // Calculate time to maturity
        let timeInterval = bond.maturityDate.timeIntervalSince(asOf)

        // Build 365.25 from integer literals
        let wholeDays = T(365)
        let quarterDay = T(1) / T(4)
        let daysPerYear = wholeDays + quarterDay
        let secondsPerYear = daysPerYear * T(24) * T(3600)
        let timeToMaturity = T(Int(timeInterval)) / secondsPerYear

        // Ensure positive time to maturity
        if timeToMaturity <= T(0) {
            return bond.faceValue
        }

        let dt = timeToMaturity / T(steps)
        let totalRate = riskFreeRate + spread

        // Interest rate tree parameters
        // Using additive binomial model: r_up = r + σ√dt, r_down = r - σ√dt
        // This is more appropriate for interest rates than multiplicative model
        let sqrtDt = T.sqrt(dt)
        let rateShift = volatility * sqrtDt

        // Risk-neutral probability (equal probability in symmetric tree)
        let p = T(1) / T(2)

        // Get cash flow schedule
        let cashFlows = bond.cashFlowSchedule(asOf: asOf)

        // For date calculations, we need to work in Double (TimeInterval)
        // Extract the underlying Double value by computing in terms of the original timeInterval
        let timeIntervalDouble = Double(timeInterval)
        let dtDouble = timeIntervalDouble / Double(steps)

        // Build tree - tree[i][j] represents value at node (i,j)
        // i = up-moves, j = time step
        var tree = Array(repeating: Array(repeating: T(0), count: steps + 1), count: steps + 1)

        // Initialize terminal values (at maturity)
        for i in 0...steps {
            // Terminal cash flow is just the final payment
            if let finalCashFlow = cashFlows.last {
                tree[i][steps] = finalCashFlow.amount
            }
        }

        // Backward induction
        for j in (0..<steps).reversed() {
            // Work with time in Double (native for Date operations)
            let currentTimeInterval = Double(j) * dtDouble
            let currentDate = asOf.addingTimeInterval(currentTimeInterval)

            // Find any cash flows at this time step
            let toleranceSeconds = dtDouble
            let stepCashFlow = cashFlowAtStep(
                cashFlows: cashFlows,
                stepDate: currentDate,
                asOf: asOf,
                tolerance: toleranceSeconds
            )

            // Check if this is a call date
            let callPrice = callPriceAt(date: currentDate, tolerance: toleranceSeconds)

            for i in 0...j {
                // Interest rate at this node (additive binomial tree)
                // Start from totalRate and add (j-i) up-moves minus i down-moves
                let netUpMoves = T(j - i) - T(i)
                let rate = totalRate + rateShift * netUpMoves

                // Ensure non-negative interest rate
                let minRate = T(1) / T(1000)  // 0.1%
                let safeRate = rate > minRate ? rate : minRate

                // Continuation value (expected value of next period, discounted)
                let discountFactor = T.exp(-safeRate * dt)
                let expectedValue = (p * tree[i][j + 1] + (T(1) - p) * tree[i + 1][j + 1]) * discountFactor

                // Add any cash flow at this step
                var nodeValue = expectedValue + stepCashFlow

                // Apply call option if applicable
                if let callPx = callPrice {
                    // Issuer calls if bond value > call price
                    // Bondholders receive minimum of bond value or call price
                    nodeValue = min(nodeValue, callPx)
                }

                tree[i][j] = nodeValue
            }
        }

        return tree[0][0]
    }

    /// Calculate value of embedded call option
    ///
    /// Call option value = Non-callable price - Callable price
    ///
    /// - Parameters:
    ///   - riskFreeRate: Current risk-free short rate
    ///   - spread: Credit spread to add to risk-free rate
    ///   - volatility: Interest rate volatility
    ///   - asOf: Valuation date
    /// - Returns: Value of embedded call option (positive = valuable to issuer)
    ///
    /// ## Interpretation
    ///
    /// - Positive value: Option has value to issuer
    /// - Increases with volatility (more optionality)
    /// - Represents compensation investors require for call risk
    public func callOptionValue(
        riskFreeRate: T,
        spread: T,
        volatility: T,
        asOf: Date = Date()
    ) -> T {
        // Price of non-callable bond
        let totalYield = riskFreeRate + spread
        let nonCallablePrice = bond.price(yield: totalYield, asOf: asOf)

        // Price of callable bond
        let callablePrice = price(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volatility,
            asOf: asOf
        )

        // Call option value = what investor gives up by accepting callable bond
        return nonCallablePrice - callablePrice
    }

    /// Calculate option-adjusted spread (OAS) from market price
    ///
    /// Solves for the spread that makes the model price equal to the market price:
    /// ```
    /// Market Price = Price(Risk-Free Rate + OAS, Volatility)
    /// ```
    ///
    /// Uses Newton-Raphson iteration to find the OAS.
    ///
    /// - Parameters:
    ///   - marketPrice: Observed market price of callable bond
    ///   - riskFreeRate: Risk-free short rate
    ///   - volatility: Interest rate volatility
    ///   - asOf: Valuation date
    /// - Returns: Option-adjusted spread (as decimal)
    /// - Throws: `OptimizationError.failedToConverge` if OAS cannot be found
    ///
    /// ## Interpretation
    ///
    /// OAS represents pure credit risk compensation after removing option value:
    /// - Higher OAS → Higher credit risk
    /// - OAS < Nominal Spread (due to embedded option)
    /// - Used to compare bonds with different option features
    ///
    /// ## Example
    ///
    /// ```swift
    /// let oas = try callableBond.optionAdjustedSpread(
    ///     marketPrice: 980.0,
    ///     riskFreeRate: 0.03,
    ///     volatility: 0.15,
    ///     asOf: today
    /// )
    /// // OAS might be 0.018 (180 bps)
    /// ```
    public func optionAdjustedSpread(
        marketPrice: T,
        riskFreeRate: T,
        volatility: T,
        asOf: Date = Date()
    ) throws -> T {
        // Initial guess: use bond's YTM minus risk-free rate
        var oas = try bond.yieldToMaturity(price: marketPrice, asOf: asOf) - riskFreeRate

        let tolerance = T(1) / T(10000)  // 1 bp
        let maxIterations = 100

        for _ in 0..<maxIterations {
            let modelPrice = price(
                riskFreeRate: riskFreeRate,
                spread: oas,
                volatility: volatility,
                asOf: asOf
            )

            let error = modelPrice - marketPrice
            let absError = error < T(0) ? -error : error

            if absError < tolerance {
                return oas
            }

            // Numerical derivative: dPrice/dSpread
            let bump = T(1) / T(1000)  // 10 bps
            let priceUp = price(
                riskFreeRate: riskFreeRate,
                spread: oas + bump,
                volatility: volatility,
                asOf: asOf
            )

            let derivative = (priceUp - modelPrice) / bump

            // Ensure derivative is non-zero
            if derivative == T(0) {
                throw OptimizationError.failedToConverge(
                    message: "OAS derivative is zero"
                )
            }

            // Newton-Raphson update
            oas = oas - error / derivative

            // Ensure OAS stays reasonable
            let minOAS = -T(1) / T(10)  // -10%
            let maxOAS = T(1)  // 100%
            if oas < minOAS { oas = minOAS }
            if oas > maxOAS { oas = maxOAS }
        }

        throw OptimizationError.failedToConverge(
            message: "OAS calculation did not converge"
        )
    }

    /// Calculate effective duration accounting for embedded call option
    ///
    /// Effective duration measures price sensitivity to parallel shifts in
    /// the yield curve, accounting for changes in cash flows due to the
    /// call option.
    ///
    /// Uses finite difference approximation:
    /// ```
    /// Effective Duration = (P- - P+) / (2 × P₀ × Δy)
    /// ```
    ///
    /// Where:
    /// - P- = Price if rates decrease by Δy
    /// - P+ = Price if rates increase by Δy
    /// - P₀ = Current price
    /// - Δy = Small yield change (typically 0.01 = 100 bps)
    ///
    /// - Parameters:
    ///   - riskFreeRate: Risk-free short rate
    ///   - spread: Credit spread
    ///   - volatility: Interest rate volatility
    ///   - asOf: Valuation date
    ///   - shift: Rate shift for calculation (default: 0.01 = 100 bps)
    /// - Returns: Effective duration in years
    ///
    /// ## Interpretation
    ///
    /// - Lower than modified duration for non-callable bonds
    /// - Reflects possibility of early call (shortens effective maturity)
    /// - Negative convexity: duration decreases as rates fall
    ///
    /// ## Example
    ///
    /// ```swift
    /// let effDuration = callableBond.effectiveDuration(
    ///     riskFreeRate: 0.03,
    ///     spread: 0.02,
    ///     volatility: 0.15,
    ///     asOf: today
    /// )
    /// // Might be 4.2 years (vs 7.5 years for non-callable)
    /// ```
    public func effectiveDuration(
        riskFreeRate: T,
        spread: T,
        volatility: T,
        asOf: Date = Date(),
        shift: T = T(1) / T(100)  // 1% = 100 bps
    ) -> T {
        let p0 = price(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volatility,
            asOf: asOf
        )

        let pMinus = price(
            riskFreeRate: riskFreeRate - shift,
            spread: spread,
            volatility: volatility,
            asOf: asOf
        )

        let pPlus = price(
            riskFreeRate: riskFreeRate + shift,
            spread: spread,
            volatility: volatility,
            asOf: asOf
        )

        // Effective duration = (P- - P+) / (2 × P₀ × Δy)
        let numerator = pMinus - pPlus
        let denominator = T(2) * p0 * shift

        return numerator / denominator
    }

    // MARK: - Helper Methods

    /// Find cash flow at a specific time step
    private func cashFlowAtStep(
        cashFlows: [BondCashFlow<T>],
        stepDate: Date,
        asOf: Date,
        tolerance: Double
    ) -> T {
        for cashFlow in cashFlows {
            let timeToFlow = cashFlow.date.timeIntervalSince(stepDate)
            let absTimeDiff = timeToFlow < 0 ? -timeToFlow : timeToFlow

            if absTimeDiff < tolerance {
                return cashFlow.amount
            }
        }
        return T(0)
    }

    /// Find call price at a specific date (if callable)
    private func callPriceAt(date: Date, tolerance: Double) -> T? {
        for provision in callSchedule {
            let timeDiff = provision.date.timeIntervalSince(date)
            let absTimeDiff = timeDiff < 0 ? -timeDiff : timeDiff

            if absTimeDiff < tolerance {
                return provision.callPrice
            }
        }
        return nil
    }
}
