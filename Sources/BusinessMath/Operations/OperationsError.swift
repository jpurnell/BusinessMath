import Foundation

/// Errors raised by Operations module models when inputs are invalid.
///
/// These errors indicate problems with the data or parameters supplied to
/// inventory management calculations. Each case includes enough context
/// to construct a user-facing diagnostic message.
public enum OperationsError: Error, Sendable {
    /// The demand history or data set is too small for the requested calculation.
    /// - Parameters:
    ///   - required: The minimum number of observations needed.
    ///   - got: The number of observations actually provided.
    case insufficientData(required: Int, got: Int)
    /// A named parameter has an invalid value.
    case invalidParameter(String)
    /// The service level is outside the open interval (0, 1).
    case invalidServiceLevel
    /// Annual or per-period demand is zero or negative.
    case zeroDemand
    /// A cost parameter (ordering, holding, underage, or overage) is zero or negative.
    case negativeCost
}
