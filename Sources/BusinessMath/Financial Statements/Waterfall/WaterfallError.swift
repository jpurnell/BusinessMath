import Foundation

/// A waterfall term that cannot describe a real distribution.
///
/// These are thrown rather than trapped. The values reaching a waterfall are
/// often not the programmer's — a rate read from a spreadsheet cell, a tier
/// priority parsed from a file — and a `preconditionFailure` on caller data
/// takes the process down with no way to intervene. A thrown error lets the
/// caller report the bad input and carry on.
public enum WaterfallError: Error, Equatable, Sendable {

    /// A tier priority that is not positive. Priorities order the tiers, and
    /// zero or negative has no ordering meaning.
    case nonPositivePriority(tierName: String, priority: Int)

    /// A negative capital return. Capital is returned, not collected.
    case negativeCapitalReturn(Double)

    /// A negative preferred return rate.
    case negativePreferredRate(Double)

    /// A preferred return over a non-positive number of years.
    case nonPositivePreferredYears(Int)

    /// A catch-up target outside `0...1`. It is a share of profits.
    case catchUpOutOfRange(Double)

    /// A pro-rata split with no participants to split between.
    case proRataHasNoParticipants

    /// A pro-rata split whose shares do not sum to 1.
    case proRataDoesNotSumToOne(actual: Double)
}

extension WaterfallError: CustomStringConvertible {

    /// A message naming the offending value, so a caller can report which input
    /// was rejected rather than only that something was.
    public var description: String {
        switch self {
        case .nonPositivePriority(let name, let priority):
            return "Tier \"\(name)\" has priority \(priority); priorities order the tiers "
                + "and must be positive"
        case .negativeCapitalReturn(let amount):
            return "Capital return cannot be negative: \(amount)"
        case .negativePreferredRate(let rate):
            return "Preferred return rate cannot be negative: \(rate)"
        case .nonPositivePreferredYears(let years):
            return "Preferred return must span a positive number of years: \(years)"
        case .catchUpOutOfRange(let percentage):
            return "Catch-up target must be a share between 0 and 1: \(percentage)"
        case .proRataHasNoParticipants:
            return "A pro-rata split needs at least one participant"
        case .proRataDoesNotSumToOne(let actual):
            return "Pro-rata shares must sum to 1.0, got \(actual)"
        }
    }
}
