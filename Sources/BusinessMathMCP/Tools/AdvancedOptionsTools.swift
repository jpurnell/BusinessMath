//
//  AdvancedOptionsTools.swift
//  BusinessMath MCP Server
//
//  Advanced option pricing and Greek calculation tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all advanced options tools
public func getAdvancedOptionsTools() -> [any MCPToolHandler] {
    return [
        OptionGreeksTool(),
        BinomialTreeOptionTool()
    ]
}

// MARK: - Helper Functions

/// Format currency
private func formatCurrency(_ value: Double, decimals: Int = 2) -> String {
    let formatted = abs(value).formatDecimal(decimals: decimals)
    return value >= 0 ? "$\(formatted)" : "-$\(formatted)"
}

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 4) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format percentage
private func formatRate(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

// MARK: - Option Greeks

public struct OptionGreeksTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_option_greeks",
        description: """
        Calculate option Greeks (sensitivities) for risk management and hedging.

        Greeks measure how option prices change with respect to various factors:

        • Delta (Δ): Change in option price per $1 change in underlying
          - Call: 0 to 1, Put: -1 to 0
          - Hedge ratio: Delta shares offset 1 option

        • Gamma (Γ): Change in Delta per $1 change in underlying
          - Measures Delta stability
          - Highest near at-the-money

        • Vega (ν): Change in option price per 1% change in volatility
          - All options have positive vega
          - Highest for at-the-money, longer-dated options

        • Theta (Θ): Change in option price per day passing
          - Time decay - usually negative
          - Accelerates as expiration approaches

        • Rho (ρ): Change in option price per 1% change in interest rates
          - Call: positive, Put: negative
          - Usually smallest Greek

        Use Cases:
        • Portfolio hedging (Delta-neutral strategies)
        • Risk management (understanding exposures)
        • Options trading strategies
        • Market making
        • Volatility trading

        Example - At-the-Money Call:
        Stock: $100, Strike: $100, 3 months to expiry
        Delta: ~0.50 (50% chance of finishing in-the-money)
        Gamma: High (Delta changes quickly)
        Vega: High (sensitive to volatility changes)
        Theta: -$0.05/day (loses $0.05 daily to time decay)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "optionType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of option: 'call' or 'put'"
                ),
                "spotPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current price of underlying asset"
                ),
                "strikePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Strike price of the option"
                ),
                "timeToExpiry": MCPSchemaProperty(
                    type: "number",
                    description: "Time to expiration in years (e.g., 0.25 for 3 months)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free interest rate (e.g., 0.05 for 5%)"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Annual volatility of underlying (e.g., 0.30 for 30%)"
                )
            ],
            required: ["optionType", "spotPrice", "strikePrice", "timeToExpiry", "riskFreeRate", "volatility"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let optionTypeStr = try args.getString("optionType")
        let spotPrice = try args.getDouble("spotPrice")
        let strikePrice = try args.getDouble("strikePrice")
        let timeToExpiry = try args.getDouble("timeToExpiry")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")

        // Parse option type
        let optionType: OptionType
        switch optionTypeStr.lowercased() {
        case "call": optionType = .call
        case "put": optionType = .put
        default:
            throw ToolError.invalidArguments("Option type must be 'call' or 'put'")
        }

        // Calculate option price
        let optionPrice = BlackScholesModel<Double>.price(
            optionType: optionType,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        // Calculate Greeks
        let greeks = BlackScholesModel<Double>.greeks(
            optionType: optionType,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        // Calculate moneyness
        let moneyness = spotPrice / strikePrice
        let moneynessDesc: String
        if moneyness > 1.05 {
            moneynessDesc = "In-the-money (ITM)"
        } else if moneyness > 0.95 {
            moneynessDesc = "At-the-money (ATM)"
        } else {
            moneynessDesc = "Out-of-the-money (OTM)"
        }

        // Convert time to days for Theta interpretation
        let daysToExpiry = timeToExpiry * 365.0
        let thetaPerDay = greeks.theta / 365.0

        let output = """
        Option Greeks Analysis

        Option Parameters:
        • Type: \(optionTypeStr.capitalized)
        • Spot Price: \(formatCurrency(spotPrice))
        • Strike Price: \(formatCurrency(strikePrice))
        • Time to Expiry: \(formatNumber(timeToExpiry, decimals: 2)) years (\(formatNumber(daysToExpiry, decimals: 0)) days)
        • Risk-Free Rate: \(formatRate(riskFreeRate))
        • Volatility: \(formatRate(volatility))

        Option Value:
        • Black-Scholes Price: \(formatCurrency(optionPrice))
        • Moneyness: \(moneynessDesc) (Spot/Strike = \(formatNumber(moneyness, decimals: 2)))

        Greeks (Sensitivities):

        Delta (Δ): \(formatNumber(greeks.delta, decimals: 4))
        • Option price changes $\(formatNumber(abs(greeks.delta), decimals: 2)) per $1 move in underlying
        • Hedge ratio: \(formatNumber(abs(greeks.delta) * 100, decimals: 0)) shares per 100 options for Delta-neutral
        • Approximate probability of finishing ITM: \(formatRate(abs(greeks.delta)))
        \(optionType == .call ?
          (greeks.delta > 0.7 ? "• Deep ITM call - high sensitivity, behaves like stock" :
           greeks.delta > 0.3 ? "• Moderate Delta - balanced exposure" :
           "• Low Delta - out-of-the-money, low sensitivity") :
          (greeks.delta < -0.7 ? "• Deep ITM put - high inverse sensitivity" :
           greeks.delta < -0.3 ? "• Moderate Delta - balanced inverse exposure" :
           "• Low Delta put - out-of-the-money"))

        Gamma (Γ): \(formatNumber(greeks.gamma, decimals: 4))
        • Delta changes by \(formatNumber(greeks.gamma, decimals: 4)) per $1 move in underlying
        • \(greeks.gamma > 0.05 ? "High Gamma - Delta very unstable, requires frequent rehedging" :
             greeks.gamma > 0.02 ? "Moderate Gamma - Delta changes moderately" :
             "Low Gamma - Delta relatively stable")
        • Maximum Gamma occurs at-the-money

        Vega (ν): \(formatNumber(greeks.vega, decimals: 4))
        • Option price changes $\(formatNumber(greeks.vega, decimals: 2)) per 1% change in volatility
        • If volatility increases from \(formatRate(volatility)) to \(formatRate(volatility + 0.01)):
          New price ≈ \(formatCurrency(optionPrice + greeks.vega))
        • \(greeks.vega > 0.15 ? "High Vega - very sensitive to volatility changes (good for vol trading)" :
             "Moderate Vega - some volatility sensitivity")

        Theta (Θ): \(formatNumber(greeks.theta, decimals: 4)) per year, \(formatNumber(thetaPerDay, decimals: 4)) per day
        • Option loses approximately $\(formatNumber(abs(thetaPerDay), decimals: 2)) per day to time decay
        • Over next week: ~\(formatCurrency(thetaPerDay * 7))
        • Over next month: ~\(formatCurrency(thetaPerDay * 30))
        • \(abs(thetaPerDay) > 0.05 ? "⚠ High time decay - option losing value quickly" :
             abs(thetaPerDay) > 0.02 ? "Moderate time decay" :
             "Low time decay")
        • Time decay accelerates as expiration approaches

        Rho (ρ): \(formatNumber(greeks.rho, decimals: 4))
        • Option price changes $\(formatNumber(abs(greeks.rho), decimals: 2)) per 1% change in interest rates
        • Usually the least important Greek for short-dated options
        • More relevant for long-dated options (LEAPS)

        Risk Management Insights:

        Delta Hedging:
        • To hedge 100 \(optionTypeStr)s: \(greeks.delta > 0 ? "Sell" : "Buy") \(formatNumber(abs(greeks.delta) * 100, decimals: 0)) shares
        • Portfolio Delta: \(formatNumber(greeks.delta * 100, decimals: 0)) (for 100 options)

        Position Characteristics:
        • \(moneyness > 1.1 ? "Deep ITM - high intrinsic value, low time value" :
             moneyness > 0.9 ? "Near the money - high Gamma and Vega, maximum time value" :
             "OTM - mostly time value, high risk/reward")
        • Time decay impact: \(abs(thetaPerDay * 30) / optionPrice > 0.10 ? "Significant (>10% per month)" : "Moderate")
        • Volatility sensitivity: \(greeks.vega / optionPrice > 0.15 ? "High" : "Moderate")

        Trading Strategy Implications:
        \(optionType == .call ?
          (greeks.delta > 0.5 ? "• Bullish position - benefits from price increases\n• Consider covered call if hedging long stock" :
           "• Speculative call - high leverage, high risk\n• Time decay working against you") :
          (greeks.delta < -0.5 ? "• Bearish/protective position\n• Consider protective put for downside insurance" :
           "• Speculative put - lottery ticket characteristics"))
        • Theta: \(greeks.theta < -0.02 ? "⚠ Time is enemy - consider shorter holding period" : "Time decay manageable")
        • Vega: \(greeks.vega > 0.15 ? "Benefits from volatility increase (long vol position)" : "Less affected by volatility changes")
        """

        return .success(text: output)
    }
}

// MARK: - Binomial Tree Option

public struct BinomialTreeOptionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_binomial_tree_option",
        description: """
        Price options using binomial tree model (supports American & European options).

        The binomial tree model prices options by building a lattice of possible
        future stock prices and working backwards to determine the option value.

        Advantages over Black-Scholes:
        • Handles American options (early exercise)
        • More intuitive discrete-time framework
        • Can incorporate dividends
        • Flexible for exotic options

        American vs European:
        • European: Exercise only at expiration
        • American: Can exercise anytime before expiration
        • American options ≥ European options (early exercise value)
        • Puts benefit more from early exercise than calls

        Use Cases:
        • American option pricing (Black-Scholes can't handle)
        • Dividend-paying stocks
        • Understanding option mechanics
        • Verifying Black-Scholes results
        • Teaching/learning options

        Example - American Put:
        Stock: $100, Strike: $105, 1 year, Deep ITM
        European Put: $6.50
        American Put: $7.20 (early exercise premium)
        Premium for early exercise right: $0.70

        More steps = more accurate pricing (converges to Black-Scholes).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "optionType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of option: 'call' or 'put'"
                ),
                "americanStyle": MCPSchemaProperty(
                    type: "boolean",
                    description: "True for American (early exercise), False for European (expiration only)"
                ),
                "spotPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current price of underlying asset"
                ),
                "strikePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Strike price of the option"
                ),
                "timeToExpiry": MCPSchemaProperty(
                    type: "number",
                    description: "Time to expiration in years"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free interest rate"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Annual volatility of underlying"
                ),
                "steps": MCPSchemaProperty(
                    type: "number",
                    description: "Number of time steps in binomial tree (default: 100, more steps = more accurate)"
                )
            ],
            required: ["optionType", "americanStyle", "spotPrice", "strikePrice", "timeToExpiry", "riskFreeRate", "volatility"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let optionTypeStr = try args.getString("optionType")
        let americanStyle = try args.getBool("americanStyle")
        let spotPrice = try args.getDouble("spotPrice")
        let strikePrice = try args.getDouble("strikePrice")
        let timeToExpiry = try args.getDouble("timeToExpiry")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")
        let steps = args.getIntOptional("steps") ?? 100

        // Validate steps
        guard steps >= 10 && steps <= 1000 else {
            throw ToolError.invalidArguments("Steps must be between 10 and 1000")
        }

        // Parse option type
        let optionType: OptionType
        switch optionTypeStr.lowercased() {
        case "call": optionType = .call
        case "put": optionType = .put
        default:
            throw ToolError.invalidArguments("Option type must be 'call' or 'put'")
        }

        // Calculate binomial tree price
        let binomialPrice = BinomialTreeModel<Double>.price(
            optionType: optionType,
            americanStyle: americanStyle,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            steps: steps
        )

        // Calculate Black-Scholes price for comparison (European)
        let blackScholesPrice = BlackScholesModel<Double>.price(
            optionType: optionType,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        // Calculate intrinsic value
        let intrinsicValue: Double
        switch optionType {
        case .call:
            intrinsicValue = max(0, spotPrice - strikePrice)
        case .put:
            intrinsicValue = max(0, strikePrice - spotPrice)
        }

        let timeValue = binomialPrice - intrinsicValue

        // Calculate moneyness
        let moneyness = spotPrice / strikePrice
        let moneynessDesc: String
        if optionType == .call {
            moneynessDesc = moneyness > 1.05 ? "In-the-money" : moneyness > 0.95 ? "At-the-money" : "Out-of-the-money"
        } else {
            moneynessDesc = moneyness < 0.95 ? "In-the-money" : moneyness < 1.05 ? "At-the-money" : "Out-of-the-money"
        }

        // Early exercise premium for American options
        let earlyExercisePremium = americanStyle ? (binomialPrice - blackScholesPrice) : 0.0

        let output = """
        Binomial Tree Option Pricing

        Option Parameters:
        • Type: \(optionTypeStr.capitalized)
        • Style: \(americanStyle ? "American (early exercise allowed)" : "European (expiration only)")
        • Spot Price: \(formatCurrency(spotPrice))
        • Strike Price: \(formatCurrency(strikePrice))
        • Time to Expiry: \(formatNumber(timeToExpiry, decimals: 2)) years (\(formatNumber(timeToExpiry * 365, decimals: 0)) days)
        • Risk-Free Rate: \(formatRate(riskFreeRate))
        • Volatility: \(formatRate(volatility))
        • Tree Steps: \(steps)

        Pricing Results:

        Binomial Tree Price: \(formatCurrency(binomialPrice))
        • This is the fair value of the \(americanStyle ? "American" : "European") \(optionTypeStr)

        Value Components:
        • Intrinsic Value: \(formatCurrency(intrinsicValue))
          \(intrinsicValue > 0 ? "→ \(moneynessDesc) by \(formatCurrency(abs(spotPrice - strikePrice)))" : "→ Currently worthless if exercised")
        • Time Value: \(formatCurrency(timeValue))
          \(timeValue > 0 ? "→ Premium for uncertainty and time remaining" : "→ No time value remaining")
        • Moneyness: \(moneynessDesc) (S/K = \(formatNumber(moneyness, decimals: 2)))

        Comparison with Black-Scholes:
        • Black-Scholes (European): \(formatCurrency(blackScholesPrice))
        • Binomial Tree (\(americanStyle ? "American" : "European")): \(formatCurrency(binomialPrice))
        • Difference: \(formatCurrency(abs(binomialPrice - blackScholesPrice)))
        \(americanStyle ? """
        • Early Exercise Premium: \(formatCurrency(earlyExercisePremium))
        \(earlyExercisePremium > 0.10 ?
          "  → Significant value from early exercise right (\(formatRate(earlyExercisePremium / binomialPrice)) of total)" :
          earlyExercisePremium > 0.01 ?
          "  → Modest early exercise value" :
          "  → Minimal benefit from early exercise")
        """ : """
        • Binomial converges to Black-Scholes for European options
        • Difference due to discrete vs continuous time modeling
        """)

        Analysis:

        Option Characteristics:
        • \(intrinsicValue > 0 ? "Has \(formatCurrency(intrinsicValue)) intrinsic value" : "No intrinsic value (out-of-the-money)")
        • Time value represents \(formatRate(timeValue / binomialPrice)) of total price
        • \(timeToExpiry > 1.0 ? "Long-dated option - high time value" :
             timeToExpiry > 0.25 ? "Medium-term option" :
             "Short-dated option - time decay accelerating")

        \(americanStyle ? """

        Early Exercise Considerations:
        \(optionType == .call ? """
        • Call options rarely optimal to exercise early (unless dividends)
        • Better to sell the option than exercise (preserve time value)
        • Early exercise only for deep ITM calls near ex-dividend date
        """ : """
        • Put options may benefit from early exercise when deep ITM
        • Especially when interest earned > time value lost
        • Deep ITM puts (\(moneyness < 0.8 ? "✓ Like this one" : "✗ Not this one")) are candidates
        \(intrinsicValue > timeValue ? "• ⚠ Intrinsic > Time value - early exercise may be optimal" : "• Time value still significant - hold option")
        """)
        """ : "")

        Trading Implications:
        • Fair Value: \(formatCurrency(binomialPrice))
        • \(binomialPrice > intrinsicValue + 0.50 ? "Premium option - high time value component" :
             "Mostly intrinsic value - behaves more like underlying")
        • Risk/Reward: Max loss = \(formatCurrency(binomialPrice)), Max gain = \(optionType == .call ? "Unlimited" : formatCurrency(strikePrice))

        Model Accuracy:
        • \(steps) steps used (more steps = more accurate)
        • Binomial model good for: American options, dividends, early exercise analysis
        • Converges to Black-Scholes as steps → ∞
        """

        return .success(text: output)
    }
}
