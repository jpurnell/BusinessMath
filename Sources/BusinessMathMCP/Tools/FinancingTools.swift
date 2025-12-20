//
//  FinancingTools.swift
//  BusinessMath MCP Server
//
//  Equity financing and venture capital tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}


// MARK: - Post-Money Valuation

public struct PostMoneyValuationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_post_money_valuation",
        description: """
        Calculate post-money valuation after a financing round.

        Post-money valuation is the company's value immediately after receiving investment.

        Formula: Post-Money Valuation = Pre-Money Valuation + Investment Amount

        Alternatively: Post-Money Valuation = Investment Amount / Ownership Percentage

        Use Cases:
        • Venture capital financing
        • Startup funding rounds
        • Equity raise planning
        • Cap table management

        Example: $10M pre-money + $2M investment = $12M post-money valuation
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "preMoneyValuation": MCPSchemaProperty(
                    type: "number",
                    description: "Pre-money valuation (company value before investment)"
                ),
                "investmentAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Amount of new investment"
                )
            ],
            required: ["preMoneyValuation", "investmentAmount"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let preMoney = try args.getDouble("preMoneyValuation")
        let investment = try args.getDouble("investmentAmount")

        let postMoney = preMoney + investment
        let newInvestorOwnership = investment / postMoney
        let existingOwnership = preMoney / postMoney

        let output = """
        Post-Money Valuation Analysis:

        Inputs:
        • Pre-Money Valuation: $\(formatNumber(preMoney, decimals: 0))
        • Investment Amount: $\(formatNumber(investment, decimals: 0))

        Result:
        • Post-Money Valuation: $\(formatNumber(postMoney, decimals: 0))

        Ownership Structure:
        • New Investor Ownership: \(newInvestorOwnership.percent())
        • Existing Shareholders: \(existingOwnership.percent())

        Price Per Share:
        Calculate as Post-Money Valuation / Total Shares Outstanding (post-investment)
        """

        return .success(text: output)
    }
}

// MARK: - Dilution Calculation

public struct DilutionCalculationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_dilution_percentage",
        description: """
        Calculate shareholder dilution from new financing.

        Dilution measures the reduction in existing shareholders' ownership percentage
        when new shares are issued to investors.

        Formula: Dilution = (New Shares / Total Shares After) × 100%

        Interpretation:
        • Higher dilution = Greater ownership reduction
        • Trade-off between capital raised and control
        • Important for founder and employee equity planning

        Use Cases:
        • Fundraising planning
        • Employee stock option pool creation
        • Cap table modeling
        • Negotiating investment terms

        Example: 1M new shares, 4M existing = 20% dilution to existing shareholders
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "existingShares": MCPSchemaProperty(
                    type: "number",
                    description: "Number of shares outstanding before new issuance"
                ),
                "newShares": MCPSchemaProperty(
                    type: "number",
                    description: "Number of new shares to be issued"
                )
            ],
            required: ["existingShares", "newShares"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let existingShares = try args.getDouble("existingShares")
        let newShares = try args.getDouble("newShares")

        let totalSharesAfter = existingShares + newShares
        let dilutionPercent = newShares / totalSharesAfter
        let ownershipAfter = existingShares / totalSharesAfter

        let output = """
        Dilution Analysis:

        Share Structure:
        • Existing Shares: \(formatNumber(existingShares, decimals: 0))
        • New Shares Issued: \(formatNumber(newShares, decimals: 0))
        • Total Shares After: \(formatNumber(totalSharesAfter, decimals: 0))

        Dilution Impact:
        • Dilution Percentage: \(dilutionPercent.percent())
        • Existing Shareholders' New Ownership: \(ownershipAfter.percent())
        • New Investors' Ownership: \(dilutionPercent.percent())

        Example:
        If a founder owned 100% before (\(formatNumber(existingShares, decimals: 0)) shares),
        they now own \(ownershipAfter.percent()) after the new issuance.
        """

        return .success(text: output)
    }
}

// MARK: - SAFE Conversion Modeling

public struct SAFEConversionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "model_safe_conversion",
        description: """
        Model the conversion of a SAFE (Simple Agreement for Future Equity) into equity.

        SAFEs convert to equity at a future priced round, typically with a valuation cap
        and/or discount rate that benefits early investors.

        Conversion Formula:
        • With Cap: Shares = Investment / min(Cap Valuation, Discount Price)
        • Discount applied to next round price per share

        Use Cases:
        • Seed funding planning
        • Cap table modeling
        • Understanding investor returns
        • Priced round preparation

        Example: $100K SAFE with $5M cap converts at $10M Series A
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "safeAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Total SAFE investment amount"
                ),
                "valuationCap": MCPSchemaProperty(
                    type: "number",
                    description: "Valuation cap on the SAFE"
                ),
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Discount rate (e.g., 0.20 for 20% discount)"
                ),
                "pricedRoundValuation": MCPSchemaProperty(
                    type: "number",
                    description: "Post-money valuation of the priced round"
                ),
                "pricedRoundPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Price per share in the priced round"
                )
            ],
            required: ["safeAmount", "valuationCap", "discountRate", "pricedRoundValuation", "pricedRoundPrice"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let safeAmount = try args.getDouble("safeAmount")
        let cap = try args.getDouble("valuationCap")
        let discount = try args.getDouble("discountRate")
        let pricedValuation = try args.getDouble("pricedRoundValuation")
        let pricedPrice = try args.getDouble("pricedRoundPrice")

        // Calculate conversion price using cap
        let capPrice = cap / pricedValuation * pricedPrice

        // Calculate conversion price using discount
        let discountPrice = pricedPrice * (1 - discount)

        // SAFE holder gets the better deal (lower price = more shares)
        let conversionPrice = min(capPrice, discountPrice)

        // Calculate shares received
        let sharesReceived = safeAmount / conversionPrice

        // Calculate effective ownership
        let safeOwnership = "Calculate as shares / total shares post-conversion"

        // Determine which term was used
        let termUsed = conversionPrice == capPrice ? "Valuation Cap" : "Discount Rate"

        let output = """
        SAFE Conversion Analysis:

        SAFE Terms:
        • Investment Amount: $\(formatNumber(safeAmount, decimals: 0))
        • Valuation Cap: $\(formatNumber(cap, decimals: 0))
        • Discount Rate: \(discount.percent())

        Priced Round Terms:
        • Post-Money Valuation: $\(formatNumber(pricedValuation, decimals: 0))
        • Price Per Share: $\(formatNumber(pricedPrice, decimals: 2))

        Conversion Analysis:
        • Conversion Price (using cap): $\(formatNumber(capPrice, decimals: 2))
        • Conversion Price (using discount): $\(formatNumber(discountPrice, decimals: 2))
        • Actual Conversion Price: $\(formatNumber(conversionPrice, decimals: 2))
        • Term Used: \(termUsed) (more favorable)

        Result:
        • Shares Received: \(formatNumber(sharesReceived, decimals: 0))
        • Effective Price Per Share: $\(formatNumber(conversionPrice, decimals: 2))
        • Discount to Priced Round: \(((pricedPrice - conversionPrice) / pricedPrice).percent())

        Note: \(safeOwnership)
        """

        return .success(text: output)
    }
}

// MARK: - Liquidation Waterfall

public struct LiquidationWaterfallTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_liquidation_waterfall",
        description: """
        Analyze capital distribution in a liquidation or exit event.

        Liquidation waterfall shows how proceeds are distributed among different
        classes of shareholders based on liquidation preferences and participation rights.

        Distribution Order:
        1. Debt holders (if any)
        2. Preferred shareholders (with liquidation preference)
        3. Common shareholders
        4. Participating preferred (if applicable)

        Use Cases:
        • M&A scenario modeling
        • Understanding investor protections
        • Exit planning
        • Term sheet negotiations

        Example: $20M exit with $10M Series A (1x preference) and common shares
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "exitProceeds": MCPSchemaProperty(
                    type: "number",
                    description: "Total proceeds from liquidation/exit"
                ),
                "preferredInvestment": MCPSchemaProperty(
                    type: "number",
                    description: "Total preferred stock investment amount"
                ),
                "liquidationMultiple": MCPSchemaProperty(
                    type: "number",
                    description: "Liquidation preference multiple (typically 1x)"
                ),
                "participating": MCPSchemaProperty(
                    type: "boolean",
                    description: "Whether preferred has participation rights"
                ),
                "commonOwnership": MCPSchemaProperty(
                    type: "number",
                    description: "Common shareholders' ownership percentage as decimal"
                ),
                "preferredOwnership": MCPSchemaProperty(
                    type: "number",
                    description: "Preferred shareholders' ownership percentage as decimal"
                )
            ],
            required: ["exitProceeds", "preferredInvestment", "liquidationMultiple", "participating", "commonOwnership", "preferredOwnership"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let proceeds = try args.getDouble("exitProceeds")
        let preferredInv = try args.getDouble("preferredInvestment")
        let multiple = try args.getDouble("liquidationMultiple")
        let participating = try args.getBool("participating")
        let commonOwn = try args.getDouble("commonOwnership")
        let preferredOwn = try args.getDouble("preferredOwnership")

        // Calculate liquidation preference amount
        let liquidationPref = preferredInv * multiple

        var preferredPayout: Double
        var commonPayout: Double

        if participating {
            // Participating preferred: gets preference + pro-rata share
            preferredPayout = min(liquidationPref, proceeds)
            let remainingProceeds = max(0, proceeds - liquidationPref)

            let proRataPreferred = remainingProceeds * preferredOwn
            let proRataCommon = remainingProceeds * commonOwn

            preferredPayout += proRataPreferred
            commonPayout = proRataCommon
        } else {
            // Non-participating: choose better of preference or pro-rata
            let preferredAsIfConverted = proceeds * preferredOwn
            let commonAsIfConverted = proceeds * commonOwn

            if liquidationPref > preferredAsIfConverted {
                // Take liquidation preference
                preferredPayout = min(liquidationPref, proceeds)
                commonPayout = max(0, proceeds - liquidationPref)
            } else {
                // Convert and take pro-rata
                preferredPayout = preferredAsIfConverted
                commonPayout = commonAsIfConverted
            }
        }

        let preferredReturn = preferredInv > 0 ? preferredPayout / preferredInv : 0
        let participationType = participating ? "Participating" : "Non-Participating"

        let output = """
        Liquidation Waterfall Analysis:

        Exit Scenario:
        • Total Proceeds: $\(formatNumber(proceeds, decimals: 0))

        Preferred Terms:
        • Investment: $\(formatNumber(preferredInv, decimals: 0))
        • Liquidation Preference: \(formatNumber(multiple, decimals: 1))x
        • Preference Amount: $\(formatNumber(liquidationPref, decimals: 0))
        • Type: \(participationType)

        Ownership:
        • Preferred Ownership: \(preferredOwn.percent())
        • Common Ownership: \(commonOwn.percent())

        Distribution:
        • To Preferred Shareholders: $\(formatNumber(preferredPayout, decimals: 0)) (\((preferredPayout / proceeds).percent()))
        • To Common Shareholders: $\(formatNumber(commonPayout, decimals: 0)) (\((commonPayout / proceeds).percent()))

        Return Analysis:
        • Preferred Multiple on Invested Capital: \(formatNumber(preferredReturn, decimals: 2))x

        Total Distributed: $\(formatNumber(preferredPayout + commonPayout, decimals: 0))
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns all equity financing tools
public func getFinancingTools() -> [any MCPToolHandler] {
    return [
        PostMoneyValuationTool(),
        DilutionCalculationTool(),
        SAFEConversionTool(),
        LiquidationWaterfallTool()
    ]
}
