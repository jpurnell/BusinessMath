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
    /// Represents a shareholder in the cap table.
    ///
    /// A shareholder record tracks ownership details including share count,
    /// investment terms, and special rights (anti-dilution, liquidation preferences).
    ///
    /// ## Usage Example
    /// ```swift
    /// // Founder shares
    /// let founder = CapTable.Shareholder(
    ///     name: "Alice",
    ///     shares: 10_000_000,
    ///     investmentDate: Date(),
    ///     pricePerShare: 0.001
    /// )
    ///
    /// // Preferred investor with liquidation preference
    /// let investor = CapTable.Shareholder(
    ///     name: "VC Fund",
    ///     shares: 2_000_000,
    ///     investmentDate: Date(),
    ///     pricePerShare: 2.50,
    ///     antiDilution: .weightedAverage,
    ///     liquidationPreference: 1.0,
    ///     participating: false
    /// )
    /// ```
    ///
    /// ## SeeAlso
    /// - ``CapTable``
    /// - ``AntiDilutionType``
    public struct Shareholder {
        /// The name or identifier of the shareholder.
        ///
        /// Can be a person ("Alice"), entity ("VC Fund"), or category ("Employees").
        public let name: String

        /// Number of shares owned.
        ///
        /// Can be fractional for scenarios involving stock splits or conversions.
        public let shares: Double

        /// Date when shares were acquired or granted.
        ///
        /// Used for vesting calculations and determining share basis for tax purposes.
        public let investmentDate: Date

        /// Price paid per share.
        ///
        /// For founders, this is typically a nominal amount (e.g., $0.001).
        /// For investors, this is the purchase price from their financing round.
        public let pricePerShare: Double

        /// Type of anti-dilution protection, if any.
        ///
        /// Anti-dilution provisions protect investors from dilution in down rounds.
        /// Common types:
        /// - ``AntiDilutionType/fullRatchet``: Full protection (more favorable to investor)
        /// - ``AntiDilutionType/weightedAverage``: Partial protection (more balanced)
        ///
        /// Typically only present for preferred shares. Common shares don't have anti-dilution rights.
        public let antiDilution: AntiDilutionType?

        /// Liquidation preference multiple.
        ///
        /// Determines the amount preferred shareholders receive before common shareholders
        /// in a liquidation event. For example:
        /// - `1.0`: 1x preference (get back investment before common shareholders)
        /// - `2.0`: 2x preference (get back 2× investment before common)
        ///
        /// Only applies to preferred shares. Common shares have no liquidation preference.
        public let liquidationPreference: Double?

        /// Whether the preferred shares are participating.
        ///
        /// Participating preferred gets:
        /// 1. Their liquidation preference first
        /// 2. Then participates pro-rata in remaining proceeds with common
        ///
        /// Non-participating preferred chooses the greater of:
        /// - Liquidation preference amount, OR
        /// - Pro-rata share as if converted to common
        ///
        /// Only relevant for preferred shares with a liquidation preference.
        public let participating: Bool?

        /// Creates a shareholder record.
        ///
        /// - Parameters:
        ///   - name: Shareholder name or identifier
        ///   - shares: Number of shares owned
        ///   - investmentDate: Date shares were acquired
        ///   - pricePerShare: Price paid per share
        ///   - antiDilution: Anti-dilution protection type (optional, for preferred shares)
        ///   - liquidationPreference: Liquidation preference multiple (optional, for preferred shares)
        ///   - participating: Whether preferred shares participate after preference (optional)
        ///
        /// ## Usage Example
        /// ```swift
        /// // Common shareholder (founder)
        /// let founder = Shareholder(
        ///     name: "Founder",
        ///     shares: 8_000_000,
        ///     investmentDate: Date(),
        ///     pricePerShare: 0.001
        /// )
        ///
        /// // Preferred shareholder (investor)
        /// let investor = Shareholder(
        ///     name: "Series A Investor",
        ///     shares: 2_000_000,
        ///     investmentDate: Date(),
        ///     pricePerShare: 2.00,
        ///     antiDilution: .weightedAverage,
        ///     liquidationPreference: 1.0,
        ///     participating: false
        /// )
        /// ```
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

    /// Array of all shareholders in the cap table.
    ///
    /// Includes founders, investors, employees, and anyone else who owns shares.
    /// Order matters for some operations (e.g., determining "last price").
    public var shareholders: [Shareholder]

    /// Number of shares reserved for future employee option grants.
    ///
    /// The option pool represents shares set aside for employee equity compensation.
    /// These shares are typically "unallocated" until granted to specific employees.
    ///
    /// ## Common Sizes
    /// - Early stage: 10-20% of fully diluted shares
    /// - Later stage: 5-10% of fully diluted shares
    public var optionPool: Double

    /// Creates a cap table with shareholders and an option pool.
    ///
    /// - Parameters:
    ///   - shareholders: Array of shareholders with their ownership details
    ///   - optionPool: Number of shares reserved for employee options
    ///
    /// ## Usage Example
    /// ```swift
    /// let founders = [
    ///     CapTable.Shareholder(name: "Alice", shares: 5_000_000, investmentDate: Date(), pricePerShare: 0.001),
    ///     CapTable.Shareholder(name: "Bob", shares: 5_000_000, investmentDate: Date(), pricePerShare: 0.001)
    /// ]
    ///
    /// let capTable = CapTable(
    ///     shareholders: founders,
    ///     optionPool: 2_000_000  // 16.7% option pool
    /// )
    /// ```
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
            if let _ = shareholder.liquidationPreference,
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

/// Represents an employee stock option grant.
///
/// Option grants give employees the right to purchase shares at a fixed price
/// (strike price) after they vest over time. This is a common form of equity
/// compensation.
///
/// ## Usage Example
/// ```swift
/// let grant = OptionGrant(
///     recipient: "Employee 001",
///     shares: 100_000,
///     strikePrice: 0.50,
///     grantDate: Date(),
///     vestingYears: 4.0,
///     vestingSchedule: .standard  // 4 years, 1 year cliff
/// )
///
/// // Check vested amount after 2 years
/// let futureDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
/// let vested = grant.vestedShares(at: futureDate)
/// print("Vested: \(vested) shares")  // ~50,000 shares
/// ```
///
/// ## SeeAlso
/// - ``VestingSchedule``
/// - ``CapTable``
public struct OptionGrant {
    /// Name or identifier of the recipient.
    ///
    /// Optional to support anonymous grants or grants pending recipient assignment.
    public let recipient: String?

    /// Total number of shares granted.
    ///
    /// This is the total grant size before vesting. Actual exercisable shares
    /// depend on how much has vested over time.
    public let shares: Double

    /// Exercise (strike) price per share.
    ///
    /// The price the employee must pay to exercise the options and buy shares.
    /// Typically set at the 409A fair market value at grant date.
    ///
    /// Optional to support grants where strike price is determined later.
    public let strikePrice: Double?

    /// Date the options were granted.
    ///
    /// Vesting starts from this date. This is also the date used to determine
    /// the strike price for tax purposes.
    public let grantDate: Date

    /// Total vesting period in years.
    ///
    /// Standard is 4 years, but can vary. Options vest gradually over this period.
    /// Defaults to 4.0 years.
    public let vestingYears: Double

    /// Vesting schedule defining how options vest over time.
    ///
    /// Common schedules:
    /// - ``VestingSchedule/standard``: 4 years with 1 year cliff (25% after year 1, then monthly)
    /// - ``VestingSchedule/custom(years:cliffYears:)``: Custom vesting period and cliff
    ///
    /// If nil, uses simple linear vesting based on ``vestingYears``.
    public let vestingSchedule: VestingSchedule?

    /// Creates an option grant.
    ///
    /// - Parameters:
    ///   - recipient: Name or ID of the recipient (optional)
    ///   - shares: Total number of shares granted
    ///   - strikePrice: Exercise price per share (optional)
    ///   - grantDate: Date options were granted
    ///   - vestingYears: Vesting period in years (default: 4.0)
    ///   - vestingSchedule: Vesting schedule type (optional)
    ///
    /// ## Usage Example
    /// ```swift
    /// // Standard 4-year vest with 1-year cliff
    /// let standardGrant = OptionGrant(
    ///     recipient: "Alice",
    ///     shares: 50_000,
    ///     strikePrice: 1.00,
    ///     grantDate: Date(),
    ///     vestingSchedule: .standard
    /// )
    ///
    /// // Custom 3-year vest with 6-month cliff
    /// let customGrant = OptionGrant(
    ///     recipient: "Bob",
    ///     shares: 25_000,
    ///     strikePrice: 1.00,
    ///     grantDate: Date(),
    ///     vestingSchedule: .custom(years: 3.0, cliffYears: 0.5)
    /// )
    /// ```
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

/// Represents a Simple Agreement for Future Equity (SAFE).
///
/// A SAFE is a financial instrument used in early-stage fundraising that converts
/// to equity in a future priced round. It's simpler than convertible notes (no
/// interest or maturity date).
///
/// ## Key Concepts
/// - **Valuation Cap**: Maximum valuation at which the SAFE converts
/// - **Post-Money vs Pre-Money**: Determines whether SAFE dilutes other SAFEs
/// - **Conversion**: Happens at next priced round, using the lower of cap or round price
///
/// ## Usage Example
/// ```swift
/// // Company raises $500K on a $5M post-money cap
/// let safe = SAFE(
///     investment: 500_000,
///     postMoneyCap: 5_000_000,
///     type: .postMoney
/// )
///
/// // Later, Series A at $10M valuation
/// let conversion = safe.convert(seriesAValuation: 10_000_000)
/// print("SAFE converts to \(conversion.shares) shares")
/// print("At price: $\(conversion.pricePerShare)")
/// print("Ownership: \(conversion.ownershipPercent * 100)%")
/// ```
///
/// ## SeeAlso
/// - ``SAFEType``
/// - ``SAFEConversion``
/// - ``ConvertibleNote``
public struct SAFE {
    /// Type of SAFE (post-money or pre-money).
    ///
    /// Determines how the SAFE interacts with other SAFEs and the priced round:
    /// - **Post-Money**: Ownership % is fixed regardless of other SAFEs. All SAFEs
    ///   with the same cap get the same price. More founder-friendly.
    /// - **Pre-Money**: Each SAFE dilutes subsequent SAFEs. First SAFE gets best
    ///   price. More investor-friendly.
    ///
    /// ## Usage Example
    /// ```swift
    /// // Post-money SAFE (Y Combinator standard)
    /// let postMoney = SAFE(
    ///     investment: 250_000,
    ///     postMoneyCap: 10_000_000,
    ///     type: .postMoney
    /// )
    ///
    /// // Pre-money SAFE (older style)
    /// let preMoney = SAFE(
    ///     investment: 250_000,
    ///     postMoneyCap: 10_000_000,  // Acts as pre-money cap
    ///     type: .preMoney
    /// )
    /// ```
    public enum SAFEType {
        /// Post-money SAFE (Y Combinator standard since 2018).
        ///
        /// Converts at: `investment / cap` ownership percentage.
        /// All post-money SAFEs with same cap convert at same price.
        case postMoney

        /// Pre-money SAFE (older format).
        ///
        /// Converts at the lower of: cap price or Series A price.
        /// Each SAFE dilutes subsequent SAFEs.
        case preMoney
    }

    /// Amount invested via the SAFE.
    ///
    /// This is the cash the investor provides to the company. It will
    /// convert to equity shares at a future priced round.
    public let investment: Double

    /// Valuation cap for conversion.
    ///
    /// Maximum valuation used for SAFE conversion. If the priced round
    /// values the company higher than this cap, the SAFE investor gets
    /// a better (lower) price per share.
    ///
    /// ## Example
    /// - Cap: $5M
    /// - Series A valuation: $10M
    /// - SAFE converts using $5M cap → investor gets 2× more shares than
    ///   Series A investors per dollar invested
    public let postMoneyCap: Double

    /// Type of SAFE (post-money or pre-money).
    ///
    /// See ``SAFEType`` for detailed explanation of the difference.
    public let type: SAFEType

    /// Creates a SAFE instrument.
    ///
    /// - Parameters:
    ///   - investment: Amount invested
    ///   - postMoneyCap: Valuation cap (acts as post-money cap for post-money SAFEs, pre-money for pre-money)
    ///   - type: Type of SAFE
    ///
    /// ## Usage Example
    /// ```swift
    /// // Typical seed SAFE
    /// let seedSafe = SAFE(
    ///     investment: 500_000,
    ///     postMoneyCap: 8_000_000,
    ///     type: .postMoney
    /// )
    ///
    /// // Convert at Series A
    /// let conversion = seedSafe.convert(seriesAValuation: 15_000_000)
    /// ```
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

/// Result of converting a SAFE to equity shares.
///
/// When a SAFE converts at a priced round, this structure captures the
/// conversion details: how many shares, at what price, and which term applied.
///
/// ## Usage Example
/// ```swift
/// let safe = SAFE(investment: 500_000, postMoneyCap: 5_000_000, type: .postMoney)
/// let conversion = safe.convert(seriesAValuation: 10_000_000)
///
/// print("Shares: \(conversion.shares)")
/// print("Price: $\(conversion.pricePerShare)")
/// print("Term: \(conversion.appliedTerm)")  // .cap or .seriesAPrice
/// print("Ownership: \(conversion.ownershipPercent * 100)%")
/// ```
///
/// ## SeeAlso
/// - ``SAFE``
/// - ``SAFEType``
public struct SAFEConversion {
    /// Which term governed the SAFE conversion.
    ///
    /// Indicates whether the SAFE converted using its valuation cap or
    /// the Series A price. The SAFE converts at whichever gives the investor
    /// more shares (lower price per share).
    ///
    /// ## Cases
    /// - ``cap``: Valuation cap was lower, so SAFE used cap price
    /// - ``seriesAPrice``: Series A price was lower (rare), so SAFE used that
    ///
    /// ## Example
    /// ```swift
    /// let safe = SAFE(investment: 1_000_000, postMoneyCap: 8_000_000, type: .postMoney)
    ///
    /// // Series A at $12M → cap is lower, SAFE gets better deal
    /// let conversion1 = safe.convert(seriesAValuation: 12_000_000)
    /// // conversion1.appliedTerm == .cap
    ///
    /// // Series A at $5M → Series A price is lower (down round)
    /// let conversion2 = safe.convert(seriesAValuation: 5_000_000)
    /// // conversion2.appliedTerm == .seriesAPrice
    /// ```
    public enum AppliedTerm {
        /// Conversion used the valuation cap.
        ///
        /// This is the typical case when the priced round values the company
        /// above the SAFE's cap. The investor gets a discount.
        case cap

        /// Conversion used the Series A price.
        ///
        /// Rare case where the priced round values the company below the
        /// SAFE's cap. No discount—investor converts at same price as new investors.
        case seriesAPrice
    }

    /// Number of shares issued to the SAFE holder.
    ///
    /// Calculated based on the investment amount divided by the conversion price.
    public let shares: Double

    /// Price per share at which the SAFE converted.
    ///
    /// Lower than Series A price when cap applies, equal to Series A price otherwise.
    public let pricePerShare: Double

    /// Which term governed the conversion (cap or Series A price).
    ///
    /// Indicates whether the SAFE investor received a discount (cap applied)
    /// or converted at the same price as new investors (Series A price applied).
    public let appliedTerm: AppliedTerm

    /// Optional explicit ownership percentage.
    ///
    /// For post-money SAFEs, this can be calculated directly from the cap.
    /// When present, this overrides ownership calculation from share count.
    ///
    /// Formula: `investment / postMoneyCap`
    public let ownershipPercentOverride: Double?

    /// Creates a SAFE conversion result.
    ///
    /// - Parameters:
    ///   - shares: Number of shares issued
    ///   - pricePerShare: Conversion price per share
    ///   - appliedTerm: Which term applied (cap or Series A price)
    ///   - ownershipPercentOverride: Explicit ownership % (optional, for post-money SAFEs)
    ///
    /// ## Usage Example
    /// ```swift
    /// // Typical usage is via SAFE.convert(), not direct initialization
    /// let safe = SAFE(investment: 250_000, postMoneyCap: 5_000_000, type: .postMoney)
    /// let conversion = safe.convert(seriesAValuation: 10_000_000)
    /// // conversion contains: shares, pricePerShare, appliedTerm, ownership%
    /// ```
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

/// Represents a convertible note.
///
/// A convertible note is a debt instrument that converts to equity at a future
/// priced round. Unlike SAFEs, convertible notes:
/// - Accrue interest over time
/// - Have a maturity date
/// - Are actual debt (appear on balance sheet)
///
/// ## Key Terms
/// - **Principal**: Amount of debt
/// - **Interest Rate**: Annual interest accrual (e.g., 5% = 0.05)
/// - **Valuation Cap**: Maximum conversion valuation
/// - **Discount**: Discount to Series A price (e.g., 20% = 0.20)
///
/// ## Conversion Mechanics
/// Note converts at the **lower** of:
/// 1. Cap price: `valuationCap / assumedShares`
/// 2. Discounted price: `seriesAPrice × (1 - discount)`
///
/// Amount converted: `principal + accruedInterest`
///
/// ## Usage Example
/// ```swift
/// // $1M note with 5% interest, $8M cap, 20% discount
/// let note = ConvertibleNote(
///     principal: 1_000_000,
///     valuationCap: 8_000_000,
///     discount: 0.20,
///     interestRate: 0.05
/// )
///
/// // Convert after 1.5 years at $10M Series A
/// let conversion = convertNote(
///     principal: note.principal,
///     valuationCap: note.valuationCap,
///     discount: note.discount,
///     seriesAPricePerShare: 2.00,
///     interestRate: note.interestRate,
///     timeHeld: 1.5
/// )
/// ```
///
/// ## SeeAlso
/// - ``SAFE``
/// - ``SAFEConversion``
/// - ``convertNote(principal:valuationCap:discount:seriesAPricePerShare:interestRate:timeHeld:)``
public struct ConvertibleNote {
    /// Principal amount of the note.
    ///
    /// This is the initial debt amount—the cash the investor provides.
    /// At conversion, this amount plus accrued interest converts to shares.
    public let principal: Double

    /// Valuation cap for conversion.
    ///
    /// Maximum valuation used to calculate conversion price. If the priced
    /// round values the company above this cap, the note holder gets a
    /// better (lower) price per share.
    ///
    /// Similar to SAFE caps, but convertible notes also have a discount.
    public let valuationCap: Double

    /// Discount to Series A price.
    ///
    /// Percentage discount applied to the priced round's share price.
    /// Express as decimal (0.20 = 20% discount).
    ///
    /// ## Example
    /// - Series A price: $2.00/share
    /// - Discount: 20% (0.20)
    /// - Discounted price: $1.60/share
    ///
    /// Note converts at lower of cap price or discounted price.
    public let discount: Double

    /// Annual interest rate.
    ///
    /// Interest accrues annually on the principal and is added to the
    /// conversion amount. Express as decimal (0.05 = 5% annual interest).
    ///
    /// ## Example
    /// - Principal: $1M
    /// - Interest rate: 5% (0.05)
    /// - Time held: 2 years
    /// - Accrued interest: $100K
    /// - Total conversion amount: $1.1M
    public let interestRate: Double

    /// Creates a convertible note instrument.
    ///
    /// - Parameters:
    ///   - principal: Principal debt amount
    ///   - valuationCap: Valuation cap for conversion
    ///   - discount: Discount to Series A price (as decimal, e.g., 0.20 for 20%)
    ///   - interestRate: Annual interest rate (as decimal, e.g., 0.05 for 5%)
    ///
    /// ## Usage Example
    /// ```swift
    /// // Standard convertible note terms
    /// let note = ConvertibleNote(
    ///     principal: 500_000,
    ///     valuationCap: 6_000_000,
    ///     discount: 0.20,  // 20% discount
    ///     interestRate: 0.06  // 6% annual interest
    /// )
    /// ```
    ///
    /// ## Typical Ranges
    /// - **Discount**: 15-25% (commonly 20%)
    /// - **Interest Rate**: 2-8% (commonly 5%)
    /// - **Cap**: Varies by stage and location
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
