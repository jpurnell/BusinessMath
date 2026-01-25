//
//  BondPricing.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Cash Flow Type

/// Type of cash flow from a bond
public enum BondCashFlowType: Sendable {
    case coupon
    case principal
    case callRedemption
    case putRedemption
}

// MARK: - Bond Cash Flow

/// Represents a single cash flow from a bond
public struct BondCashFlow<T: Real>: Sendable where T: Sendable {
    public let date: Date
    public let amount: T
    public let type: BondCashFlowType

    public init(date: Date, amount: T, type: BondCashFlowType) {
        self.date = date
        self.amount = amount
        self.type = type
    }
}

// MARK: - Bond Protocol

/// Protocol for any instrument that can be priced like a bond
public protocol BondLike {
    associatedtype T: Real where T: Sendable

    /// Generate cash flow schedule
    func cashFlowSchedule(asOf: Date) -> [BondCashFlow<T>]

    /// Price the bond given a yield
    func price(yield: T, asOf: Date) -> T

    /// Calculate yield to maturity given a price
    func yieldToMaturity(price: T, asOf: Date) throws -> T

    /// Face value of the bond
    var faceValue: T { get }

    /// Maturity date
    var maturityDate: Date { get }
}

// MARK: - Fixed-Rate Bond

/// Traditional fixed-rate bond with periodic coupon payments
///
/// This is the most common type of bond, featuring:
/// - Fixed coupon rate
/// - Periodic interest payments (annual, semiannual, quarterly, or monthly)
/// - Principal repayment at maturity (bullet structure)
/// - Standard pricing and yield calculations
///
/// ## Overview
///
/// A fixed-rate bond pays a constant coupon (interest) payment at regular intervals
/// and returns the full principal at maturity. The price of the bond is the present
/// value of all future cash flows discounted at the yield to maturity.
///
/// ## Pricing Formula
///
/// ```
/// Price = Σ(Coupon / (1 + y/m)^t) + Face Value / (1 + y/m)^n
/// ```
///
/// Where:
/// - Coupon = Face Value × Coupon Rate / m
/// - y = Yield to maturity (annual)
/// - m = Payments per year
/// - n = Total number of periods
/// - t = Period number
///
/// ## Bond Price Relationships
///
/// - **Par**: Price = Face Value when Coupon Rate = Yield
/// - **Premium**: Price > Face Value when Coupon Rate > Yield
/// - **Discount**: Price < Face Value when Coupon Rate < Yield
///
/// ## Usage Example
///
/// ```swift
/// // Create a 10-year bond with 5% coupon, semiannual payments
/// let bond = Bond(
///     faceValue: 1000.0,
///     couponRate: 0.05,
///     maturityDate: Date().addingTimeInterval(10 * 365 * 24 * 3600),
///     paymentFrequency: .semiannual,
///     issueDate: Date()
/// )
///
/// // Price at 6% yield
/// let price = bond.price(yield: 0.06)
/// print("Bond price: $\(price)")  // Will be < $1000 (discount)
///
/// // Calculate YTM for a bond trading at $950
/// let ytm = try bond.yieldToMaturity(price: 950.0)
/// print("Yield to maturity: \(ytm * 100)%")
/// ```
///
/// - SeeAlso:
///   - ``ZeroCouponBond`` for bonds without coupon payments
///   - ``AmortizingBond`` for bonds with principal amortization
public struct Bond<T: Real>: BondLike where T: Sendable {

    /// Face value (par value) of the bond
    public let faceValue: T

    /// Annual coupon rate (as decimal, e.g., 0.05 for 5%)
    public let couponRate: T

    /// Date when the bond matures and principal is repaid
    public let maturityDate: Date

    /// Frequency of coupon payments
    public let paymentFrequency: PaymentFrequency

    /// Date when the bond was issued
    public let issueDate: Date

    /// Initialize a fixed-rate bond
    ///
    /// - Parameters:
    ///   - faceValue: Par value of the bond (typically $1000)
    ///   - couponRate: Annual coupon rate (e.g., 0.05 for 5%)
    ///   - maturityDate: Date when bond matures
    ///   - paymentFrequency: How often coupons are paid
    ///   - issueDate: Date when bond was issued
    public init(
        faceValue: T,
        couponRate: T,
        maturityDate: Date,
        paymentFrequency: PaymentFrequency,
        issueDate: Date
    ) {
        self.faceValue = faceValue
        self.couponRate = couponRate
        self.maturityDate = maturityDate
        self.paymentFrequency = paymentFrequency
        self.issueDate = issueDate
    }

    /// Generate the complete cash flow schedule for the bond
    ///
    /// Creates a list of all future coupon payments and the principal repayment.
    ///
    /// - Parameter asOf: Valuation date (defaults to today)
    /// - Returns: Array of cash flows sorted by date
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cashFlows = bond.cashFlowSchedule()
    /// for cf in cashFlows {
    ///     print("\(cf.date): $\(cf.amount) (\(cf.type))")
    /// }
    /// ```
    public func cashFlowSchedule(asOf: Date = Date()) -> [BondCashFlow<T>] {
        var cashFlows: [BondCashFlow<T>] = []

        let calendar = Calendar.current
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)  // Convert Int to T
        let couponPayment = faceValue * couponRate / m

        // Calculate months between payments
        let monthsBetween = 12 / periodsPerYear

        // Generate coupon payment dates
        var currentDate = issueDate
        while currentDate < maturityDate {
            currentDate = calendar.date(
                byAdding: .month,
                value: monthsBetween,
                to: currentDate
            ) ?? currentDate

            if currentDate <= maturityDate && currentDate > asOf {
                cashFlows.append(BondCashFlow(
                    date: currentDate,
                    amount: couponPayment,
                    type: .coupon
                ))
            }
        }

        // Add principal repayment at maturity (if in the future)
        if maturityDate > asOf {
            cashFlows.append(BondCashFlow(
                date: maturityDate,
                amount: faceValue,
                type: .principal
            ))
        }

        return cashFlows.sorted { $0.date < $1.date }
    }

    /// Calculate bond price given a yield to maturity
    ///
    /// Discounts all future cash flows at the given yield to determine present value.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity (as decimal, e.g., 0.06 for 6%)
    ///   - asOf: Valuation date
    /// - Returns: Present value of the bond
    ///
    /// ## Formula
    ///
    /// Price = Σ(CF_t / (1 + y/m)^t)
    ///
    /// Where CF_t is the cash flow at time t
    public func price(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)
        let periodicYield = yield / m

        var presentValue: T = 0

        for cashFlow in cashFlows {
            // Calculate periods from asOf to cash flow date
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            // Build seconds per year from integer literals
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay  // 365.25
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear
            let periods = years * m

            let discountFactor = T.pow(T(1) + periodicYield, periods)
            presentValue += cashFlow.amount / discountFactor
        }

        return presentValue
    }

    /// Calculate yield to maturity given a bond price
    ///
    /// Uses Newton-Raphson method to find the yield that makes the
    /// present value of cash flows equal to the given price.
    ///
    /// - Parameters:
    ///   - price: Market price of the bond
    ///   - asOf: Valuation date
    /// - Returns: Yield to maturity (annualized)
    /// - Throws: `OptimizationError` if convergence fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ytm = try bond.yieldToMaturity(price: 950.0)
    /// print("YTM: \(ytm * 100)%")
    /// ```
    public func yieldToMaturity(price: T, asOf: Date = Date()) throws -> T {
        // Use Newton-Raphson to solve for yield
        // f(y) = Price(y) - TargetPrice = 0

        var yield = couponRate  // Initial guess
        // Build tolerance from integer literals: 0.0001 = 1/10000
        let tolerance = T(1) / T(10000)
        // Build minimum yield: 0.001 = 1/1000
        let minYield = T(1) / T(1000)
        let maxIterations = 100

        for _ in 0..<maxIterations {
            let currentPrice = self.price(yield: yield, asOf: asOf)
            let error = currentPrice - price

            // Check convergence using absolute value
            let absError = error < 0 ? -error : error
            if absError < tolerance {
                return yield
            }

            // Calculate derivative (duration-based approximation)
            let modDuration = modifiedDuration(yield: yield, asOf: asOf)
            let derivative = -currentPrice * modDuration

            // Newton-Raphson update
            yield = yield - error / derivative

            // Ensure yield stays positive
            if yield < 0 {
                yield = minYield
            }
        }

        throw OptimizationError.failedToConverge(
            message: "YTM calculation did not converge after \(maxIterations) iterations"
        )
    }

    /// Calculate current yield
    ///
    /// Current yield is the annual coupon payment divided by the current price.
    /// This is a simple yield measure that ignores capital gains/losses.
    ///
    /// - Parameter price: Current market price
    /// - Returns: Current yield (as decimal)
    ///
    /// ## Formula
    ///
    /// Current Yield = Annual Coupon / Price
    ///
    /// ## Example
    ///
    /// ```swift
    /// let currentYield = bond.currentYield(price: 950.0)
    /// // If coupon is 5%, current yield = 50 / 950 ≈ 5.26%
    /// ```
    public func currentYield(price: T) -> T {
        let annualCoupon = faceValue * couponRate
        return annualCoupon / price
    }

    /// Calculate Macaulay duration
    ///
    /// Macaulay duration is the weighted average time to receive cash flows,
    /// where weights are the present values of each cash flow.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Macaulay duration in years
    ///
    /// ## Formula
    ///
    /// Duration = Σ(t × PV(CF_t)) / Price
    ///
    /// ## Interpretation
    ///
    /// - Duration < Maturity (due to coupon payments)
    /// - Higher coupon → Lower duration
    /// - Longer maturity → Higher duration
    public func macaulayDuration(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)
        let periodicYield = yield / m
        let bondPrice = price(yield: yield, asOf: asOf)

        var weightedTime: T = 0

        for cashFlow in cashFlows {
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            // Build seconds per year from integer literals
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay  // 365.25
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear
            let periods = years * m

            let discountFactor = T.pow(T(1) + periodicYield, periods)
            let pv = cashFlow.amount / discountFactor

            weightedTime += years * pv
        }

        return weightedTime / bondPrice
    }

    /// Calculate modified duration
    ///
    /// Modified duration measures the percentage change in bond price
    /// for a 1% change in yield.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Modified duration
    ///
    /// ## Formula
    ///
    /// Modified Duration = Macaulay Duration / (1 + y/m)
    ///
    /// ## Usage
    ///
    /// Approximate price change: ΔPrice/Price ≈ -ModDuration × ΔYield
    ///
    /// ## Example
    ///
    /// ```swift
    /// let modDur = bond.modifiedDuration(yield: 0.06)
    /// // If yield increases by 0.01 (1%), price decreases by ~modDur%
    /// ```
    public func modifiedDuration(yield: T, asOf: Date = Date()) -> T {
        let macDuration = macaulayDuration(yield: yield, asOf: asOf)
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)
        return macDuration / (T(1) + yield / m)
    }

    /// Calculate convexity
    ///
    /// Convexity measures the curvature of the price-yield relationship.
    /// It improves the duration approximation for larger yield changes.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Convexity
    ///
    /// ## Formula
    ///
    /// Convexity = Σ(t(t+1) × PV(CF_t)) / (Price × (1 + y/m)²)
    ///
    /// ## Usage
    ///
    /// Improved price approximation:
    /// ΔPrice/Price ≈ -ModDuration × ΔYield + 0.5 × Convexity × (ΔYield)²
    ///
    /// ## Interpretation
    ///
    /// - Convexity is always positive for option-free bonds
    /// - Higher convexity → Better price performance
    /// - Investors prefer positive convexity
    public func convexity(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)
        let periodicYield = yield / m
        let bondPrice = price(yield: yield, asOf: asOf)

        var convexitySum: T = 0

        for cashFlow in cashFlows {
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            // Build seconds per year from integer literals
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay  // 365.25
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear
            let periods = years * m

            let discountFactor = T.pow(T(1) + periodicYield, periods)
            let pv = cashFlow.amount / discountFactor

            // t(t+1) term for convexity
            let timeFactor = periods * (periods + 1)
            convexitySum += timeFactor * pv
        }

        let denominator = bondPrice * T.pow(T(1) + periodicYield, 2)
        return convexitySum / (denominator * m * m)
    }
}

// MARK: - Zero Coupon Bond

/// Zero coupon bond with no periodic interest payments
///
/// A zero coupon bond (also called a pure discount bond) does not pay any coupons.
/// Instead, it is sold at a deep discount to face value and pays the full face value
/// at maturity. The return comes entirely from capital appreciation.
///
/// ## Overview
///
/// Zero coupon bonds are the simplest form of fixed-income security:
/// - **No coupon payments**: All return comes from price appreciation
/// - **Single cash flow**: Only the face value payment at maturity
/// - **Duration equals maturity**: Most interest rate sensitive bond type
/// - **Deep discount pricing**: Traded well below par value
///
/// ## Pricing Formula
///
/// ```
/// Price = Face Value / (1 + y)^t
/// ```
///
/// Where:
/// - y = Yield to maturity (annual)
/// - t = Years to maturity
///
/// ## Characteristics
///
/// - **Maximum Duration**: Macaulay duration equals time to maturity
/// - **High Volatility**: Most sensitive to interest rate changes
/// - **No Reinvestment Risk**: No coupons to reinvest
/// - **Tax Implications**: Imputed interest may be taxable annually
///
/// ## Usage Example
///
/// ```swift
/// let zeroCoupon = ZeroCouponBond(
///     faceValue: 1000.0,
///     maturityDate: Date().addingTimeInterval(10 * 365 * 24 * 3600),
///     issueDate: Date()
/// )
///
/// // Price at 5% yield: 1000 / (1.05)^10 ≈ $613.91
/// let price = zeroCoupon.price(yield: 0.05)
///
/// // Calculate YTM for a bond trading at $600
/// let ytm = try zeroCoupon.yieldToMaturity(price: 600.0)
/// ```
///
/// - SeeAlso:
///   - ``Bond`` for traditional coupon-paying bonds
///   - ``AmortizingBond`` for bonds with principal amortization
public struct ZeroCouponBond<T: Real>: BondLike where T: Sendable {

    /// Face value (par value) of the bond
    public let faceValue: T

    /// Date when the bond matures and principal is repaid
    public let maturityDate: Date

    /// Date when the bond was issued
    public let issueDate: Date

    /// Initialize a zero coupon bond
    ///
    /// - Parameters:
    ///   - faceValue: Par value of the bond (amount paid at maturity)
    ///   - maturityDate: Date when bond matures
    ///   - issueDate: Date when bond was issued
    public init(
        faceValue: T,
        maturityDate: Date,
        issueDate: Date
    ) {
        self.faceValue = faceValue
        self.maturityDate = maturityDate
        self.issueDate = issueDate
    }

    /// Generate cash flow schedule (single principal payment at maturity)
    ///
    /// - Parameter asOf: Valuation date
    /// - Returns: Array with single cash flow at maturity
    public func cashFlowSchedule(asOf: Date = Date()) -> [BondCashFlow<T>] {
        // Zero coupon bonds have only one cash flow: principal at maturity
        if maturityDate > asOf {
            return [BondCashFlow(date: maturityDate, amount: faceValue, type: .principal)]
        } else {
            return []
        }
    }

    /// Calculate bond price given a yield
    ///
    /// Uses the simple present value formula for a single future payment.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity (annual, as decimal)
    ///   - asOf: Valuation date
    /// - Returns: Present value of the bond
    ///
    /// ## Formula
    ///
    /// Price = Face Value / (1 + yield)^years
    public func price(yield: T, asOf: Date = Date()) -> T {
        let timeInterval = maturityDate.timeIntervalSince(asOf)
        let wholeDays = T(365)
        let quarterDay = T(1) / T(4)
        let daysPerYear = wholeDays + quarterDay
        let hoursPerDay = T(24)
        let secondsPerHour = T(3600)
        let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
        let years = T(Int(timeInterval)) / secondsPerYear

        let discountFactor = T.pow(T(1) + yield, years)
        return faceValue / discountFactor
    }

    /// Calculate yield to maturity given a price
    ///
    /// For zero coupon bonds, YTM can be calculated directly:
    /// YTM = (Face Value / Price)^(1/years) - 1
    ///
    /// - Parameters:
    ///   - price: Market price of the bond
    ///   - asOf: Valuation date
    /// - Returns: Yield to maturity (annualized)
    public func yieldToMaturity(price: T, asOf: Date = Date()) throws -> T {
        let timeInterval = maturityDate.timeIntervalSince(asOf)
        let wholeDays = T(365)
        let quarterDay = T(1) / T(4)
        let daysPerYear = wholeDays + quarterDay
        let hoursPerDay = T(24)
        let secondsPerHour = T(3600)
        let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
        let years = T(Int(timeInterval)) / secondsPerYear

        // YTM = (Face / Price)^(1/years) - 1
        let ratio = faceValue / price
        let exponent = T(1) / years
        let ytm = T.pow(ratio, exponent) - T(1)

        return ytm
    }

    /// Calculate Macaulay duration (equals time to maturity for zero coupon bonds)
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Duration in years (equals years to maturity)
    public func macaulayDuration(yield: T, asOf: Date = Date()) -> T {
        // For zero coupon bonds, duration = time to maturity
        let timeInterval = maturityDate.timeIntervalSince(asOf)
        let wholeDays = T(365)
        let quarterDay = T(1) / T(4)
        let daysPerYear = wholeDays + quarterDay
        let hoursPerDay = T(24)
        let secondsPerHour = T(3600)
        let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
        let years = T(Int(timeInterval)) / secondsPerYear

        return years
    }

    /// Calculate modified duration
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Modified duration
    public func modifiedDuration(yield: T, asOf: Date = Date()) -> T {
        let macDuration = macaulayDuration(yield: yield, asOf: asOf)
        return macDuration / (T(1) + yield)
    }

    /// Calculate convexity
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Convexity
    public func convexity(yield: T, asOf: Date = Date()) -> T {
        let timeInterval = maturityDate.timeIntervalSince(asOf)
        let wholeDays = T(365)
        let quarterDay = T(1) / T(4)
        let daysPerYear = wholeDays + quarterDay
        let hoursPerDay = T(24)
        let secondsPerHour = T(3600)
        let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
        let years = T(Int(timeInterval)) / secondsPerYear

        // For zero coupon: Convexity = t(t+1) / (1+y)^2
        let numerator = years * (years + T(1))
        let denominator = T.pow(T(1) + yield, T(2))
        return numerator / denominator
    }
}

// MARK: - Amortization Payment

/// Represents a scheduled principal repayment on an amortizing bond
public struct AmortizationPayment<T: Real>: Sendable where T: Sendable {
    /// Date of the principal payment
    public let date: Date

    /// Amount of principal to be repaid
    public let principalAmount: T

    public init(date: Date, principalAmount: T) {
        self.date = date
        self.principalAmount = principalAmount
    }
}

// MARK: - Amortizing Bond

/// Amortizing bond with periodic principal repayments
///
/// An amortizing bond (also called a sinking fund bond or principal amortization bond)
/// repays principal gradually over the life of the bond rather than all at maturity.
/// This reduces credit risk and typically results in lower duration than bullet bonds.
///
/// ## Overview
///
/// Amortizing bonds combine features of bonds and loans:
/// - **Periodic coupons**: Interest payments on remaining principal balance
/// - **Principal amortization**: Gradual repayment of face value
/// - **Reduced duration**: Lower than comparable bullet bonds
/// - **Lower credit risk**: Outstanding principal declines over time
///
/// ## Cash Flows
///
/// Each payment date typically includes:
/// 1. **Coupon payment**: Interest on current outstanding principal
/// 2. **Principal payment**: Scheduled amortization amount
///
/// The coupon amount decreases over time as principal is repaid.
///
/// ## Common Amortization Patterns
///
/// - **Level payments**: Equal total payments (like a mortgage)
/// - **Equal principal**: Same principal amount each period
/// - **Bullet with amortization**: Partial amortization with balloon payment
/// - **Custom schedule**: Any specified amortization pattern
///
/// ## Usage Example
///
/// ```swift
/// // 5-year bond with equal annual principal payments
/// var schedule: [AmortizationPayment] = []
/// for year in 1...5 {
///     let date = Date().addingTimeInterval(Double(year) * 365 * 24 * 3600)
///     schedule.append(AmortizationPayment(date: date, principalAmount: 200.0))
/// }
///
/// let bond = AmortizingBond(
///     faceValue: 1000.0,
///     couponRate: 0.06,
///     maturityDate: schedule.last!.date,
///     paymentFrequency: .annual,
///     issueDate: Date(),
///     amortizationSchedule: schedule
/// )
///
/// // Calculate price and duration
/// let price = bond.price(yield: 0.06)
/// let duration = bond.macaulayDuration(yield: 0.06)
/// ```
///
/// ## Important Notes
///
/// - Coupon payments are calculated on the **remaining principal balance**
/// - Duration is typically lower than equivalent bullet bond
/// - Total principal payments should sum to face value
/// - Amortization schedule must be in chronological order
///
/// - SeeAlso:
///   - ``Bond`` for traditional bullet bonds
///   - ``ZeroCouponBond`` for bonds without coupons
public struct AmortizingBond<T: Real>: BondLike where T: Sendable {

    /// Face value (par value) of the bond
    public let faceValue: T

    /// Annual coupon rate (as decimal, e.g., 0.05 for 5%)
    public let couponRate: T

    /// Date when the bond matures and final payment is made
    public let maturityDate: Date

    /// Frequency of coupon payments
    public let paymentFrequency: PaymentFrequency

    /// Date when the bond was issued
    public let issueDate: Date

    /// Schedule of principal amortization payments
    public let amortizationSchedule: [AmortizationPayment<T>]

    /// Initialize an amortizing bond
    ///
    /// - Parameters:
    ///   - faceValue: Par value of the bond
    ///   - couponRate: Annual coupon rate (e.g., 0.05 for 5%)
    ///   - maturityDate: Date when bond matures
    ///   - paymentFrequency: How often coupons are paid
    ///   - issueDate: Date when bond was issued
    ///   - amortizationSchedule: Schedule of principal repayments
    public init(
        faceValue: T,
        couponRate: T,
        maturityDate: Date,
        paymentFrequency: PaymentFrequency,
        issueDate: Date,
        amortizationSchedule: [AmortizationPayment<T>]
    ) {
        self.faceValue = faceValue
        self.couponRate = couponRate
        self.maturityDate = maturityDate
        self.paymentFrequency = paymentFrequency
        self.issueDate = issueDate
        self.amortizationSchedule = amortizationSchedule
    }

    /// Generate cash flow schedule with coupons and principal payments
    ///
    /// Creates both coupon payments (on declining balance) and principal payments.
    ///
    /// - Parameter asOf: Valuation date
    /// - Returns: Array of cash flows sorted by date
    public func cashFlowSchedule(asOf: Date = Date()) -> [BondCashFlow<T>] {
        var cashFlows: [BondCashFlow<T>] = []

        let calendar = Calendar.current
        let periodsPerYear = paymentFrequency.periodsPerYear
        let m = T(periodsPerYear)
        let monthsBetween = 12 / periodsPerYear

        // Track remaining principal for coupon calculations
        var remainingPrincipal = faceValue

        // Generate coupon payment dates
        var currentDate = issueDate
        while currentDate < maturityDate {
            currentDate = calendar.date(
                byAdding: .month,
                value: monthsBetween,
                to: currentDate
            ) ?? currentDate

            if currentDate <= maturityDate && currentDate > asOf {
                // Calculate coupon on current remaining principal
                let couponPayment = remainingPrincipal * couponRate / m
                cashFlows.append(BondCashFlow(
                    date: currentDate,
                    amount: couponPayment,
                    type: .coupon
                ))
            }

            // Check if any principal payments occur before next coupon date
            for amortPayment in amortizationSchedule {
                if amortPayment.date <= currentDate && amortPayment.date > asOf {
                    // Add principal payment
                    if !cashFlows.contains(where: { $0.date == amortPayment.date && $0.type == .principal }) {
                        cashFlows.append(BondCashFlow(
                            date: amortPayment.date,
                            amount: amortPayment.principalAmount,
                            type: .principal
                        ))
                        remainingPrincipal -= amortPayment.principalAmount
                    }
                }
            }
        }

        // Add any remaining principal payments
        for amortPayment in amortizationSchedule {
            if amortPayment.date > asOf {
                if !cashFlows.contains(where: { $0.date == amortPayment.date && $0.type == .principal }) {
                    cashFlows.append(BondCashFlow(
                        date: amortPayment.date,
                        amount: amortPayment.principalAmount,
                        type: .principal
                    ))
                }
            }
        }

        return cashFlows.sorted { $0.date < $1.date }
    }

    /// Calculate bond price given a yield
    ///
    /// Discounts all future cash flows (coupons and principal payments) at the given yield.
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity (as decimal)
    ///   - asOf: Valuation date
    /// - Returns: Present value of the bond
    public func price(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)

        var presentValue: T = 0

        for cashFlow in cashFlows {
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear

            let discountFactor = T.pow(T(1) + yield, years)
            presentValue += cashFlow.amount / discountFactor
        }

        return presentValue
    }

    /// Calculate yield to maturity given a price
    ///
    /// Uses Newton-Raphson method to find the yield that matches the given price.
    ///
    /// - Parameters:
    ///   - price: Market price of the bond
    ///   - asOf: Valuation date
    /// - Returns: Yield to maturity (annualized)
    /// - Throws: `OptimizationError` if convergence fails
    public func yieldToMaturity(price: T, asOf: Date = Date()) throws -> T {
        var yield = couponRate  // Initial guess
        let tolerance = T(1) / T(10000)
        let minYield = T(1) / T(1000)
        let maxIterations = 100

        for _ in 0..<maxIterations {
            let currentPrice = self.price(yield: yield, asOf: asOf)
            let error = currentPrice - price

            let absError = error < 0 ? -error : error
            if absError < tolerance {
                return yield
            }

            // Calculate derivative (duration-based approximation)
            let modDuration = modifiedDuration(yield: yield, asOf: asOf)
            let derivative = -currentPrice * modDuration

            // Newton-Raphson update
            yield = yield - error / derivative

            // Ensure yield stays positive
            if yield < 0 {
                yield = minYield
            }
        }

        throw OptimizationError.failedToConverge(
            message: "YTM calculation did not converge after \(maxIterations) iterations"
        )
    }

    /// Calculate Macaulay duration
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Macaulay duration in years
    public func macaulayDuration(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)
        let bondPrice = price(yield: yield, asOf: asOf)

        var weightedTime: T = 0

        for cashFlow in cashFlows {
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear

            let discountFactor = T.pow(T(1) + yield, years)
            let pv = cashFlow.amount / discountFactor

            weightedTime += years * pv
        }

        return weightedTime / bondPrice
    }

    /// Calculate modified duration
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Modified duration
    public func modifiedDuration(yield: T, asOf: Date = Date()) -> T {
        let macDuration = macaulayDuration(yield: yield, asOf: asOf)
        return macDuration / (T(1) + yield)
    }

    /// Calculate convexity
    ///
    /// - Parameters:
    ///   - yield: Yield to maturity
    ///   - asOf: Valuation date
    /// - Returns: Convexity
    public func convexity(yield: T, asOf: Date = Date()) -> T {
        let cashFlows = cashFlowSchedule(asOf: asOf)
        let bondPrice = price(yield: yield, asOf: asOf)

        var convexitySum: T = 0

        for cashFlow in cashFlows {
            let timeInterval = cashFlow.date.timeIntervalSince(asOf)
            let wholeDays = T(365)
            let quarterDay = T(1) / T(4)
            let daysPerYear = wholeDays + quarterDay
            let hoursPerDay = T(24)
            let secondsPerHour = T(3600)
            let secondsPerYear = daysPerYear * hoursPerDay * secondsPerHour
            let years = T(Int(timeInterval)) / secondsPerYear

            let discountFactor = T.pow(T(1) + yield, years)
            let pv = cashFlow.amount / discountFactor

            let timeFactor = years * (years + T(1))
            convexitySum += timeFactor * pv
        }

        let denominator = bondPrice * T.pow(T(1) + yield, T(2))
        return convexitySum / denominator
    }
}

// MARK: - Optimization Error

/// Errors that can occur during optimization (e.g., YTM calculation)
public enum OptimizationError: Error {
    case failedToConverge(message: String)
    case invalidInput(message: String)
    case nonFiniteValue(message: String)
    case singularMatrix(message: String)
    case maxIterationsReached
    case unsupportedConstraints(String)
    case nonlinearModel(message: String)  // NEW: For MILP solvers requiring linear models
}
