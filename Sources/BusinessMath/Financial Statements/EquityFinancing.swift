import Foundation

/// Represents a capitalization table showing ownership distribution in a company.
///
/// A cap table tracks who owns what percentage of a company across multiple
/// financing rounds, option pools, and dilution events.
///
/// ## Usage Example
///
/// ```swift
/// let founder = CapTable.Shareholder(
///     name: "Alice",
///     shares: 10_000_000,
///     investmentDate: Date(),
///     pricePerShare: 0.001
/// )
///
/// var capTable = CapTable(shareholders: [founder], optionPool: 0)
/// print(capTable.ownership()["Alice"]!)  // 1.0 (100%)
///
/// // Model a financing round
/// capTable = capTable.modelRound(
///     preMoneyValuation: 15_000_000,
///     investment: 5_000_000,
///     investorName: "VC Fund"
/// )
/// ```
public struct CapTable {
    /// Represents a shareholder in the cap table
    public struct Shareholder {
        public let name: String
        public let shares: Double
        public let investmentDate: Date
        public let pricePerShare: Double
        public let antiDilution: AntiDilutionType?
        public let liquidationPreference: Double?
        public let participating: Bool?

        public init(
            name: String,
            shares: Double,
            investmentDate: Date,
            pricePerShare: Double,
            antiDilution: AntiDilutionType? = nil,
            liquidationPreference: Double? = nil,
            participating: Bool? = nil
        ) {
            self.name = name
            self.shares = shares
            self.investmentDate = investmentDate
            self.pricePerShare = pricePerShare
            self.antiDilution = antiDilution
            self.liquidationPreference = liquidationPreference
            self.participating = participating
        }
    }

    public var shareholders: [Shareholder]
    public var optionPool: Double

    public init(shareholders: [Shareholder], optionPool: Double) {
        self.shareholders = shareholders
        self.optionPool = optionPool
    }

    /// Total shares outstanding (including option pool)
    public var totalShares: Double {
        return shareholders.reduce(0.0) { $0 + $1.shares } + optionPool
    }

    /// Calculate ownership percentages for each shareholder
    public func ownership() -> [String: Double] {
        let total = totalShares
        guard total > 0 else { return [:] }

        var result: [String: Double] = [:]
        result.reserveCapacity(shareholders.count)

        for shareholder in shareholders {
            result[shareholder.name, default: 0.0] += shareholder.shares / total
        }

        return result
    }

    /// Option pool as percentage of total shares
    public var optionPoolPercentage: Double {
        guard totalShares > 0 else { return 0.0 }
        return optionPool / totalShares
    }

    /// Pre-money valuation based on last share price
    public func preMoneyValuation() -> Double {
        guard let lastPrice = shareholders.last?.pricePerShare else { return 0.0 }
        return lastPrice * totalShares
    }

    /// Post-money valuation (same as pre-money for an existing cap table)
    public func postMoneyValuation() -> Double {
        return preMoneyValuation()
    }

    /// Get the most recent price per share
    public func currentPricePerShare() -> Double {
        guard let lastShareholder = shareholders.last else { return 0.0 }
        return lastShareholder.pricePerShare
    }

    /// Total shares outstanding (excluding option pool)
    public func outstandingShares() -> Double {
        return shareholders.reduce(0.0) { $0 + $1.shares }
    }

    /// Fully diluted shares (including option pool)
    public func fullyDilutedShares() -> Double {
        return totalShares
    }

    /// Grant options from the option pool to a recipient
    public func grantOptions(
        recipient: String,
        shares: Double,
        strikePrice: Double
    ) -> CapTable {
        let newShareholder = Shareholder(
            name: recipient,
            shares: shares,
            investmentDate: Date(),
            pricePerShare: strikePrice
        )

        return CapTable(
            shareholders: shareholders + [newShareholder],
            optionPool: optionPool - shares
        )
    }

    /// Model a down round with anti-dilution protection
    public func modelDownRound(
        newInvestment: Double,
        preMoneyValuation: Double,
        payToPlayParticipants: [String]
    ) -> CapTable {
        // Simplified down round - similar to regular round but at lower valuation
        let postMoneyValuation = preMoneyValuation + newInvestment
        let investorOwnership = newInvestment / postMoneyValuation
        let pricePerShare = preMoneyValuation / totalShares

        let investorShares = (investorOwnership / (1.0 - investorOwnership)) * totalShares

        let investor = Shareholder(
            name: "Down Round Investor",
            shares: investorShares,
            investmentDate: Date(),
            pricePerShare: pricePerShare
        )

        // TODO: Apply anti-dilution protection for existing shareholders
        // For now, simple dilution
        return CapTable(
            shareholders: shareholders + [investor],
            optionPool: optionPool
        )
    }

    /// Calculate liquidation waterfall distribution
    public func liquidationWaterfall(exitValue: Double) -> [String: Double] {
        var distribution: [String: Double] = [:]
        var remainingValue = exitValue

        // Separate shareholders by type
        var nonParticipating: [Shareholder] = []
        var participating: [Shareholder] = []
        var common: [Shareholder] = []

        for shareholder in shareholders {
            if let liquidationPref = shareholder.liquidationPreference,
               let isParticipating = shareholder.participating {
                if isParticipating {
                    participating.append(shareholder)
                } else {
                    nonParticipating.append(shareholder)
                }
            } else {
                common.append(shareholder)
            }
        }

        // Step 1: Pay non-participating preferred their preference
        for shareholder in nonParticipating {
            let preferenceAmount = shareholder.shares * shareholder.pricePerShare * (shareholder.liquidationPreference ?? 1.0)
            let paid = min(preferenceAmount, remainingValue)
            distribution[shareholder.name] = paid
            remainingValue -= paid
        }

        // Step 2: Pay participating preferred their preference
        for shareholder in participating {
            let preferenceAmount = shareholder.shares * shareholder.pricePerShare * (shareholder.liquidationPreference ?? 1.0)
            let paid = min(preferenceAmount, remainingValue)
            distribution[shareholder.name, default: 0.0] += paid
            remainingValue -= paid
        }

        // Step 3: Distribute remaining pro-rata to participating preferred + common
        if remainingValue > 0 {
            let participatingShares = participating.reduce(0.0) { $0 + $1.shares } + common.reduce(0.0) { $0 + $1.shares }

            for shareholder in participating + common {
                let proRataShare = shareholder.shares / participatingShares
                let proRataAmount = remainingValue * proRataShare
                distribution[shareholder.name, default: 0.0] += proRataAmount
            }
        }

        return distribution
    }

    /// Model a financing round
    public func modelRound(
        newInvestment: Double,
        preMoneyValuation: Double,
        optionPoolIncrease: Double,
        investorName: String = "Series A Investor",
        poolTiming: OptionPoolTiming = .postRound
    ) -> CapTable {
        let postMoneyValuation = preMoneyValuation + newInvestment
        let investorOwnership = newInvestment / postMoneyValuation
        let pricePerShare = preMoneyValuation / totalShares

        // Calculate new shares for investor
        let investorShares = (investorOwnership / (1.0 - investorOwnership)) * totalShares

        let investor = Shareholder(
            name: investorName,
            shares: investorShares,
            investmentDate: Date(),
            pricePerShare: pricePerShare
        )

        // If optionPoolIncrease is between 0 and 1, treat as percentage
        // Otherwise treat as absolute share count
        let newOptionPool: Double
        if optionPoolIncrease > 0 && optionPoolIncrease < 1 {
            // It's a percentage - calculate based on timing
            let postMoneyShares = totalShares + investorShares
            switch poolTiming {
            case .preRound:
                // Pool created before round, so it dilutes everyone including investor
                newOptionPool = postMoneyShares * optionPoolIncrease / (1.0 - optionPoolIncrease)
            case .postRound:
                // Pool created after round
                newOptionPool = postMoneyShares * optionPoolIncrease
            }
        } else {
            // It's an absolute share count
            newOptionPool = optionPool + optionPoolIncrease
        }

        return CapTable(
            shareholders: shareholders + [investor],
            optionPool: newOptionPool
        )
    }
}

/// Vesting schedule types for option grants
public enum VestingSchedule {
    case standard  // 4 year vest, 1 year cliff
    case custom(years: Double, cliffYears: Double)
}

/// Represents an employee stock option grant
public struct OptionGrant {
    public let recipient: String?
    public let shares: Double
    public let strikePrice: Double?
    public let grantDate: Date
    public let vestingYears: Double
    public let vestingSchedule: VestingSchedule?

    public init(
        recipient: String? = nil,
        shares: Double,
        strikePrice: Double? = nil,
        grantDate: Date,
        vestingYears: Double = 4.0,
        vestingSchedule: VestingSchedule? = nil
    ) {
        self.recipient = recipient
        self.shares = shares
        self.strikePrice = strikePrice
        self.grantDate = grantDate
        self.vestingYears = vestingYears
        self.vestingSchedule = vestingSchedule
    }

    /// Calculate vested shares at a given date
    public func vestedShares(at date: Date) -> Double {
        let timeElapsed = date.timeIntervalSince(grantDate)

        // If there's a vesting schedule, use it
        if let schedule = vestingSchedule {
            switch schedule {
            case .standard:
                // 4 year vest, 1 year cliff
                let cliffSeconds = 365.0 * 24 * 3600 // 1 year (using 365 days)
                if timeElapsed < cliffSeconds {
                    return 0.0 // No vesting before cliff
                }

                // After cliff, linear vesting over 4 years
                let vestingSeconds = 4.0 * 365.0 * 24 * 3600
                let vestingProgress = min(1.0, timeElapsed / vestingSeconds)
                return shares * vestingProgress

            case .custom(let years, let cliffYears):
                let cliffSeconds = cliffYears * 365.0 * 24 * 3600
                if timeElapsed < cliffSeconds {
                    return 0.0
                }

                let vestingSeconds = years * 365.0 * 24 * 3600
                let vestingProgress = min(1.0, timeElapsed / vestingSeconds)
                return shares * vestingProgress
            }
        } else {
            // Simple linear vesting
            let vestingSeconds = vestingYears * 365.0 * 24 * 3600
            let vestingProgress = min(1.0, timeElapsed / vestingSeconds)
            return shares * vestingProgress
        }
    }
}

/// Timing for option pool creation
public enum OptionPoolTiming {
    case preRound   // Pool created before financing round
    case postRound  // Pool created after financing round
}

/// Calculate option pool dilution when creating an option pool
public func optionPoolDilution(
    currentShares: Double,
    optionPoolPercent: Double,
    timing: OptionPoolTiming
) -> Double {
    switch timing {
    case .preRound:
        // Pool is a percentage of total (existing + pool)
        // If we want 10% pool: poolShares / (currentShares + poolShares) = 0.10
        // poolShares = 0.10 * (currentShares + poolShares)
        // poolShares = 0.10 * currentShares / 0.90
        return optionPoolPercent
    case .postRound:
        // Pool is a percentage of total after round
        return optionPoolPercent
    }
}

/// Calculate 409A fair market value for private company stock
public func calculate409APrice(
    preferredPrice: Double,
    discount: Double
) -> Double {
    // Simplified: common stock typically priced at discount to preferred
    return preferredPrice * (1.0 - discount)
}

/// Anti-dilution protection types
public enum AntiDilutionType {
    case fullRatchet
    case weightedAverage
}

/// Apply full ratchet anti-dilution adjustment
public func applyAntiDilution(
    originalShares: Double,
    originalPrice: Double,
    newPrice: Double,
    type: AntiDilutionType
) -> Double {
    switch type {
    case .fullRatchet:
        // New shares = original shares × (original price / new price)
        return originalShares * (originalPrice / newPrice)
    case .weightedAverage:
        // Simplified weighted average (would need more parameters for full calculation)
        let ratio = originalPrice / newPrice
        let adjustment = (ratio - 1.0) * 0.5 + 1.0  // Simplified
        return originalShares * adjustment
    }
}

/// Apply weighted average anti-dilution protection
public func applyWeightedAverageAntiDilution(
    originalShares: Double,
    originalPrice: Double,
    newPrice: Double,
    newShares: Double,
    fullyDilutedBefore: Double
) -> Double {
    // Weighted average formula
    let numerator = (fullyDilutedBefore * originalPrice) + (newShares * newPrice)
    let denominator = fullyDilutedBefore + newShares
    let adjustedPrice = numerator / denominator

    return originalShares * (originalPrice / adjustedPrice)
}

/// Represents a Simple Agreement for Future Equity (SAFE)
public struct SAFE {
    public enum SAFEType {
        case postMoney
        case preMoney
    }

    public let investment: Double
    public let postMoneyCap: Double
    public let type: SAFEType

    public init(investment: Double, postMoneyCap: Double, type: SAFEType) {
        self.investment = investment
        self.postMoneyCap = postMoneyCap
        self.type = type
    }

    /// Convert SAFE to equity at a priced round
    public func convert(seriesAValuation: Double) -> SAFEConversion {
        switch type {
        case .postMoney:
            // Post-money SAFE: ownership = investment / cap
            let ownershipPct = investment / postMoneyCap
            // Assume cap is based on some standard share count (e.g., 10M shares)
            let assumedShares = 10_000_000.0
            let pricePerShare = postMoneyCap / assumedShares
            let shares = investment / pricePerShare

            return SAFEConversion(
                shares: shares,
                pricePerShare: pricePerShare,
                appliedTerm: .cap,
                ownershipPercentOverride: ownershipPct
            )

        case .preMoney:
            // Pre-money SAFE: use cap vs series A price
            let capPrice = postMoneyCap / 10_000_000
            let seriesAPrice = seriesAValuation / 10_000_000

            let conversionPrice = min(capPrice, seriesAPrice)
            let shares = investment / conversionPrice

            return SAFEConversion(
                shares: shares,
                pricePerShare: conversionPrice,
                appliedTerm: conversionPrice == capPrice ? .cap : .seriesAPrice,
                ownershipPercentOverride: nil
            )
        }
    }
}

public struct SAFEConversion {
    public enum AppliedTerm {
        case cap
        case seriesAPrice
    }

    public let shares: Double
    public let pricePerShare: Double
    public let appliedTerm: AppliedTerm
    public let ownershipPercentOverride: Double?

    public init(
        shares: Double,
        pricePerShare: Double,
        appliedTerm: AppliedTerm,
        ownershipPercentOverride: Double? = nil
    ) {
        self.shares = shares
        self.pricePerShare = pricePerShare
        self.appliedTerm = appliedTerm
        self.ownershipPercentOverride = ownershipPercentOverride
    }

    /// Alias for shares for compatibility
    public var sharesIssued: Double { shares }

    /// Alias for pricePerShare for compatibility
    public var effectivePrice: Double { pricePerShare }

    /// Ownership percentage (requires total shares outstanding to calculate)
    /// This is a simplified calculation assuming 10M shares outstanding
    public var ownershipPercent: Double {
        if let override = ownershipPercentOverride {
            return override
        }
        return shares / (10_000_000.0 + shares)
    }
}

/// Represents a convertible note
public struct ConvertibleNote {
    public let principal: Double
    public let valuationCap: Double
    public let discount: Double
    public let interestRate: Double

    public init(principal: Double, valuationCap: Double, discount: Double, interestRate: Double) {
        self.principal = principal
        self.valuationCap = valuationCap
        self.discount = discount
        self.interestRate = interestRate
    }
}

/// Convert a convertible note to equity
public func convertNote(
    principal: Double,
    valuationCap: Double,
    discount: Double,
    seriesAPricePerShare: Double,
    interestRate: Double = 0.0,
    timeHeld: Double = 0.0
) -> SAFEConversion {
    // Calculate principal + accrued interest
    let accruedInterest = principal * interestRate * timeHeld
    let totalAmount = principal + accruedInterest

    let capPrice = valuationCap / 10_000_000  // Simplified
    let discountedPrice = seriesAPricePerShare * (1.0 - discount)

    let conversionPrice = min(capPrice, discountedPrice)
    let shares = totalAmount / conversionPrice

    return SAFEConversion(
        shares: shares,
        pricePerShare: conversionPrice,
        appliedTerm: conversionPrice == capPrice ? .cap : .seriesAPrice,
        ownershipPercentOverride: nil
    )
}

/// Calculate pre-money valuation from post-money and investment
public func preMoneyFromPostMoney(postMoney: Double, investment: Double) -> Double {
    return postMoney - investment
}

/// Calculate post-money valuation from pre-money and investment
public func postMoneyFromPreMoney(preMoney: Double, investment: Double) -> Double {
    return preMoney + investment
}

/// Calculate ownership percentage from investment and valuation
public func ownershipFromInvestment(investment: Double, postMoneyValuation: Double) -> Double {
    return investment / postMoneyValuation
}
