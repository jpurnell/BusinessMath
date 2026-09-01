import Foundation

// MARK: - Tier Components

/// Return of original capital investment.
public struct CapitalReturn: Sendable, Equatable {

    /// The capital amount to return before profits.
    public let amount: Double

    /// Creates a capital return requirement.
    ///
    /// - Parameter amount: The capital to return.
    /// - Throws: ``WaterfallError/negativeCapitalReturn(_:)`` if negative.
    public init(_ amount: Double) throws {
        guard amount >= 0 else { throw WaterfallError.negativeCapitalReturn(amount) }
        self.amount = amount
    }
}

/// Preferred return (hurdle rate) over a period.
public struct PreferredReturn: Sendable, Equatable {

    /// The annual preferred return rate, e.g. `0.08` for 8%.
    public let rate: Double

    /// The number of years the preferred return accrues over.
    public let years: Int

    /// Creates a preferred return requirement.
    ///
    /// - Parameters:
    ///   - rate: The annual rate.
    ///   - years: The number of years.
    /// - Throws: ``WaterfallError/negativePreferredRate(_:)`` or
    ///   ``WaterfallError/nonPositivePreferredYears(_:)``.
    public init(_ rate: Double, years: Int) throws {
        guard rate >= 0 else { throw WaterfallError.negativePreferredRate(rate) }
        guard years > 0 else { throw WaterfallError.nonPositivePreferredYears(years) }
        self.rate = rate
        self.years = years
    }

    /// The total preferred return as a multiple of capital.
    ///
    /// Simple interest: `rate × years`. Not compounded — a compounding variant
    /// would be a different term, not a refinement of this one, and changing it
    /// silently would move every number in every waterfall built on it.
    public var totalReturn: Double {
        rate * Double(years)
    }
}

/// Catch-up provision to achieve a target profit split.
public struct CatchUp: Sendable, Equatable {

    /// The target share of profits for the catch-up recipient.
    public let targetPercentage: Double

    /// Creates a catch-up provision.
    ///
    /// - Parameter percentage: The target profit share, between 0 and 1.
    /// - Throws: ``WaterfallError/catchUpOutOfRange(_:)`` if outside `0...1`.
    public init(to percentage: Double) throws {
        guard percentage >= 0, percentage <= 1.0 else {
            throw WaterfallError.catchUpOutOfRange(percentage)
        }
        self.targetPercentage = percentage
    }
}

/// Residual distribution, capturing all remaining proceeds.
public struct Residual: Sendable, Equatable {

    /// Creates a residual component.
    public init() {}
}

/// One participant's share of a pro-rata split.
public struct ProRataShare: Sendable, Equatable {

    /// The participant's name, used as the distribution key.
    public let name: String

    /// The participant's share, between 0 and 1.
    public let percentage: Double

    /// Creates a participant share.
    ///
    /// - Parameters:
    ///   - name: The participant's name.
    ///   - percentage: Their share of the split.
    public init(name: String, percentage: Double) {
        self.name = name
        self.percentage = percentage
    }
}

/// Pro-rata distribution among multiple participants.
public struct ProRata: Sendable, Equatable {

    /// The participants and their shares.
    public let participants: [ProRataShare]

    /// Creates a pro-rata distribution.
    ///
    /// - Parameter participants: Name and share pairs, whose shares sum to 1.
    /// - Throws: ``WaterfallError/proRataHasNoParticipants`` or
    ///   ``WaterfallError/proRataDoesNotSumToOne(actual:)``.
    public init(_ participants: [(String, Double)]) throws {
        guard !participants.isEmpty else { throw WaterfallError.proRataHasNoParticipants }

        let total = participants.reduce(0.0) { $0 + $1.1 }
        guard abs(total - 1.0) < 0.001 else {
            throw WaterfallError.proRataDoesNotSumToOne(actual: total)
        }

        self.participants = participants.map { ProRataShare(name: $0.0, percentage: $0.1) }
    }
}

// MARK: - Tier Components

/// A component that can appear inside a ``Tier``.
public enum TierComponent: Sendable, Equatable {

    /// Return of capital.
    case capitalReturn(CapitalReturn)

    /// A preferred return hurdle.
    case preferredReturn(PreferredReturn)

    /// A catch-up provision.
    case catchUp(CatchUp)

    /// A residual sweep of everything remaining.
    case residual(Residual)

    /// A pro-rata split.
    case proRata(ProRata)
}

/// A type that can be used as a ``TierComponent`` inside a tier builder.
public protocol TierComponentConvertible {

    /// This value as a tier component.
    var tierComponent: TierComponent { get }
}

extension CapitalReturn: TierComponentConvertible {
    /// This capital return as a tier component.
    public var tierComponent: TierComponent { .capitalReturn(self) }
}

extension PreferredReturn: TierComponentConvertible {
    /// This preferred return as a tier component.
    public var tierComponent: TierComponent { .preferredReturn(self) }
}

extension CatchUp: TierComponentConvertible {
    /// This catch-up as a tier component.
    public var tierComponent: TierComponent { .catchUp(self) }
}

extension Residual: TierComponentConvertible {
    /// This residual as a tier component.
    public var tierComponent: TierComponent { .residual(self) }
}

extension ProRata: TierComponentConvertible {
    /// This pro-rata split as a tier component.
    public var tierComponent: TierComponent { .proRata(self) }
}
