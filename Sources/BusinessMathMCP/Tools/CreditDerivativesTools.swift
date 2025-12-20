//
//  CreditDerivativesTools.swift
//  BusinessMath MCP Server
//
//  MCP tools for credit derivatives and default modeling
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all credit derivatives tools
public func getCreditDerivativesTools() -> [any MCPToolHandler] {
    return [
        CDSPricingTool(),
        MertonModelTool(),
        HazardRateAnalysisTool(),
        BootstrapCreditCurveTool()
    ]
}

// MARK: - CDS Pricing Tool

public struct CDSPricingTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "price_cds",
        description: """
        Price a Credit Default Swap (CDS) contract.

        A CDS is insurance against credit default. The buyer pays periodic premiums
        (the spread) to the seller in exchange for protection if a reference entity defaults.

        Pricing Components:
        • Premium Leg: PV of spread payments (risky annuity)
        • Protection Leg: PV of default payoff (LGD × default probability)
        • Fair Spread: Protection PV / Premium Annuity

        When to Use:
        • Valuing CDS contracts
        • Assessing credit risk
        • Hedging credit exposure

        Example: 5Y CDS on BBB-rated corporate at 150 bps spread
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "notional": MCPSchemaProperty(
                    type: "number",
                    description: "Notional amount of protection (default: 10,000,000)"
                ),
                "spread": MCPSchemaProperty(
                    type: "number",
                    description: "CDS spread in basis points (e.g., 150 for 150 bps)"
                ),
                "maturity": MCPSchemaProperty(
                    type: "number",
                    description: "Maturity in years (e.g., 5.0 for 5 years)"
                ),
                "recoveryRate": MCPSchemaProperty(
                    type: "number",
                    description: "Expected recovery rate as decimal (default: 0.40 for 40%)"
                ),
                "hazardRate": MCPSchemaProperty(
                    type: "number",
                    description: "Constant hazard rate as decimal (e.g., 0.02 for 2% annual)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate as decimal (default: 0.05 for 5%)"
                )
            ],
            required: ["spread", "maturity", "hazardRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            return .error(message: "Missing arguments")
        }

        // Parse parameters
        let notional = (try? args.getDouble("notional")) ?? 10_000_000.0
        let spreadBps = try args.getDouble("spread")
        let spread = spreadBps / 10000.0  // Convert bps to decimal
        let maturity = try args.getDouble("maturity")
        let recoveryRate = (try? args.getDouble("recoveryRate")) ?? 0.40
        let hazardRate = try args.getDouble("hazardRate")
        let riskFreeRate = (try? args.getDouble("riskFreeRate")) ?? 0.05

        // Create CDS (quarterly payments)
        let cds = CDS(
            notional: notional,
            spread: spread,
            maturity: maturity,
            recoveryRate: recoveryRate,
            paymentFrequency: .quarterly
        )

        // Build discount curve (flat at risk-free rate)
        let numPeriods = Int(maturity * 4)  // Quarterly
        var periods: [Period] = []
        var discountFactors: [Double] = []

        for i in 1...numPeriods {
            let t = Double(i) / 4.0
            periods.append(Period.year(2024 + Int(t)))
            discountFactors.append(exp(-riskFreeRate * t))
        }

        let discountCurve = TimeSeries(periods: periods, values: discountFactors)

        // Build survival curve
        var survivalProbs: [Double] = []
        for i in 1...numPeriods {
            let t = Double(i) / 4.0
            survivalProbs.append(exp(-hazardRate * t))
        }

        let survivalCurve = TimeSeries(periods: periods, values: survivalProbs)

        // Calculate values
        let premiumPV = cds.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        let protectionPV = cds.protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        let fairSpread = cds.fairSpread(discountCurve: discountCurve, hazardRate: hazardRate)
        let fairSpreadBps = fairSpread * 10000.0

        // Calculate MTM (assuming contract spread = market spread for now)
        let mtm = cds.mtm(
            contractSpread: spread,
            marketSpread: spread,
            discountCurve: discountCurve,
            hazardRate: hazardRate
        )

        let result = """
        ## CDS Valuation Results

        **Contract Specifications:**
        - Notional: $\(formatNumber(notional))
        - Spread: \(formatNumber(spreadBps)) bps (\(spread.percent()))
        - Maturity: \(formatNumber(maturity)) years
        - Recovery Rate: \(recoveryRate.percent())
        - Payment Frequency: Quarterly

        **Market Parameters:**
        - Hazard Rate: \(hazardRate.percent())
        - Risk-Free Rate: \(riskFreeRate.percent())
        - Implied Default Probability: \((1 - exp(-hazardRate * maturity)).percent())

        **Valuation:**
        - Premium Leg PV: $\(formatNumber(premiumPV))
        - Protection Leg PV: $\(formatNumber(protectionPV))
        - Mark-to-Market: $\(formatNumber(mtm))
        - Fair Spread: \(formatNumber(fairSpreadBps)) bps

        **Interpretation:**
        \(mtm > 0 ? "• CDS is **in-the-money** for protection buyer (credit quality deteriorated)" : "• CDS is **out-of-the-money** for protection buyer (credit quality improved)")
        \(fairSpreadBps > spreadBps ? "• Market spread is **below fair value** (CDS is cheap)" : "• Market spread is **above fair value** (CDS is expensive)")
        • Annual premium cost: $\(formatNumber(notional * spread))
        • Break-even default probability: \((spread / (1 - recoveryRate)).percent())
        """

        return .success(text: result)
    }
}

// MARK: - Merton Model Tool

public struct MertonModelTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "merton_default_model",
        description: """
        Calculate default probability using Merton structural model.

        The Merton Model treats equity as a call option on firm assets.
        Default occurs when asset value falls below debt face value at maturity.

        Key Outputs:
        • Equity Value: Market value of firm's equity
        • Default Probability: P(assets < debt at maturity)
        • Distance to Default: Standardized measure of credit quality
        • Credit Spread: Yield spread over risk-free rate

        When to Use:
        • Assessing corporate credit risk
        • Estimating default probabilities
        • Stress testing credit portfolios

        Example: Firm with $100M assets, $80M debt, 25% volatility
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assetValue": MCPSchemaProperty(
                    type: "number",
                    description: "Current market value of firm's assets"
                ),
                "assetVolatility": MCPSchemaProperty(
                    type: "number",
                    description: "Volatility of asset returns (as decimal, e.g., 0.25 for 25%)"
                ),
                "debtFaceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value of zero-coupon debt"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free interest rate (default: 0.05 for 5%)"
                ),
                "maturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years until debt matures (default: 1.0)"
                )
            ],
            required: ["assetValue", "assetVolatility", "debtFaceValue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            return .error(message: "Missing arguments")
        }

        // Parse parameters
        let assetValue = try args.getDouble("assetValue")
        let assetVolatility = try args.getDouble("assetVolatility")
        let debtFaceValue = try args.getDouble("debtFaceValue")
        let riskFreeRate = (try? args.getDouble("riskFreeRate")) ?? 0.05
        let maturity = (try? args.getDouble("maturity")) ?? 1.0

        // Create Merton model
        let model = MertonModel(
            assetValue: assetValue,
            assetVolatility: assetVolatility,
            debtFaceValue: debtFaceValue,
            riskFreeRate: riskFreeRate,
            maturity: maturity
        )

        // Calculate metrics
        let equityValue = model.equityValue()
        let debtValue = model.debtValue()
        let defaultProb = model.defaultProbability()
        let distanceToDefault = model.distanceToDefault()
        let creditSpread = model.creditSpread()
        let creditSpreadBps = creditSpread * 10000.0

        let leverage = debtFaceValue / assetValue
        let rating = ratingFromDistance(distanceToDefault)

        let result = """
        ## Merton Model Credit Analysis

        **Firm Parameters:**
        - Asset Value: $\(formatNumber(assetValue))
        - Asset Volatility: \(assetVolatility.percent())
        - Debt Face Value: $\(formatNumber(debtFaceValue))
        - Leverage: \(leverage.percent())
        - Time Horizon: \(formatNumber(maturity)) years

        **Valuation:**
        - Equity Value: $\(formatNumber(equityValue))
        - Debt Value: $\(formatNumber(debtValue))
        - Credit Spread: \(formatNumber(creditSpreadBps)) bps

        **Credit Metrics:**
        - Default Probability: \(defaultProb.percent())
        - Distance to Default: \(formatNumber(distanceToDefault)) σ
        - Implied Rating: **\(rating)**

        **Interpretation:**
        \(distanceToDefault > 3 ? "• **Very Strong** credit quality" : distanceToDefault > 2 ? "• **Good** credit quality" : distanceToDefault > 1 ? "• **Moderate** credit risk" : "• **High** credit risk")
        • Equity represents \((equityValue / assetValue).percent()) of asset value
        • Risk-free debt value: $\(formatNumber(debtFaceValue * exp(-riskFreeRate * maturity)))
        """

        return .success(text: result)
    }
}

// MARK: - Hazard Rate Analysis Tool

public struct HazardRateAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_hazard_rate",
        description: """
        Analyze credit risk using hazard rate models.

        Hazard rates (intensity-based models) represent the instantaneous
        probability of default at each moment in time.

        Key Concepts:
        • Constant Hazard: Exponential default distribution
        • Survival Probability: P(no default by time t)
        • Default Probability: P(default by time t)
        • Hazard from Spread: λ ≈ spread / (1 - recovery)

        When to Use:
        • Converting spreads to default probabilities
        • Calculating survival probabilities
        • Pricing credit-sensitive instruments

        Example: 150 bps spread, 40% recovery → 2.5% hazard rate
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "hazardRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual hazard rate (as decimal, e.g., 0.02 for 2%)"
                ),
                "timeHorizon": MCPSchemaProperty(
                    type: "number",
                    description: "Time horizon in years (default: 5.0)"
                ),
                "creditSpread": MCPSchemaProperty(
                    type: "number",
                    description: "Credit spread in bps (optional, to calculate implied hazard)"
                ),
                "recoveryRate": MCPSchemaProperty(
                    type: "number",
                    description: "Recovery rate as decimal (default: 0.40)"
                )
            ],
            required: ["hazardRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            return .error(message: "Missing arguments")
        }

        // Parse parameters
        let hazardRate = try args.getDouble("hazardRate")
        let timeHorizon = (try? args.getDouble("timeHorizon")) ?? 5.0
        let spreadBps = try? args.getDouble("creditSpread")
        let recoveryRate = (try? args.getDouble("recoveryRate")) ?? 0.40

        // Create constant hazard rate model
        let model = ConstantHazardRate(hazardRate: hazardRate)

        // Calculate probabilities at various horizons
        let horizons = [1.0, 3.0, 5.0, 7.0, 10.0]
        var survivalTable = "| Horizon | Survival | Default | Density |\n"
        survivalTable += "|---------|----------|---------|----------|\n"

        for t in horizons {
            let survival = model.survivalProbability(time: t)
            let defaultProb = model.defaultProbability(time: t)
            let density = model.defaultDensity(time: t)
            survivalTable += "| \(Int(t))Y | \(survival.percent()) | \(defaultProb.percent()) | \(formatNumber(density * 100, decimals: 3))% |\n"
        }

        // Calculate implied spread if requested
        var spreadAnalysis = ""
        if let spreadBps = spreadBps {
            let spread = spreadBps / 10000.0
            let impliedHazard = hazardRateFromSpread(spread: spread, recoveryRate: recoveryRate)
            spreadAnalysis = """

            **Spread Analysis:**
            - Market Spread: \(formatNumber(spreadBps)) bps
            - Implied Hazard Rate: \(impliedHazard.percent())
            - Difference from Input: \(abs(impliedHazard - hazardRate))
            \(abs(impliedHazard - hazardRate) / hazardRate < 0.10 ? "• Spread and hazard are **consistent**" : "• Spread and hazard show **significant difference**")
            """
        }

        let result = """
        ## Hazard Rate Credit Analysis

        **Model Parameters:**
        - Hazard Rate: \(hazardRate.percent()) (λ)
        - Recovery Rate: \(recoveryRate.percent())
        - Loss Given Default: \((1 - recoveryRate).percent())
        - Time Horizon: \(formatNumber(timeHorizon)) years

        **Default Probabilities:**
        \(survivalTable)

        **Key Metrics:**
        - \(Int(timeHorizon))Y Survival: \((model.survivalProbability(time: timeHorizon)).percent())
        - \(Int(timeHorizon))Y Default: \((model.defaultProbability(time: timeHorizon)).percent())
        - Expected Loss (\(Int(timeHorizon))Y): \((model.defaultProbability(time: timeHorizon) * (1 - recoveryRate)).percent())
        \(spreadAnalysis)

        **Interpretation:**
        • Annual default intensity: \(hazardRate.percent())
        • Expected defaults per 100 entities: \(formatNumber(hazardRate * 100))
        • Half-life (50% survival): \(formatNumber(-log(0.5) / hazardRate, decimals: 2)) years
        • Mean time to default: \(formatNumber(1 / hazardRate, decimals: 2)) years
        """

        return .success(text: result)
    }
}

// MARK: - Bootstrap Credit Curve Tool

public struct BootstrapCreditCurveTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "bootstrap_credit_curve",
        description: """
        Bootstrap credit term structure from market CDS quotes.

        Takes market CDS spreads at various maturities and calibrates a
        piecewise constant hazard rate curve that reproduces these quotes.

        Process:
        1. Sort CDS quotes by maturity
        2. For each tenor, solve for hazard rate matching market spread
        3. Build complete term structure

        When to Use:
        • Building credit curves from market data
        • Pricing off-market CDS contracts
        • Calculating default probabilities

        Example: 1Y @ 50bps, 3Y @ 100bps, 5Y @ 150bps
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "cdsSpreads": MCPSchemaProperty(
                    type: "array",
                    description: "Array of CDS spreads in basis points [50, 100, 150, ...]"
                ),
                "tenors": MCPSchemaProperty(
                    type: "array",
                    description: "Array of maturities in years [1.0, 3.0, 5.0, ...]"
                ),
                "recoveryRate": MCPSchemaProperty(
                    type: "number",
                    description: "Recovery rate as decimal (default: 0.40)"
                )
            ],
            required: ["cdsSpreads", "tenors"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            return .error(message: "Missing arguments")
        }

        // Parse array parameters
        let spreadsBps = try args.getDoubleArray("cdsSpreads")
        let spreads = spreadsBps.map { $0 / 10000.0 }
        let tenors = try args.getDoubleArray("tenors")
        let recoveryRate = (try? args.getDouble("recoveryRate")) ?? 0.40

        guard spreads.count == tenors.count && !spreads.isEmpty else {
            return .error(message: "cdsSpreads and tenors must have same length and be non-empty")
        }

        // Bootstrap curve
        let curve = bootstrapCreditCurve(
            tenors: tenors,
            cdsSpreads: spreads,
            recoveryRate: recoveryRate
        )

        // Build results table
        var curveTable = "| Tenor | Spread | Hazard Rate | Survival | Default |\n"
        curveTable += "|-------|--------|-------------|----------|----------|\n"

        for (i, tenor) in tenors.enumerated() {
            let spreadBps = spreads[i] * 10000.0
            let hazard = curve.hazardRates.valuesArray[i]
            let survival = curve.survivalProbability(time: tenor)
            let defaultProb = curve.defaultProbability(time: tenor)

            curveTable += "| \(formatNumber(tenor, decimals: 1))Y | \(formatNumber(spreadBps, decimals: 0)) bps | \(hazard.percent()) | \(survival.percent()) | \(defaultProb.percent()) |\n"
        }

        // Calculate forward hazard rates
        var forwardTable = ""
        if tenors.count > 1 {
            forwardTable = "\n**Forward Hazard Rates:**\n"
            forwardTable += "| Period | Forward Hazard |\n"
            forwardTable += "|--------|----------------|\n"

            for i in 1..<tenors.count {
                let t1 = tenors[i-1]
                let t2 = tenors[i]
                let forward = curve.forwardHazardRate(from: t1, to: t2)
                forwardTable += "| \(formatNumber(t1, decimals: 1))Y-\(formatNumber(t2, decimals: 1))Y | \(forward.percent()) |\n"
            }
        }

        let result = """
        ## Credit Curve Bootstrap Results

        **Market Inputs:**
        - Number of CDS Quotes: \(tenors.count)
        - Recovery Rate: \(recoveryRate.percent())
        - Tenor Range: \(formatNumber(tenors.min() ?? 0, decimals: 1))Y - \(formatNumber(tenors.max() ?? 0, decimals: 1))Y

        **Bootstrapped Curve:**
        \(curveTable)
        \(forwardTable)

        **Interpretation:**
        \(curve.hazardRates.valuesArray.last ?? 0 > curve.hazardRates.valuesArray.first ?? 0 ? "• **Upward sloping** hazard curve (deteriorating credit quality over time)" : "• **Flat or inverted** hazard curve")
        • \(Int(tenors.max() ?? 5))Y cumulative default probability: \((curve.defaultProbability(time: tenors.max() ?? 5)).percent())
        • Average hazard rate: \((curve.hazardRates.valuesArray.reduce(0, +) / Double(curve.hazardRates.valuesArray.count)).percent())
        • Spread range: \(formatNumber((spreads.min() ?? 0) * 10000)) - \(formatNumber((spreads.max() ?? 0) * 10000)) bps
        """

        return .success(text: result)
    }
}

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}


private func ratingFromDistance(_ dd: Double) -> String {
    if dd > 4.0 { return "AAA/AA" }
    if dd > 3.0 { return "A" }
    if dd > 2.0 { return "BBB" }
    if dd > 1.0 { return "BB" }
    if dd > 0.0 { return "B" }
    return "CCC or below"
}
