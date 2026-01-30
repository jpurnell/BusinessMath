//
//  DividendDiscountModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Foundation
import Numerics

// MARK: - Gordon Growth Model

/// Gordon Growth Model for equity valuation using constant dividend growth.
///
/// The Gordon Growth Model (also called the Dividend Discount Model or DDM) values a stock
/// based on the present value of an infinite stream of dividends growing at a constant rate.
///
/// This model is best suited for:
/// - Mature, stable companies with predictable dividend growth
/// - Utilities, consumer staples, and other defensive sectors
/// - Companies with established dividend policies
///
/// ## Formula
///
/// ```
/// Value = D₁ / (r - g)
/// ```
///
/// Where:
/// - D₁ = Next year's expected dividend per share
/// - r = Required rate of return (cost of equity)
/// - g = Constant dividend growth rate
///
/// ## Assumptions
///
/// - Dividends grow at a constant rate forever
/// - Growth rate is less than the required return (g < r)
/// - Company pays dividends
/// - Dividend payout ratio is stable
///
/// ## Usage Example
///
/// ```swift
/// // Value a utility stock with $2.50 dividend, 3% growth, 8% required return
/// let model = GordonGrowthModel(
///     dividendPerShare: 2.50,
///     growthRate: 0.03,
///     requiredReturn: 0.08
/// )
///
/// let intrinsicValue = model.valuePerShare()
/// print("Intrinsic value: $\(intrinsicValue)")  // $50.00
/// ```
///
/// ## Important Notes
///
/// - Returns `NaN` or `Infinity` if `growthRate >= requiredReturn` (mathematically undefined)
/// - Returns negative value if `growthRate > requiredReturn` (invalid model)
/// - For zero growth (perpetuity), use `growthRate = 0`
/// - Model is highly sensitive to growth rate assumptions
///
/// - SeeAlso:
///   - ``TwoStageDDM`` for companies transitioning from growth to maturity
///   - ``HModel`` for companies with declining growth rates
///   - ``FCFEModel`` for valuation using free cash flows
public struct GordonGrowthModel<T: Real> where T: Sendable {
    /// Next year's expected dividend per share (D₁)
    public let dividendPerShare: T

    /// Constant dividend growth rate (g), expressed as decimal (e.g., 0.05 for 5%)
    public let growthRate: T

    /// Required rate of return / cost of equity (r), expressed as decimal (e.g., 0.10 for 10%)
    public let requiredReturn: T

    /// Initialize a Gordon Growth Model
    ///
    /// - Parameters:
    ///   - dividendPerShare: Next year's expected dividend per share
    ///   - growthRate: Constant dividend growth rate (as decimal, e.g., 0.05 for 5%)
    ///   - requiredReturn: Required rate of return (as decimal, e.g., 0.10 for 10%)
    public init(
        dividendPerShare: T,
        growthRate: T,
        requiredReturn: T
    ) {
        self.dividendPerShare = dividendPerShare
        self.growthRate = growthRate
        self.requiredReturn = requiredReturn
    }

    /// Calculate the intrinsic value per share
    ///
    /// Formula: `Value = D₁ / (r - g)`
    ///
    /// - Returns: Intrinsic value per share. Returns `NaN`, `Infinity`, or negative value
    ///   if `growthRate >= requiredReturn` (invalid model assumptions).
    ///
    /// - Note: The model is invalid when growth rate equals or exceeds required return,
    ///   as this implies unsustainable growth. In practice, stable companies typically
    ///   have growth rates of 2-6% and required returns of 8-12%.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = GordonGrowthModel(
    ///     dividendPerShare: 3.00,
    ///     growthRate: 0.04,
    ///     requiredReturn: 0.09
    /// )
    /// let value = model.valuePerShare()  // $60.00
    /// ```
    public func valuePerShare() -> T {
        // Formula: V = D / (r - g)
        let denominator = requiredReturn - growthRate

        // Guard against invalid inputs (g >= r)
        guard denominator > T(0) else {
            // Return NaN for invalid inputs (mathematically undefined)
            return T.nan
        }

        return dividendPerShare / denominator
    }
}

// MARK: - Two-Stage Dividend Discount Model

/// Two-Stage Dividend Discount Model for companies transitioning from growth to maturity.
///
/// The Two-Stage DDM is appropriate for companies expected to experience:
/// - High growth in the near term (e.g., 5-10 years)
/// - Transition to stable, lower growth thereafter
///
/// This model is commonly used for:
/// - Growth companies approaching maturity
/// - Tech companies with declining growth rates
/// - Any company in transition between life cycle stages
///
/// ## Formula
///
/// ```
/// Value = PV(High Growth Dividends) + PV(Terminal Value)
/// ```
///
/// Where:
/// - Stage 1: Sum of PV of dividends during high growth period
/// - Stage 2: Terminal value using Gordon Growth Model, discounted to present
///
/// ## Usage Example
///
/// ```swift
/// // Tech company with $1 dividend, 15% growth for 5 years, then 4% stable
/// let model = TwoStageDDM(
///     currentDividend: 1.00,
///     highGrowthRate: 0.15,
///     highGrowthPeriods: 5,
///     stableGrowthRate: 0.04,
///     requiredReturn: 0.10
/// )
///
/// let value = model.valuePerShare()
/// print("Intrinsic value: $\(value)")
/// ```
///
/// - Important: `stableGrowthRate` must be less than `requiredReturn` for terminal value to be valid
///
/// - SeeAlso:
///   - ``GordonGrowthModel`` for the terminal value calculation
///   - ``HModel`` for continuously declining growth
public struct TwoStageDDM<T: Real> where T: Sendable {
    /// Current dividend per share (D₀)
    public let currentDividend: T

    /// High growth rate during initial stage (as decimal)
    public let highGrowthRate: T

    /// Number of periods of high growth
    public let highGrowthPeriods: Int

    /// Stable growth rate after high growth stage (as decimal)
    public let stableGrowthRate: T

    /// Required rate of return / cost of equity (as decimal)
    public let requiredReturn: T

    /// Initialize a Two-Stage Dividend Discount Model
    ///
    /// - Parameters:
    ///   - currentDividend: Current dividend per share (D₀)
    ///   - highGrowthRate: Growth rate during initial high growth stage
    ///   - highGrowthPeriods: Number of years of high growth
    ///   - stableGrowthRate: Growth rate during stable stage (must be < requiredReturn)
    ///   - requiredReturn: Required rate of return
    public init(
        currentDividend: T,
        highGrowthRate: T,
        highGrowthPeriods: Int,
        stableGrowthRate: T,
        requiredReturn: T
    ) {
        self.currentDividend = currentDividend
        self.highGrowthRate = highGrowthRate
        self.highGrowthPeriods = highGrowthPeriods
        self.stableGrowthRate = stableGrowthRate
        self.requiredReturn = requiredReturn
    }

    /// Calculate the intrinsic value per share
    ///
    /// Calculates present value of high growth dividends plus terminal value.
    ///
    /// - Returns: Intrinsic value per share. Returns `NaN` or `Infinity` if
    ///   `stableGrowthRate >= requiredReturn` (invalid terminal value).
    ///
    /// ## Calculation Steps
    ///
    /// 1. Project dividends during high growth phase
    /// 2. Calculate present value of each high growth dividend
    /// 3. Calculate terminal value at end of high growth using Gordon Growth
    /// 4. Discount terminal value to present
    /// 5. Sum all present values
    ///
    /// - Complexity: O(n) where n is `highGrowthPeriods`
    public func valuePerShare() -> T {
        let highGrowthValue = highGrowthPhaseValue()
        let termValue = terminalValue()
        return highGrowthValue + termValue
    }

    /// Calculate the present value of dividends during the high growth phase
    ///
    /// This method returns the sum of discounted dividends paid during the high growth period,
    /// excluding the terminal value. Useful for understanding value composition and performing
    /// sensitivity analysis.
    ///
    /// - Returns: Present value of all dividends during high growth phase. Returns 0 if
    ///   `highGrowthPeriods` is 0.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = TwoStageDDM(
    ///     currentDividend: 1.00,
    ///     highGrowthRate: 0.20,
    ///     highGrowthPeriods: 5,
    ///     stableGrowthRate: 0.05,
    ///     requiredReturn: 0.12
    /// )
    ///
    /// let highGrowthValue = model.highGrowthPhaseValue()  // ~$9.18
    /// let terminalValue = model.terminalValue()           // ~$19.27
    /// print("High growth phase: \(highGrowthValue)")
    /// print("Terminal value: \(terminalValue)")
    /// ```
    ///
    /// - Note: Typically, terminal value represents 60-80% of total value in two-stage models,
    ///   emphasizing that most value comes from the perpetuity, not the high growth years.
    ///
    /// - Complexity: O(n) where n is `highGrowthPeriods`
    public func highGrowthPhaseValue() -> T {
        var presentValue = T(0)
        var dividend = currentDividend

        // Present value of high growth dividends
        // Handle edge case: if highGrowthPeriods is 0, return 0
        if highGrowthPeriods > 0 {
            for period in 1...highGrowthPeriods {
                // Calculate dividend for this period
                dividend = dividend * (T(1) + highGrowthRate)

                // Calculate discount factor
                let discountFactor = T.pow(T(1) + requiredReturn, T(period))

                // Add PV of this dividend
                presentValue += dividend / discountFactor
            }
        }

        return presentValue
    }

    /// Calculate the present value of the terminal value (perpetuity after high growth phase)
    ///
    /// This method calculates the Gordon Growth Model terminal value at the end of the high
    /// growth period, then discounts it back to present value. The terminal value typically
    /// represents the majority of value in two-stage models.
    ///
    /// - Returns: Present value of terminal perpetuity. Returns `NaN` if
    ///   `stableGrowthRate >= requiredReturn` (invalid model).
    ///
    /// ## Formula
    ///
    /// ```
    /// Terminal Value = D(n+1) / (r - g_stable)
    /// PV(Terminal) = Terminal Value / (1 + r)^n
    /// ```
    ///
    /// Where:
    /// - D(n+1) = First dividend in stable phase
    /// - r = Required return
    /// - g_stable = Stable growth rate
    /// - n = High growth periods
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = TwoStageDDM(
    ///     currentDividend: 1.00,
    ///     highGrowthRate: 0.20,
    ///     highGrowthPeriods: 5,
    ///     stableGrowthRate: 0.05,
    ///     requiredReturn: 0.12
    /// )
    ///
    /// let terminalValue = model.terminalValue()  // ~$19.27
    /// let totalValue = model.valuePerShare()     // ~$28.45
    /// let terminalPercentage = terminalValue / totalValue  // ~68%
    /// ```
    ///
    /// - Complexity: O(1) if `highGrowthPeriods` is already known, otherwise O(n)
    public func terminalValue() -> T {
        // Calculate the dividend at end of high growth period
        var dividend = currentDividend
        if highGrowthPeriods > 0 {
            for _ in 1...highGrowthPeriods {
                dividend = dividend * (T(1) + highGrowthRate)
            }
        }

        // First dividend in stable stage
        let firstStableDividend = dividend * (T(1) + stableGrowthRate)

        // Terminal value using Gordon Growth Model
        let terminalValueAtEnd = firstStableDividend / (requiredReturn - stableGrowthRate)

        // Guard against invalid terminal value
        guard !terminalValueAtEnd.isNaN && !terminalValueAtEnd.isInfinite else {
            return T.nan
        }

        // Discount terminal value to present
        let terminalDiscountFactor = T.pow(T(1) + requiredReturn, T(highGrowthPeriods))
        let pvTerminal = terminalValueAtEnd / terminalDiscountFactor

        return pvTerminal
    }
}

// MARK: - H-Model (Fuller-Hsia Model)

/// H-Model for equity valuation with linearly declining dividend growth rate.
///
/// The H-Model (Fuller-Hsia Model) assumes dividend growth declines linearly
/// from an initial high rate to a stable terminal rate over a specified period (2H).
///
/// This model is appropriate for:
/// - Companies with gradually declining growth
/// - More realistic transition than two-stage model
/// - Companies where growth decline is gradual rather than abrupt
///
/// ## Formula
///
/// ```
/// Value = [D₀ × (1 + gₗ)] / (r - gₗ) + [D₀ × H × (gₛ - gₗ)] / (r - gₗ)
/// ```
///
/// Where:
/// - D₀ = Current dividend
/// - gₛ = Initial (short-term) growth rate
/// - gₗ = Terminal (long-term) growth rate
/// - H = Half-life (years for growth to decline to midpoint)
/// - r = Required return
///
/// ## Usage Example
///
/// ```swift
/// // Company with growth declining from 10% to 4% over 8 years
/// let model = HModel(
///     currentDividend: 2.00,
///     initialGrowthRate: 0.10,
///     terminalGrowthRate: 0.04,
///     halfLife: 8,
///     requiredReturn: 0.11
/// )
///
/// let value = model.valuePerShare()
/// print("Intrinsic value: $\(value)")
/// ```
///
/// - SeeAlso:
///   - ``GordonGrowthModel`` for constant growth
///   - ``TwoStageDDM`` for abrupt growth transition
public struct HModel<T: Real> where T: Sendable {
    /// Current dividend per share (D₀)
    public let currentDividend: T

    /// Initial (short-term) high growth rate (as decimal)
    public let initialGrowthRate: T

    /// Terminal (long-term) stable growth rate (as decimal)
    public let terminalGrowthRate: T

    /// Half-life: number of years for growth rate to reach midpoint between initial and terminal
    /// The full transition period is 2H years.
    public let halfLife: Int

    /// Required rate of return / cost of equity (as decimal)
    public let requiredReturn: T

    /// Initialize an H-Model
    ///
    /// - Parameters:
    ///   - currentDividend: Current dividend per share (D₀)
    ///   - initialGrowthRate: Initial high growth rate
    ///   - terminalGrowthRate: Terminal stable growth rate (must be < requiredReturn)
    ///   - halfLife: Half-life in years (full transition = 2H years)
    ///   - requiredReturn: Required rate of return
    public init(
        currentDividend: T,
        initialGrowthRate: T,
        terminalGrowthRate: T,
        halfLife: Int,
        requiredReturn: T
    ) {
        self.currentDividend = currentDividend
        self.initialGrowthRate = initialGrowthRate
        self.terminalGrowthRate = terminalGrowthRate
        self.halfLife = halfLife
        self.requiredReturn = requiredReturn
    }

    /// Calculate the intrinsic value per share
    ///
    /// Uses the Fuller-Hsia H-Model formula with linearly declining growth.
    ///
    /// - Returns: Intrinsic value per share. Returns `NaN` if
    ///   `terminalGrowthRate >= requiredReturn` (invalid model).
    ///
    /// ## Formula Derivation
    ///
    /// The H-Model formula has two components:
    /// 1. Terminal value component: D₀(1+gₗ)/(r-gₗ)
    /// 2. Declining growth premium: D₀×H×(gₛ-gₗ)/(r-gₗ)
    ///
    /// When `initialGrowthRate = terminalGrowthRate`, the model reduces to Gordon Growth.
    ///
    /// - Note: The model assumes linear growth decline over 2H years, which is often
    ///   more realistic than the abrupt transition in the Two-Stage model.
    public func valuePerShare() -> T {
        let denominator = requiredReturn - terminalGrowthRate

        // Guard against invalid inputs
        guard denominator > T(0) else {
            return T.nan
        }

        // First component: Terminal value (Gordon Growth at terminal growth rate)
        let terminalComponent = (currentDividend * (T(1) + terminalGrowthRate)) / denominator

        // Second component: Value from declining growth
        // D₀ × H × (gₛ - gₗ) / (r - gₗ)
        let growthPremium = (currentDividend * T(halfLife) * (initialGrowthRate - terminalGrowthRate)) / denominator

        return terminalComponent + growthPremium
    }
}
