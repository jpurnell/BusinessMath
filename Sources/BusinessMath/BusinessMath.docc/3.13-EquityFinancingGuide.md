# Equity Financing and Cap Table Modeling

Model startup financing rounds, cap tables, SAFEs, convertible notes, and liquidation scenarios.

## Overview

Equity financing is essential for startups raising capital. The ``CapTable`` type provides comprehensive tools for:
- Tracking shareholder ownership through multiple financing rounds
- Modeling SAFEs (Simple Agreement for Future Equity) and convertible notes
- Calculating dilution from option pools and new investments
- Simulating liquidation waterfalls with preference stacks
- Handling anti-dilution protections and down rounds

This guide walks through common equity financing scenarios from formation through exit.

## Creating Your First Cap Table

Start by creating a cap table with founding shareholders:

```swift
import BusinessMath

// Create founders as shareholders
let alice = CapTable.Shareholder(
    name: "Alice",
    shares: 7_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

let bob = CapTable.Shareholder(
    name: "Bob",
    shares: 3_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

// Create cap table with founders
var capTable = CapTable(
    shareholders: [alice, bob],
    optionPool: 0
)

// Check ownership
let ownership = capTable.ownership()
let aliceOwnership = ownership["Alice"]!
print("Alice owns: \(aliceOwnership * 100)%")  // 70%
```

## Adding an Option Pool

Most VCs require an option pool for employee equity. Option pools are typically created as part of a financing round:

```swift
// Calculate what a 10% post-money option pool means for dilution
let poolPercent = 0.10
let currentShares = capTable.totalShares

// Pool will be 10% of total after creation
let poolShares = (poolPercent / (1.0 - poolPercent)) * currentShares

// Create updated cap table with option pool
let dilutedCapTable = CapTable(
    shareholders: capTable.shareholders,
    optionPool: poolShares
)

// Option pool dilutes everyone proportionally
let newOwnership = dilutedCapTable.ownership()
let aliceNewOwnership = newOwnership["Alice"]!
print("Alice after option pool: \(aliceNewOwnership * 100)%")  // ~63.6%
```

## Modeling a Series A Round

Add your first institutional financing round:

```swift
// Series A: $2M at $8M pre-money valuation
let seriesA = capTable.modelRound(
    newInvestment: 2_000_000,
    preMoneyValuation: 8_000_000,
    optionPoolIncrease: 0.15,  // Add 15% option pool
    investorName: "VC Fund I",
    poolTiming: .postRound
)

// Check post-round ownership
let postRoundOwnership = seriesA.ownership()
let alicePostRound = postRoundOwnership["Alice"]!
print("Alice after Series A: \(alicePostRound * 100)%")

// VC owns 20% ($2M / $10M post-money)
let vcOwnership = postRoundOwnership["VC Fund I"]!
print("VC owns: \(vcOwnership * 100)%")
```

## SAFE Financing

Model pre-seed or seed financing with SAFEs:

```swift
// Company issues $500K SAFE at $10M post-money cap
let safe = SAFE(
    investment: 500_000,
    postMoneyCap: 10_000_000,
    type: .postMoney
)

// Convert at Series A valuation
let conversion = safe.convert(seriesAValuation: 8_000_000)

print("SAFE converts to \(conversion.shares) shares")
print("Price per share: $\(conversion.pricePerShare)")
print("Ownership: \(conversion.ownershipPercent * 100)%")  // 5%
```

Add the SAFE investor to your cap table:

```swift
let safeInvestor = CapTable.Shareholder(
    name: "Angel Investor",
    shares: conversion.shares,
    investmentDate: Date(),
    pricePerShare: conversion.pricePerShare
)

let capTableWithSafe = CapTable(
    shareholders: capTable.shareholders + [safeInvestor],
    optionPool: capTable.optionPool
)
```

## Convertible Notes

Model convertible debt with interest and conversion:

```swift
// $250K note at 20% discount, 6% annual interest, $5M cap
let note = ConvertibleNote(
    principal: 250_000,
    valuationCap: 5_000_000,
    discount: 0.20,
    interestRate: 0.06
)

// Series A price per share
let seriesAPricePerShare = 1.00

// Convert at Series A pricing (after 1 year)
let noteConversion = convertNote(
    principal: note.principal,
    valuationCap: note.valuationCap,
    discount: note.discount,
    seriesAPricePerShare: seriesAPricePerShare,
    interestRate: note.interestRate,
    timeHeld: 1.0  // 1 year
)

print("Note converts to \(noteConversion.shares) shares")
print("At price: $\(noteConversion.pricePerShare)")
print("Applied \(noteConversion.appliedTerm)")  // .cap or .seriesAPrice
```

## Vesting Schedules

Model employee stock options with standard 4-year vest:

```swift
// Grant 100K options to an employee
let optionGrant = OptionGrant(
    recipient: "Employee",
    shares: 100_000,
    strikePrice: 0.50,  // FMV at grant
    grantDate: Date(),
    vestingYears: 4.0,
    vestingSchedule: .standard  // 4 year, 1 year cliff
)

// Check vested shares after 18 months
let grantDate = optionGrant.grantDate
let checkDate = Calendar.current.date(byAdding: .month, value: 18, to: grantDate)!
let vestedShares = optionGrant.vestedShares(at: checkDate)
print("Vested after 18 months: \(vestedShares)")  // ~37,500 shares
```

## Down Rounds and Anti-Dilution

Handle down rounds with anti-dilution protection:

```swift
// Series B at lower valuation than Series A
// Down from $10M post-Series A to $6M pre-money
let downRound = capTable.modelDownRound(
    newInvestment: 3_000_000,
    preMoneyValuation: 6_000_000,
    payToPlayParticipants: ["VC Fund I"]  // Investors participating in down round
)

// Creates new investor at lower valuation
// Pay-to-play: participating investors avoid additional dilution
```

For manual anti-dilution adjustments, use the standalone functions:

```swift
// Full ratchet: adjust Series A shares based on new price
let originalShares = 2_000_000.0
let originalPrice = 1.00
let newPrice = 0.67  // Series B price

let adjustedShares = applyAntiDilution(
    originalShares: originalShares,
    originalPrice: originalPrice,
    newPrice: newPrice,
    type: .fullRatchet
)

print("Series A shares after full ratchet: \(adjustedShares)")

// Weighted average (more founder-friendly)
let waShares = applyWeightedAverageAntiDilution(
    originalShares: originalShares,
    originalPrice: originalPrice,
    newPrice: newPrice,
    newShares: 3_000_000,
    fullyDilutedBefore: capTable.fullyDilutedShares()
)

print("Series A shares after weighted average: \(waShares)")
```

## Liquidation Preferences

Model exit scenarios with preference stacks:

```swift
// Create shareholders with liquidation preferences
let vcFundA = CapTable.Shareholder(
    name: "VC Fund I",
    shares: 2_000_000,
    investmentDate: Date(),
    pricePerShare: 1.00,
    antiDilution: nil,
    liquidationPreference: 1.0,
    participating: false  // Takes preference OR pro-rata, whichever is higher
)

let vcFundB = CapTable.Shareholder(
    name: "VC Fund II",
    shares: 1_500_000,
    investmentDate: Date(),
    pricePerShare: 2.00,
    antiDilution: nil,
    liquidationPreference: 2.0,
    participating: true  // Gets preference PLUS pro-rata
)

// Build cap table with preference stack
let preferenceCapTable = CapTable(
    shareholders: [alice, bob, vcFundA, vcFundB],
    optionPool: 1_000_000
)
```

Calculate liquidation waterfall at various exit values:

```swift
// Low exit: $5M (below total invested capital)
let lowExit = preferenceCapTable.liquidationWaterfall(exitValue: 5_000_000)
for (shareholder, payout) in lowExit {
    print("\(shareholder): $\(payout)")
}
// Series B gets 2x preference first, then Series A gets remainder

// High exit: $50M
let highExit = preferenceCapTable.liquidationWaterfall(exitValue: 50_000_000)
for (shareholder, payout) in highExit {
    print("\(shareholder): $\(payout)")
}
// Non-participating preferred converts to common
// Participating preferred gets preference + upside
```

## Full Financing Example

Here's a complete multi-round scenario:

```swift
import BusinessMath

// Formation - Create founders
let founder1 = CapTable.Shareholder(
    name: "Founder 1",
    shares: 6_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

let founder2 = CapTable.Shareholder(
    name: "Founder 2",
    shares: 4_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

var capTable = CapTable(
    shareholders: [founder1, founder2],
    optionPool: 0
)

// Pre-seed SAFE: $500K at $5M post-money
let safe = SAFE(
    investment: 500_000,
    postMoneyCap: 5_000_000,
    type: .postMoney
)

let safeConversion = safe.convert(seriesAValuation: 5_000_000)

let preSeedFund = CapTable.Shareholder(
    name: "Pre-seed Fund",
    shares: safeConversion.shares,
    investmentDate: Date(),
    pricePerShare: safeConversion.pricePerShare
)

capTable = CapTable(
    shareholders: capTable.shareholders + [preSeedFund],
    optionPool: capTable.optionPool
)

// Seed: $2M at $8M pre-money
let seedRound = capTable.modelRound(
    newInvestment: 2_000_000,
    preMoneyValuation: 8_000_000,
    optionPoolIncrease: 0.0,  // No pool yet
    investorName: "Seed Fund",
    poolTiming: .postRound
)

// Add 15% option pool post-Seed
let poolShares = (0.15 / (1.0 - 0.15)) * seedRound.totalShares
let withPool = CapTable(
    shareholders: seedRound.shareholders,
    optionPool: poolShares
)

// Series A: $10M at $40M pre-money
let seriesA = withPool.modelRound(
    newInvestment: 10_000_000,
    preMoneyValuation: 40_000_000,
    optionPoolIncrease: 0.0,  // Pool already exists
    investorName: "Series A Lead",
    poolTiming: .postRound
)

// Final cap table summary
print("=== Cap Table Post-Series A ===")
let ownership = seriesA.ownership()
for shareholder in seriesA.shareholders {
    let ownershipPct = ownership[shareholder.name]!
    print("\(shareholder.name): \(ownershipPct * 100)%")
}

// Outstanding vs fully diluted
let outstanding = seriesA.outstandingShares()
let fullyDiluted = seriesA.fullyDilutedShares()
print("\nOutstanding: \(outstanding)")
print("Fully Diluted: \(fullyDiluted)")

// Exit scenario: $100M acquisition
print("\n=== Exit: $100M ===")
let exitProceeds = seriesA.liquidationWaterfall(exitValue: 100_000_000)
for (shareholder, payout) in exitProceeds.sorted(by: { $0.value > $1.value }) {
    print("\(shareholder): $\(String(format: "%.2f", payout))")
}
```

## Understanding Ownership Dilution

Track how ownership changes through rounds:

```swift
// Track founder ownership through each round
let founderName = "Founder 1"

let formation = capTable.ownership()[founderName]!
let postSeed = seedRound.ownership()[founderName]!
let postPool = withPool.ownership()[founderName]!
let postSeriesA = seriesA.ownership()[founderName]!

print("Ownership trajectory:")
print("Formation: \(formation * 100)%")
print("Post-Seed: \(postSeed * 100)%")
print("Post-Pool: \(postPool * 100)%")
print("Post-Series A: \(postSeriesA * 100)%")
```

## Common Patterns

### Pre-Money vs Post-Money Option Pools

```swift
// Pre-money: Pool dilutes existing shareholders before new investment
let preMoneyRound = capTable.modelRound(
    newInvestment: 2_000_000,
    preMoneyValuation: 8_000_000,
    optionPoolIncrease: 0.15,
    investorName: "Investor",
    poolTiming: .preRound
)

// Post-money: Pool dilutes everyone including new investor
let postMoneyRound = capTable.modelRound(
    newInvestment: 2_000_000,
    preMoneyValuation: 8_000_000,
    optionPoolIncrease: 0.15,
    investorName: "Investor",
    poolTiming: .postRound
)

// Pre-round is more founder-friendly (investor bears pool dilution)
```

### Multiple SAFEs with Different Caps

```swift
// Early SAFE: $100K at $5M cap
let earlySafe = SAFE(
    investment: 100_000,
    postMoneyCap: 5_000_000,
    type: .postMoney
)

let earlySafeConversion = earlySafe.convert(seriesAValuation: 10_000_000)

// Later SAFE: $500K at $8M cap
let laterSafe = SAFE(
    investment: 500_000,
    postMoneyCap: 8_000_000,
    type: .postMoney
)

let laterSafeConversion = laterSafe.convert(seriesAValuation: 10_000_000)

// Early SAFE gets better terms (lower cap = more ownership)
print("Early SAFE ownership: \(earlySafeConversion.ownershipPercent * 100)%")
print("Later SAFE ownership: \(laterSafeConversion.ownershipPercent * 100)%")
```

### 409A Valuations for Option Grants

```swift
// Calculate FMV for common stock options
let preferredPrice = 2.00  // Series A price
let discountFactor = 0.40  // Typical 40% discount

let commonFMV = calculate409APrice(
    preferredPrice: preferredPrice,
    discount: discountFactor
)

print("Strike price for options: $\(commonFMV)")  // $1.20 (60% of preferred)
```

## Next Steps

- Explore <doc:DebtAndFinancingGuide> for debt financing and capital structure
- Learn about <doc:FinancialStatementsGuide> for modeling complete financial statements
- Follow <doc:BuildingRevenueModel> to integrate equity financing into revenue models

## See Also

- ``CapTable``
- ``Shareholder``
- ``SAFETerm``
- ``ConvertibleNoteTerm``
- ``OptionGrant``
- ``ShareClass``
