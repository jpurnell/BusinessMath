//
//  Payoff.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-15.
//

import Foundation

// MARK: - Payoff Protocol

/// A protocol for option payoffs that observe price paths and compute terminal values.
///
/// Payoffs can be path-dependent (e.g., Asian, barrier, lookback) or path-independent
/// (e.g., European, digital). Path-dependent payoffs accumulate state through ``observe(value:time:)``
/// calls during simulation, while path-independent payoffs ignore observations.
///
/// ## Usage
///
/// ```swift
/// var payoff = AsianPayoff(strike: 100.0, optionType: .call)
/// for (price, time) in path {
///     payoff.observe(value: price, time: time)
/// }
/// let result = payoff.terminalValue(finalSpot: path.last!.price)
/// payoff.reset()  // Ready for next path
/// ```
public protocol Payoff: Sendable {
    /// Observe the underlying value at a time step.
    ///
    /// Path-dependent payoffs accumulate state from each observation.
    /// Path-independent payoffs may ignore this call.
    ///
    /// - Parameters:
    ///   - value: The underlying asset price at this time step.
    ///   - time: The time of the observation in years.
    mutating func observe(value: Double, time: Double)

    /// Compute the terminal payoff value.
    ///
    /// - Parameter finalSpot: The underlying asset price at expiry.
    /// - Returns: The payoff amount, which is always non-negative.
    func terminalValue(finalSpot: Double) -> Double

    /// Reset accumulated state for a new simulation path.
    ///
    /// Call this before beginning observations on a new Monte Carlo path.
    mutating func reset()
}

// MARK: - EuropeanPayoff

/// Standard European option payoff (non-path-dependent).
///
/// A European payoff depends only on the final spot price at expiry:
/// - **Call:** `max(S - K, 0) * notional`
/// - **Put:** `max(K - S, 0) * notional`
///
/// ## Example
///
/// ```swift
/// let call = EuropeanPayoff(strike: 100.0, optionType: .call, notional: 1000.0)
/// let value = call.terminalValue(finalSpot: 110.0)  // 10,000.0
/// ```
public struct EuropeanPayoff: Payoff, Sendable {
    /// The strike price of the option.
    public let strike: Double

    /// Whether this is a call or put option.
    public let optionType: OptionType

    /// The notional amount (number of units or contract multiplier).
    public let notional: Double

    /// Creates a European payoff.
    ///
    /// - Parameters:
    ///   - strike: The strike price.
    ///   - optionType: Call or put.
    ///   - notional: The notional multiplier. Defaults to `1.0`.
    public init(strike: Double, optionType: OptionType, notional: Double = 1.0) {
        self.strike = strike
        self.optionType = optionType
        self.notional = notional
    }

    /// No-op for European payoffs, which are path-independent.
    public mutating func observe(value: Double, time: Double) { }

    /// Computes the European payoff at expiry.
    ///
    /// - Parameter finalSpot: The underlying price at expiry.
    /// - Returns: `max(S - K, 0) * notional` for calls, `max(K - S, 0) * notional` for puts.
    public func terminalValue(finalSpot: Double) -> Double {
        switch optionType {
        case .call:
            return max(finalSpot - strike, 0.0) * notional
        case .put:
            return max(strike - finalSpot, 0.0) * notional
        }
    }

    /// No-op for European payoffs, which have no accumulated state.
    public mutating func reset() { }
}

// MARK: - AsianPayoff

/// Asian option payoff based on the arithmetic average of observed prices.
///
/// The payoff is computed using the arithmetic mean of all observed prices:
/// - **Call:** `max(average - K, 0) * notional`
/// - **Put:** `max(K - average, 0) * notional`
///
/// ## Example
///
/// ```swift
/// var payoff = AsianPayoff(strike: 105.0, optionType: .call)
/// payoff.observe(value: 100.0, time: 0.25)
/// payoff.observe(value: 110.0, time: 0.50)
/// payoff.observe(value: 120.0, time: 0.75)
/// let result = payoff.terminalValue(finalSpot: 120.0)  // max(110 - 105, 0) = 5.0
/// ```
public struct AsianPayoff: Payoff, Sendable {
    /// The strike price of the option.
    public let strike: Double

    /// Whether this is a call or put option.
    public let optionType: OptionType

    /// The notional amount.
    public let notional: Double

    /// Running sum of observed prices.
    private var sum: Double = 0.0

    /// Count of observations.
    private var count: Int = 0

    /// Creates an Asian payoff.
    ///
    /// - Parameters:
    ///   - strike: The strike price.
    ///   - optionType: Call or put.
    ///   - notional: The notional multiplier. Defaults to `1.0`.
    public init(strike: Double, optionType: OptionType, notional: Double = 1.0) {
        self.strike = strike
        self.optionType = optionType
        self.notional = notional
    }

    /// Records a price observation for the running average.
    ///
    /// - Parameters:
    ///   - value: The underlying asset price at this time step.
    ///   - time: The time of the observation in years.
    public mutating func observe(value: Double, time: Double) {
        sum += value
        count += 1
    }

    /// Computes the Asian payoff using the arithmetic average of observed prices.
    ///
    /// If no observations were recorded, returns `0.0`.
    ///
    /// - Parameter finalSpot: The underlying price at expiry (unused; average is used instead).
    /// - Returns: The Asian option payoff.
    public func terminalValue(finalSpot: Double) -> Double {
        guard count > 0 else { return 0.0 }
        let average = sum / Double(count)
        switch optionType {
        case .call:
            return max(average - strike, 0.0) * notional
        case .put:
            return max(strike - average, 0.0) * notional
        }
    }

    /// Resets the running sum and count for a new simulation path.
    public mutating func reset() {
        sum = 0.0
        count = 0
    }
}

// MARK: - BarrierType

/// The type of barrier condition for a barrier option.
public enum BarrierType: Sendable {
    /// The option is knocked out if the price rises above the barrier.
    case upAndOut

    /// The option is knocked in if the price rises above the barrier.
    case upAndIn

    /// The option is knocked out if the price falls below the barrier.
    case downAndOut

    /// The option is knocked in if the price falls below the barrier.
    case downAndIn
}

// MARK: - BarrierPayoff

/// Barrier option payoff that activates or deactivates at a barrier level.
///
/// - **Knock-out** barriers (up-and-out, down-and-out) cancel the option if the barrier is breached.
/// - **Knock-in** barriers (up-and-in, down-and-in) activate the option only if the barrier is breached.
///
/// ## Example
///
/// ```swift
/// var payoff = BarrierPayoff(
///     strike: 100.0, barrier: 80.0,
///     barrierType: .downAndOut, optionType: .call
/// )
/// payoff.observe(value: 95.0, time: 0.25)
/// payoff.observe(value: 85.0, time: 0.50)  // barrier not breached (85 > 80)
/// let result = payoff.terminalValue(finalSpot: 110.0)  // max(110 - 100, 0) = 10.0
/// ```
public struct BarrierPayoff: Payoff, Sendable {
    /// The strike price of the option.
    public let strike: Double

    /// The barrier level.
    public let barrier: Double

    /// The type of barrier condition.
    public let barrierType: BarrierType

    /// Whether this is a call or put option.
    public let optionType: OptionType

    /// The notional amount.
    public let notional: Double

    /// Whether the barrier has been breached during the path.
    private var barrierBreached: Bool = false

    /// Creates a barrier payoff.
    ///
    /// - Parameters:
    ///   - strike: The strike price.
    ///   - barrier: The barrier level.
    ///   - barrierType: The type of barrier (knock-in or knock-out, up or down).
    ///   - optionType: Call or put.
    ///   - notional: The notional multiplier. Defaults to `1.0`.
    public init(
        strike: Double,
        barrier: Double,
        barrierType: BarrierType,
        optionType: OptionType,
        notional: Double = 1.0
    ) {
        self.strike = strike
        self.barrier = barrier
        self.barrierType = barrierType
        self.optionType = optionType
        self.notional = notional
    }

    /// Checks whether the observed price breaches the barrier.
    ///
    /// - Parameters:
    ///   - value: The underlying asset price at this time step.
    ///   - time: The time of the observation in years.
    public mutating func observe(value: Double, time: Double) {
        guard !barrierBreached else { return }
        switch barrierType {
        case .upAndOut, .upAndIn:
            if value >= barrier {
                barrierBreached = true
            }
        case .downAndOut, .downAndIn:
            if value <= barrier {
                barrierBreached = true
            }
        }
    }

    /// Computes the barrier option payoff.
    ///
    /// - For knock-out types: returns the vanilla payoff if the barrier was **not** breached, otherwise `0`.
    /// - For knock-in types: returns the vanilla payoff if the barrier **was** breached, otherwise `0`.
    ///
    /// - Parameter finalSpot: The underlying price at expiry.
    /// - Returns: The barrier option payoff.
    public func terminalValue(finalSpot: Double) -> Double {
        let vanillaPayoff: Double
        switch optionType {
        case .call:
            vanillaPayoff = max(finalSpot - strike, 0.0)
        case .put:
            vanillaPayoff = max(strike - finalSpot, 0.0)
        }

        switch barrierType {
        case .upAndOut, .downAndOut:
            return barrierBreached ? 0.0 : vanillaPayoff * notional
        case .upAndIn, .downAndIn:
            return barrierBreached ? vanillaPayoff * notional : 0.0
        }
    }

    /// Resets the barrier breach state for a new simulation path.
    public mutating func reset() {
        barrierBreached = false
    }
}

// MARK: - LookbackPayoff

/// Lookback option payoff based on the extremum of the observed price path.
///
/// Uses a floating-strike formulation:
/// - **Call:** `(finalSpot - pathMinimum) * notional`
/// - **Put:** `(pathMaximum - finalSpot) * notional`
///
/// The payoff is always non-negative since the extremum guarantees the best possible entry.
///
/// ## Example
///
/// ```swift
/// var payoff = LookbackPayoff(optionType: .call)
/// payoff.observe(value: 100.0, time: 0.25)
/// payoff.observe(value: 90.0, time: 0.50)
/// payoff.observe(value: 105.0, time: 0.75)
/// let result = payoff.terminalValue(finalSpot: 110.0)  // 110 - 90 = 20.0
/// ```
public struct LookbackPayoff: Payoff, Sendable {
    /// Whether this is a call or put option.
    public let optionType: OptionType

    /// The notional amount.
    public let notional: Double

    /// Running maximum of observed prices.
    private var runningMax: Double = -.infinity

    /// Running minimum of observed prices.
    private var runningMin: Double = .infinity

    /// Creates a lookback payoff.
    ///
    /// - Parameters:
    ///   - optionType: Call or put.
    ///   - notional: The notional multiplier. Defaults to `1.0`.
    public init(optionType: OptionType, notional: Double = 1.0) {
        self.optionType = optionType
        self.notional = notional
    }

    /// Tracks the running maximum and minimum of the price path.
    ///
    /// - Parameters:
    ///   - value: The underlying asset price at this time step.
    ///   - time: The time of the observation in years.
    public mutating func observe(value: Double, time: Double) {
        if value > runningMax { runningMax = value }
        if value < runningMin { runningMin = value }
    }

    /// Computes the lookback payoff using the path extremum.
    ///
    /// Returns `0.0` if no observations were recorded.
    ///
    /// - Parameter finalSpot: The underlying price at expiry.
    /// - Returns: The floating-strike lookback payoff.
    public func terminalValue(finalSpot: Double) -> Double {
        guard runningMax > -.infinity, runningMin < .infinity else { return 0.0 }
        switch optionType {
        case .call:
            return max(finalSpot - runningMin, 0.0) * notional
        case .put:
            return max(runningMax - finalSpot, 0.0) * notional
        }
    }

    /// Resets the running max and min for a new simulation path.
    public mutating func reset() {
        runningMax = -.infinity
        runningMin = .infinity
    }
}

// MARK: - DigitalPayoff

/// Digital (binary) option payoff that pays a fixed amount if in-the-money at expiry.
///
/// - **Call:** pays ``payout`` if `finalSpot > strike`, otherwise `0`.
/// - **Put:** pays ``payout`` if `finalSpot < strike`, otherwise `0`.
///
/// ## Example
///
/// ```swift
/// let digital = DigitalPayoff(strike: 100.0, optionType: .call, payout: 1000.0)
/// let value = digital.terminalValue(finalSpot: 101.0)  // 1000.0
/// ```
public struct DigitalPayoff: Payoff, Sendable {
    /// The strike price of the option.
    public let strike: Double

    /// Whether this is a call or put option.
    public let optionType: OptionType

    /// The fixed payout amount if the option finishes in-the-money.
    public let payout: Double

    /// Creates a digital payoff.
    ///
    /// - Parameters:
    ///   - strike: The strike price.
    ///   - optionType: Call or put.
    ///   - payout: The fixed payout amount. Defaults to `1.0`.
    public init(strike: Double, optionType: OptionType, payout: Double = 1.0) {
        self.strike = strike
        self.optionType = optionType
        self.payout = payout
    }

    /// No-op for digital payoffs, which are path-independent.
    public mutating func observe(value: Double, time: Double) { }

    /// Computes the digital payoff at expiry.
    ///
    /// - Parameter finalSpot: The underlying price at expiry.
    /// - Returns: ``payout`` if in-the-money, `0.0` otherwise.
    public func terminalValue(finalSpot: Double) -> Double {
        switch optionType {
        case .call:
            return finalSpot > strike ? payout : 0.0
        case .put:
            return finalSpot < strike ? payout : 0.0
        }
    }

    /// No-op for digital payoffs, which have no accumulated state.
    public mutating func reset() { }
}
