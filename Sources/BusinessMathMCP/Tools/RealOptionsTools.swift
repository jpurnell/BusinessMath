import Foundation
import MCP
import BusinessMath

// MARK: - Black-Scholes Option Pricing Tool

public struct BlackScholesOptionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "price_black_scholes_option",
        description: """
        Price European options using the Black-Scholes-Merton model. Perfect for valuing call and put options that can only be exercised at expiration.

        Example: Price a call option
        - optionType: "call"
        - spotPrice: 100 (current stock price)
        - strikePrice: 105 (exercise price)
        - timeToExpiry: 0.5 (6 months)
        - riskFreeRate: 0.05 (5% annual)
        - volatility: 0.30 (30% annual)

        Returns option price and interpretation.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "optionType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of option",
                    enum: ["call", "put"]
                ),
                "spotPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current price of underlying asset"
                ),
                "strikePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Exercise/strike price"
                ),
                "timeToExpiry": MCPSchemaProperty(
                    type: "number",
                    description: "Time to expiration in years (e.g., 0.5 for 6 months)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free interest rate as decimal (e.g., 0.05 for 5%)"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Annual volatility as decimal (e.g., 0.30 for 30%)"
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

        let optionTypeString = try args.getString("optionType")
        let optionType: OptionType = optionTypeString == "call" ? .call : .put
        let spotPrice = try args.getDouble("spotPrice")
        let strikePrice = try args.getDouble("strikePrice")
        let timeToExpiry = try args.getDouble("timeToExpiry")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")

        // Calculate option price
        let price = BlackScholesModel<Double>.price(
            optionType: optionType,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        // Calculate intrinsic and time value
        let intrinsicValue: Double
        if optionType == .call {
            intrinsicValue = max(0, spotPrice - strikePrice)
        } else {
            intrinsicValue = max(0, strikePrice - spotPrice)
        }
        let timeValue = price - intrinsicValue

        let moneyness: String
        if optionType == .call {
            if spotPrice > strikePrice {
                moneyness = "In-the-Money (ITM)"
            } else if spotPrice < strikePrice {
                moneyness = "Out-of-the-Money (OTM)"
            } else {
                moneyness = "At-the-Money (ATM)"
            }
        } else {
            if spotPrice < strikePrice {
                moneyness = "In-the-Money (ITM)"
            } else if spotPrice > strikePrice {
                moneyness = "Out-of-the-Money (OTM)"
            } else {
                moneyness = "At-the-Money (ATM)"
            }
        }

        let result = """
        Black-Scholes Option Pricing

        Option Details:
        - Type: \(optionType == .call ? "Call" : "Put") (\(moneyness))
        - Spot Price: $\(String(format: "%.2f", spotPrice))
        - Strike Price: $\(String(format: "%.2f", strikePrice))
        - Time to Expiry: \(String(format: "%.2f", timeToExpiry)) years
        - Risk-Free Rate: \(String(format: "%.1f%%", riskFreeRate * 100))
        - Volatility: \(String(format: "%.1f%%", volatility * 100))

        Option Value: $\(String(format: "%.2f", price))

        Value Breakdown:
        - Intrinsic Value: $\(String(format: "%.2f", intrinsicValue))
        - Time Value: $\(String(format: "%.2f", timeValue))

        Interpretation:
        \(optionType == .call ?
          "Call option gives the right to BUY at $\(String(format: "%.2f", strikePrice))" :
          "Put option gives the right to SELL at $\(String(format: "%.2f", strikePrice))")
        Current profit if exercised: $\(String(format: "%.2f", intrinsicValue))
        Premium for waiting/flexibility: $\(String(format: "%.2f", timeValue))

        Note: This is for European options (exercisable only at expiration).
        For American options (exercisable anytime), use binomial tree model.
        """

        return .success(text: result)
    }
}

// MARK: - Option Greeks Calculator Tool

public struct CalculateGreeksTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_option_greeks",
        description: """
        Calculate option Greeks (Delta, Gamma, Vega, Theta, Rho) for sensitivity analysis. Greeks measure how option prices change with market conditions.

        Example:
        - optionType: "call"
        - spotPrice: 100
        - strikePrice: 105
        - timeToExpiry: 0.5
        - riskFreeRate: 0.05
        - volatility: 0.30

        Returns all five Greeks with interpretations.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "optionType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of option",
                    enum: ["call", "put"]
                ),
                "spotPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current price of underlying asset"
                ),
                "strikePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Exercise/strike price"
                ),
                "timeToExpiry": MCPSchemaProperty(
                    type: "number",
                    description: "Time to expiration in years"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free rate as decimal"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Annual volatility as decimal"
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

        let optionTypeString = try args.getString("optionType")
        let optionType: OptionType = optionTypeString == "call" ? .call : .put
        let spotPrice = try args.getDouble("spotPrice")
        let strikePrice = try args.getDouble("strikePrice")
        let timeToExpiry = try args.getDouble("timeToExpiry")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")

        // Calculate Greeks
        let greeks = BlackScholesModel<Double>.greeks(
            optionType: optionType,
            spotPrice: spotPrice,
            strikePrice: strikePrice,
            timeToExpiry: timeToExpiry,
            riskFreeRate: riskFreeRate,
            volatility: volatility
        )

        let result = """
        Option Greeks for \(optionType == .call ? "Call" : "Put") Option

        Greek Values:
        • Delta: \(String(format: "%.4f", greeks.delta))
        • Gamma: \(String(format: "%.4f", greeks.gamma))
        • Vega: \(String(format: "%.4f", greeks.vega))
        • Theta: \(String(format: "%.4f", greeks.theta))
        • Rho: \(String(format: "%.4f", greeks.rho))

        Interpretations:

        Delta (\(String(format: "%.4f", greeks.delta))):
        If underlying rises $1, option price changes by $\(String(format: "%.4f", greeks.delta))
        Range: 0 to 1 for calls, -1 to 0 for puts
        Hedge ratio: Buy \(String(format: "%.0f", abs(greeks.delta) * 100)) shares per 100 option contracts

        Gamma (\(String(format: "%.4f", greeks.gamma))):
        Delta sensitivity to $1 price change
        Higher gamma = delta changes faster = more risk/opportunity
        Highest at-the-money, approaches 0 deep ITM/OTM

        Vega (\(String(format: "%.4f", greeks.vega))):
        If volatility rises 1%, option price changes by $\(String(format: "%.4f", greeks.vega * 0.01))
        All options benefit from increased volatility (positive vega)
        Highest at-the-money, with more time to expiration

        Theta (\(String(format: "%.4f", greeks.theta))):
        Daily time decay: $\(String(format: "%.4f", greeks.theta / 365)) per day
        \(greeks.theta < 0 ? "Losing" : "Gaining") value as time passes
        Accelerates as expiration approaches

        Rho (\(String(format: "%.4f", greeks.rho))):
        If risk-free rate rises 1%, option price changes by $\(String(format: "%.4f", greeks.rho * 0.01))
        Usually least important Greek for short-dated options

        Risk Management:
        - Delta hedge: Need \(String(format: "%.0f", abs(greeks.delta * 100))) shares opposite position
        - Gamma risk: Delta will change by \(String(format: "%.4f", greeks.gamma)) per $1 move
        - Theta decay: Losing $\(String(format: "%.2f", abs(greeks.theta / 365))) per day
        """

        return .success(text: result)
    }
}

// MARK: - Binomial Tree Option Pricing Tool

public struct BinomialTreeOptionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "price_binomial_option",
        description: """
        Price American or European options using binomial tree model. American options can be exercised early, making them more valuable than European options.

        Example: Price American put with early exercise
        - optionType: "put"
        - americanStyle: true
        - spotPrice: 100
        - strikePrice: 110 (in-the-money put)
        - timeToExpiry: 1.0
        - riskFreeRate: 0.05
        - volatility: 0.25
        - steps: 100

        Returns option price and early exercise premium.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "optionType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of option",
                    enum: ["call", "put"]
                ),
                "americanStyle": MCPSchemaProperty(
                    type: "boolean",
                    description: "true for American (early exercise allowed), false for European"
                ),
                "spotPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current price of underlying asset"
                ),
                "strikePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Exercise/strike price"
                ),
                "timeToExpiry": MCPSchemaProperty(
                    type: "number",
                    description: "Time to expiration in years"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free rate as decimal"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Annual volatility as decimal"
                ),
                "steps": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of time steps in the tree (default: 100, more = more accurate)"
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

        let optionTypeString = try args.getString("optionType")
        let optionType: OptionType = optionTypeString == "call" ? .call : .put
        let americanStyle = try args.getBool("americanStyle")
        let spotPrice = try args.getDouble("spotPrice")
        let strikePrice = try args.getDouble("strikePrice")
        let timeToExpiry = try args.getDouble("timeToExpiry")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")
        let steps = args.getIntOptional("steps") ?? 100

        // Calculate binomial price
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

        var result = """
        Binomial Tree Option Pricing

        Option Details:
        - Type: \(optionType == .call ? "Call" : "Put")
        - Style: \(americanStyle ? "American" : "European")
        - Spot Price: $\(String(format: "%.2f", spotPrice))
        - Strike Price: $\(String(format: "%.2f", strikePrice))
        - Time to Expiry: \(String(format: "%.2f", timeToExpiry)) years
        - Risk-Free Rate: \(String(format: "%.1f%%", riskFreeRate * 100))
        - Volatility: \(String(format: "%.1f%%", volatility * 100))
        - Tree Steps: \(steps)

        Option Value: $\(String(format: "%.4f", binomialPrice))
        """

        if americanStyle {
            // Also calculate European price for comparison
            let europeanPrice = BinomialTreeModel<Double>.price(
                optionType: optionType,
                americanStyle: false,
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility,
                steps: steps
            )

            let earlyExercisePremium = binomialPrice - europeanPrice

            result += """


            Early Exercise Value:
            - European Value: $\(String(format: "%.4f", europeanPrice))
            - American Value: $\(String(format: "%.4f", binomialPrice))
            - Early Exercise Premium: $\(String(format: "%.4f", earlyExercisePremium))

            The American option is worth \(String(format: "%.2f%%", (earlyExercisePremium / europeanPrice) * 100)) more
            due to the flexibility to exercise early.
            """
        }

        // Compare to Black-Scholes for European
        if !americanStyle {
            let blackScholesPrice = BlackScholesModel<Double>.price(
                optionType: optionType,
                spotPrice: spotPrice,
                strikePrice: strikePrice,
                timeToExpiry: timeToExpiry,
                riskFreeRate: riskFreeRate,
                volatility: volatility
            )

            let difference = abs(binomialPrice - blackScholesPrice)
            let percentDiff = (difference / blackScholesPrice) * 100

            result += """


            Comparison to Black-Scholes:
            - Binomial: $\(String(format: "%.4f", binomialPrice))
            - Black-Scholes: $\(String(format: "%.4f", blackScholesPrice))
            - Difference: $\(String(format: "%.4f", difference)) (\(String(format: "%.2f%%", percentDiff)))

            Binomial tree converges to Black-Scholes as steps increase.
            """
        }

        result += """


        Method Notes:
        - Binomial tree: Discrete-time lattice model
        - \(steps) steps means \(steps) decision points
        - More steps = more accurate but slower
        - American options use backward induction to check early exercise
        """

        return .success(text: result)
    }
}

// MARK: - Real Options Expansion Tool

public struct RealOptionsExpansionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_expansion_option",
        description: """
        Value a strategic expansion option as a call option on growth opportunities. Captures the value of flexibility to expand into new markets or products.

        Example: Software company expansion option
        - baseNPV: 10000000 (current business NPV)
        - expansionCost: 5000000 (cost to expand)
        - expansionNPV: 8000000 (NPV of new market)
        - volatility: 0.35 (35% uncertainty)
        - timeToDecision: 2.0 (2 years to decide)
        - riskFreeRate: 0.05

        Returns total project value including option value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "baseNPV": MCPSchemaProperty(
                    type: "number",
                    description: "NPV of current/base business"
                ),
                "expansionCost": MCPSchemaProperty(
                    type: "number",
                    description: "Cost to execute expansion"
                ),
                "expansionNPV": MCPSchemaProperty(
                    type: "number",
                    description: "NPV of expansion opportunity"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Volatility/uncertainty of expansion value"
                ),
                "timeToDecision": MCPSchemaProperty(
                    type: "number",
                    description: "Years until expansion decision must be made"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free rate"
                )
            ],
            required: ["baseNPV", "expansionCost", "expansionNPV", "volatility", "timeToDecision", "riskFreeRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let baseNPV = try args.getDouble("baseNPV")
        let expansionCost = try args.getDouble("expansionCost")
        let expansionNPV = try args.getDouble("expansionNPV")
        let volatility = try args.getDouble("volatility")
        let timeToDecision = try args.getDouble("timeToDecision")
        let riskFreeRate = try args.getDouble("riskFreeRate")

        // Calculate project value with expansion option
        let projectValue = RealOptionsAnalysis<Double>.expansionOption(
            baseNPV: baseNPV,
            expansionCost: expansionCost,
            expansionNPV: expansionNPV,
            volatility: volatility,
            timeToDecision: timeToDecision,
            riskFreeRate: riskFreeRate
        )

        let optionValue = projectValue - baseNPV
        let traditionalNPV = baseNPV + max(0, expansionNPV - expansionCost)
        let valueMissed = projectValue - traditionalNPV

        let result = """
        Expansion Option Valuation

        Project Components:
        - Base Business NPV: $\(String(format: "%.0f", baseNPV))
        - Expansion Cost: $\(String(format: "%.0f", expansionCost))
        - Expansion NPV (if successful): $\(String(format: "%.0f", expansionNPV))
        - Uncertainty (volatility): \(String(format: "%.0f%%", volatility * 100))
        - Time to Decision: \(String(format: "%.1f", timeToDecision)) years

        Valuation Results:
        - Expansion Option Value: $\(String(format: "%.0f", optionValue))
        - Total Project Value: $\(String(format: "%.0f", projectValue))

        Comparison to Traditional NPV:
        - Traditional NPV: $\(String(format: "%.0f", traditionalNPV))
        - Real Options Value: $\(String(format: "%.0f", projectValue))
        - Value of Flexibility: $\(String(format: "%.0f", valueMissed))

        Interpretation:
        The option to expand is worth $\(String(format: "%.0f", optionValue)), which is
        \(String(format: "%.1f%%", (optionValue / baseNPV) * 100)) of the base business value.

        Traditional NPV analysis would \(valueMissed > 0 ? "undervalue" : "properly value")
        this project by $\(String(format: "%.0f", abs(valueMissed))).

        Key Insight: You're paying for the RIGHT to expand, not the obligation.
        If market conditions turn unfavorable, you can choose not to expand,
        limiting downside while preserving upside potential.

        Option Value Drivers:
        • Higher volatility → Higher option value (more upside potential)
        • More time → Higher option value (more time to learn)
        • Higher expansion NPV → Higher option value (bigger opportunity)
        """

        return .success(text: result)
    }
}

// MARK: - Real Options Abandonment Tool

public struct RealOptionsAbandonmentTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_abandonment_option",
        description: """
        Value an abandonment option as a put option providing downside protection. Captures the value of being able to exit a project if conditions deteriorate.

        Example: Manufacturing project with equipment resale
        - projectNPV: 5000000 (NPV if continued)
        - salvageValue: 3000000 (equipment resale value)
        - volatility: 0.40 (high project uncertainty)
        - timeToDecision: 1.0 (decide after 1 year)
        - riskFreeRate: 0.05

        Returns value with abandonment option included.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "projectNPV": MCPSchemaProperty(
                    type: "number",
                    description: "NPV if project is continued"
                ),
                "salvageValue": MCPSchemaProperty(
                    type: "number",
                    description: "Value if project is abandoned (resale, salvage)"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Volatility/uncertainty of project value"
                ),
                "timeToDecision": MCPSchemaProperty(
                    type: "number",
                    description: "Years until abandonment decision point"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual risk-free rate"
                )
            ],
            required: ["projectNPV", "salvageValue", "volatility", "timeToDecision", "riskFreeRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let projectNPV = try args.getDouble("projectNPV")
        let salvageValue = try args.getDouble("salvageValue")
        let volatility = try args.getDouble("volatility")
        let timeToDecision = try args.getDouble("timeToDecision")
        let riskFreeRate = try args.getDouble("riskFreeRate")

        // Calculate value with abandonment option
        let valueWithOption = RealOptionsAnalysis<Double>.abandonmentOption(
            projectNPV: projectNPV,
            salvageValue: salvageValue,
            volatility: volatility,
            timeToDecision: timeToDecision,
            riskFreeRate: riskFreeRate
        )

        let optionValue = valueWithOption - projectNPV

        let result = """
        Abandonment Option Valuation

        Project Details:
        - Project NPV (if continued): $\(String(format: "%.0f", projectNPV))
        - Salvage Value (if abandoned): $\(String(format: "%.0f", salvageValue))
        - Uncertainty (volatility): \(String(format: "%.0f%%", volatility * 100))
        - Decision Point: \(String(format: "%.1f", timeToDecision)) years

        Valuation Results:
        - Abandonment Option Value: $\(String(format: "%.0f", optionValue))
        - Total Value with Option: $\(String(format: "%.0f", valueWithOption))
        - Value Increase: \(String(format: "%.1f%%", (optionValue / projectNPV) * 100))

        Interpretation:
        The safety net of being able to abandon adds $\(String(format: "%.0f", optionValue))
        in value, which is \(String(format: "%.1f%%", (optionValue / projectNPV) * 100)) of the
        base project value.

        Strategic Implications:
        • This is a "put option" on the project
        • If conditions worsen, you can walk away with $\(String(format: "%.0f", salvageValue))
        • Limits downside while keeping upside
        • More valuable with higher uncertainty

        Decision Rule:
        After \(String(format: "%.1f", timeToDecision)) years, abandon if:
        - Project value falls below $\(String(format: "%.0f", salvageValue))
        - Market conditions have deteriorated significantly
        - Better opportunities have emerged

        Option Value Drivers:
        • Higher volatility → Higher put value (more downside protection needed)
        • Higher salvage value → Higher put value (better safety net)
        • More time → Higher put value (more uncertainty to resolve)
        """

        return .success(text: result)
    }
}

// MARK: - Tool Registration

public func getRealOptionsTools() -> [MCPToolHandler] {
    return [
        BlackScholesOptionTool(),
        CalculateGreeksTool(),
        BinomialTreeOptionTool(),
        RealOptionsExpansionTool(),
        RealOptionsAbandonmentTool()
    ]
}
