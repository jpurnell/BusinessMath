//
//  MeasureTag.swift
//  BusinessMath
//
//  Marker protocol for statistical measure (P or Q).
//

/// Marker protocol for the probability measure under which a simulation runs.
///
/// By encoding the measure as a type parameter, the compiler prevents
/// the most dangerous class of quantitative errors: pricing under the
/// physical measure or computing VaR under the risk-neutral measure.
///
/// ## Usage
///
/// Downstream consumers declare which measure they require:
///
/// ```swift
/// func price<M: MeasureTag>(context: SimulationContext<M>) -> Double
///     where M == RiskNeutral
/// ```
///
/// Passing a `SimulationContext<Physical>` to this function produces
/// a compile-time error — not a silent numerical mistake.
public protocol MeasureTag: Sendable {
    /// Human-readable name for logging and metadata.
    static var name: String { get }

    /// Creates a measure tag instance.
    init()
}

/// Risk-neutral measure (Q): used for derivatives pricing.
///
/// Under Q, the drift of all traded assets equals the risk-free rate.
/// Parameters are calibrated to market prices (implied vol, swap rates).
public struct RiskNeutral: MeasureTag, Sendable {
    /// The measure name.
    public static let name = "risk-neutral"

    /// Creates a risk-neutral measure tag.
    public init() {}
}

/// Physical measure (P): used for risk management, VaR, CFaR.
///
/// Under P, asset dynamics reflect real-world expected returns and
/// historical volatility. Parameters are estimated from time series data.
public struct Physical: MeasureTag, Sendable {
    /// The measure name.
    public static let name = "physical"

    /// Creates a physical measure tag.
    public init() {}
}
