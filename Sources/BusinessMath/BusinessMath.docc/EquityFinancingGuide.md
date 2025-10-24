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

// Create cap table with two founders
var capTable = CapTable(companyName: "Acme Inc")

// Add founders with initial equity split
capTable.addShareholder(Shareholder(
    name: "Alice",
    shares: 7_000_000,
    pricePerShare: 0.001,
    shareClass: .common
))

capTable.addShareholder(Shareholder(
    name: "Bob",
    shares: 3_000_000,
    pricePerShare: 0.001,
    shareClass: .common
))

// Check ownership
let aliceOwnership = capTable.ownershipPercentage(shareholder: "Alice")
print("Alice owns: \(aliceOwnership * 100)%")  // 70%
```

## Adding an Option Pool

Most VCs require an option pool for employee equity:

```swift
// Create 10% post-money option pool before Series A
// This dilutes founders proportionally
let dilutedCapTable = capTable.addOptionPool(
    poolSize: 0.10,
    timing: .postRound
)

// Option pool dilutes everyone
let newOwnership = dilutedCapTable.ownershipPercentage(shareholder: "Alice")
print("Alice after option pool: \(newOwnership * 100)%")  // 63%
```

## Modeling a Series A Round

Add your first institutional financing round:

```swift
// Series A: $2M at $8M pre-money valuation
let seriesA = capTable.modelFinancingRound(
    investment: 2_000_000,
    preMoneyValuation: 8_000_000,
    investorName: "VC Fund I",
    shareClass: .preferredA,
    liquidationPreference: 1.0,
    participating: false
)

// Check post-round ownership
let postRoundOwnership = seriesA.ownershipPercentage(shareholder: "Alice")
print("Alice after Series A: \(postRoundOwnership * 100)%")

// VC owns 20% ($2M / $10M post-money)
let vcOwnership = seriesA.ownershipPercentage(shareholder: "VC Fund I")
print("VC owns: \(vcOwnership * 100)%")
```

## SAFE Financing

Model pre-seed or seed financing with SAFEs:

```swift
// Company issues $500K SAFE at $10M post-money cap
let safeTerms = SAFETerm(
    cap: 10_000_000,
    discount: nil,
    type: .postMoney
)

let conversion = safeTerms.convertToEquity(
    investment: 500_000,
    valuationAtConversion: 8_000_000  // Series A price
)

print("SAFE converts to \(conversion.shares) shares")
print("Ownership: \(conversion.ownershipPercentOverride! * 100)%")  // 5%
```

Add the SAFE to your cap table:

```swift
capTable.addShareholder(Shareholder(
    name: "Angel Investor",
    shares: conversion.shares,
    pricePerShare: conversion.pricePerShare,
    shareClass: .safe
))
```

## Convertible Notes

Model convertible debt with interest and conversion:

```swift
// $250K note at 20% discount, 6% annual interest
let noteTerms = ConvertibleNoteTerm(
    principal: 250_000,
    interestRate: 0.06,
    discount: 0.20,
    cap: 5_000_000,
    timeToMaturity: 1.0  // 1 year
)

// Convert at Series A pricing
let noteConversion = noteTerms.convertToEquity(
    valuationAtConversion: 8_000_000,
    timeElapsed: 1.0  // Full year elapsed
)

print("Note converts to \(noteConversion.shares) shares")
print("Applied \(noteConversion.appliedTerm)")  // .cap or .discount
```

## Vesting Schedules

Model employee stock options with standard 4-year vest:

```swift
// Grant 100K options to an employee
let optionGrant = OptionGrant(
    grantee: "Employee",
    shares: 100_000,
    strikePrice: 0.50,  // FMV at grant
    vestingSchedule: .standard,  // 4 year, 1 year cliff
    grantDate: Date()
)

// Check vested shares after 18 months
let monthsElapsed = 18.0 * 30.0 * 24 * 3600  // seconds
let vestedShares = optionGrant.vestedShares(timeElapsed: monthsElapsed)
print("Vested after 18 months: \(vestedShares)")  // ~37,500 shares
```

## Down Rounds and Anti-Dilution

Handle down rounds with anti-dilution protection:

```swift
// Series B at lower valuation than Series A
// Full ratchet protection for Series A investors
let downRound = capTable.modelDownRound(
    newInvestment: 3_000_000,
    newValuation: 6_000_000,  // Down from $10M post-Series A
    protectedShareClass: .preferredA,
    protectionType: .fullRatchet
)

// Series A shares are repriced to match Series B
// This prevents Series A dilution
```

For weighted average protection (more founder-friendly):

```swift
let downRoundWA = capTable.modelDownRound(
    newInvestment: 3_000_000,
    newValuation: 6_000_000,
    protectedShareClass: .preferredA,
    protectionType: .weightedAverage
)

// Partial protection based on amount raised
```

## Liquidation Preferences

Model exit scenarios with preference stacks:

```swift
// Series A: 1x non-participating preferred
capTable.addShareholder(Shareholder(
    name: "VC Fund I",
    shares: 2_000_000,
    pricePerShare: 1.00,
    shareClass: .preferredA,
    liquidationPreference: 1.0,
    participating: false  // Takes preference OR pro-rata, whichever is higher
))

// Series B: 2x participating preferred
capTable.addShareholder(Shareholder(
    name: "VC Fund II",
    shares: 1_500_000,
    pricePerShare: 2.00,
    shareClass: .preferredB,
    liquidationPreference: 2.0,
    participating: true  // Gets preference PLUS pro-rata
))
```

Calculate liquidation waterfall at various exit values:

```swift
// Low exit: $5M (below total invested capital)
let lowExit = capTable.liquidationWaterfall(exitValue: 5_000_000)
for (shareholder, payout) in lowExit {
    print("\(shareholder): $\(payout)")
}
// Series B gets 2x preference first, then Series A gets remainder

// High exit: $50M
let highExit = capTable.liquidationWaterfall(exitValue: 50_000_000)
// Non-participating preferred converts to common
// Participating preferred gets preference + upside
```

## Full Financing Example

Here's a complete multi-round scenario:

```swift
import BusinessMath

// Formation
var capTable = CapTable(companyName: "Startup Inc")

// Founders
capTable.addShareholder(Shareholder(
    name: "Founder 1",
    shares: 6_000_000,
    pricePerShare: 0.001,
    shareClass: .common
))

capTable.addShareholder(Shareholder(
    name: "Founder 2",
    shares: 4_000_000,
    pricePerShare: 0.001,
    shareClass: .common
))

// Pre-seed SAFE: $500K at $5M post-money
let safeTerms = SAFETerm(cap: 5_000_000, discount: nil, type: .postMoney)
let safeConversion = safeTerms.convertToEquity(
    investment: 500_000,
    valuationAtConversion: 5_000_000
)

capTable.addShareholder(Shareholder(
    name: "Pre-seed Fund",
    shares: safeConversion.shares,
    pricePerShare: safeConversion.pricePerShare,
    shareClass: .safe
))

// Seed: $2M at $8M pre-money
let seedRound = capTable.modelFinancingRound(
    investment: 2_000_000,
    preMoneyValuation: 8_000_000,
    investorName: "Seed Fund",
    shareClass: .preferredSeed,
    liquidationPreference: 1.0,
    participating: false
)

// Add 15% option pool post-Seed
let withPool = seedRound.addOptionPool(poolSize: 0.15, timing: .postRound)

// Series A: $10M at $40M pre-money
let seriesA = withPool.modelFinancingRound(
    investment: 10_000_000,
    preMoneyValuation: 40_000_000,
    investorName: "Series A Lead",
    shareClass: .preferredA,
    liquidationPreference: 1.0,
    participating: false
)

// Final cap table summary
print("=== Cap Table Post-Series A ===")
for shareholder in seriesA.shareholders {
    let ownership = seriesA.ownershipPercentage(shareholder: shareholder.name)
    print("\(shareholder.name): \(ownership * 100)% - \(shareholder.shareClass)")
}

// Outstanding vs fully diluted
let outstanding = seriesA.outstandingShares()
let fullyDiluted = seriesA.fullyDilutedShares()
print("\nOutstanding: \(outstanding)")
print("Fully Diluted: \(fullyDiluted)")

// Exit scenario: $100M acquisition
print("\n=== Exit: $100M ===")
let exitProceeds = seriesA.liquidationWaterfall(exitValue: 100_000_000)
for (shareholder, payout) in exitProceeds {
    print("\(shareholder): $\(String(format: "%.2f", payout))")
}
```

## Understanding Ownership Dilution

Track how ownership changes through rounds:

```swift
// Track founder ownership through each round
let founderName = "Founder 1"

let formation = capTable.ownershipPercentage(shareholder: founderName)
let postSeed = seedRound.ownershipPercentage(shareholder: founderName)
let postPool = withPool.ownershipPercentage(shareholder: founderName)
let postSeriesA = seriesA.ownershipPercentage(shareholder: founderName)

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
let preMoneyPool = capTable.addOptionPool(poolSize: 0.15, timing: .preRound)

// Post-money: Pool dilutes everyone including new investor
let postMoneyPool = capTable.addOptionPool(poolSize: 0.15, timing: .postRound)

// Post-money is more founder-friendly (less dilution from pool)
```

### Multiple SAFEs with Different Caps

```swift
// Early SAFE: $100K at $5M cap
let earlySafe = SAFETerm(cap: 5_000_000, discount: nil, type: .postMoney)
let earlySafeConversion = earlySafe.convertToEquity(
    investment: 100_000,
    valuationAtConversion: 10_000_000
)

// Later SAFE: $500K at $8M cap
let laterSafe = SAFETerm(cap: 8_000_000, discount: nil, type: .postMoney)
let laterSafeConversion = laterSafe.convertToEquity(
    investment: 500_000,
    valuationAtConversion: 10_000_000
)

// Early SAFE gets better terms (lower cap = more ownership)
print("Early SAFE ownership: \(earlySafeConversion.ownershipPercentOverride!)")
print("Later SAFE ownership: \(laterSafeConversion.ownershipPercentOverride!)")
```

### 409A Valuations for Option Grants

```swift
// Calculate FMV for common stock options
let preferredPrice = 2.00  // Series A price
let commonFMV = capTable.commonStockFMV(
    preferredPrice: preferredPrice,
    discountFactor: 0.40  // Typical 40% discount
)

print("Strike price for options: $\(commonFMV)")  // ~$0.80
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
