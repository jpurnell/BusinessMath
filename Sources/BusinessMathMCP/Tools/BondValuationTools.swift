//
//  BondValuationTools.swift
//  BusinessMath MCP Server
//
//  MCP tools for bond valuation and credit analysis
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all bond valuation tools
public func getBondValuationTools() -> [any MCPToolHandler] {
    return [
        BondPriceTool(),
        BondYieldToMaturityTool(),
        BondDurationTool(),
        CreditSpreadAnalysisTool(),
        CallableBondPriceTool(),
        OptionAdjustedSpreadTool(),
        ExpectedLossTool()
    ]
}

// MARK: - Bond Price Tool

public struct BondPriceTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "price_bond",
        description: """
        Calculate bond price given yield to maturity.

        Bonds are priced as the present value of future cash flows (coupons + principal)
        discounted at the market yield. The price-yield relationship is inverse.

        Key Relationships:
        • Coupon > Yield → Premium (price > par)
        • Coupon < Yield → Discount (price < par)
        • Coupon = Yield → Par (price = face value)

        When to Use:
        • Valuing bonds at current market yields
        • Comparing bonds with different coupons
        • Assessing bond attractiveness
        • Portfolio valuation

        Example: $1,000 face, 6% coupon, 5 years, 5% yield = $1,043.30
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "faceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value/par value of bond (default: 1000.0)"
                ),
                "couponRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual coupon rate (as decimal, e.g., 0.06 for 6%)"
                ),
                "yearsToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years until bond matures"
                ),
                "yieldToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Market yield to maturity (as decimal)"
                ),
                "paymentFrequency": MCPSchemaProperty(
                    type: "string",
                    description: "Payment frequency: annual, semiAnnual, quarterly, or monthly (default: semiAnnual)"
                )
            ],
            required: ["couponRate", "yearsToMaturity", "yieldToMaturity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let faceValue = (try? args.getDouble("faceValue")) ?? 1000.0
        let couponRate = try args.getDouble("couponRate")
        let yearsToMaturity = try args.getDouble("yearsToMaturity")
        let ytm = try args.getDouble("yieldToMaturity")
        let freqString = (try? args.getString("paymentFrequency")) ?? "semiAnnual"

        let frequency = parsePaymentFrequency(freqString)

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: Int(yearsToMaturity), to: today)!

        let bond = Bond(
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturity,
            paymentFrequency: frequency,
            issueDate: today
        )

        let price = bond.price(yield: ytm, asOf: today)
        let currentYield = bond.currentYield(price: price)
        let annualCoupon = faceValue * couponRate

        let priceStatus: String
        if price > faceValue * 1.01 {
            priceStatus = "PREMIUM (price > par)"
        } else if price < faceValue * 0.99 {
            priceStatus = "DISCOUNT (price < par)"
        } else {
            priceStatus = "AT PAR (price ≈ par)"
        }

        let result = """
        Bond Pricing Results
        ====================

        Bond Specifications:
          Face Value: \(faceValue.currency())
          Coupon Rate: \(couponRate.percent())
          Annual Coupon: \(annualCoupon.currency())
          Years to Maturity: \(formatNumber(yearsToMaturity, decimals: 1))
          Payment Frequency: \(freqString)

        Market Conditions:
          Yield to Maturity: \(ytm.percent())

        Valuation:
          Bond Price: \(price.currency())
          Status: \(priceStatus)
          Current Yield: \(currentYield.percent())

        Interpretation:
        • Price represents present value of all future cash flows
        • \(couponRate > ytm ? "Trading at premium because coupon exceeds yield" : couponRate < ytm ? "Trading at discount because yield exceeds coupon" : "Trading at par because coupon equals yield")
        • Current yield = Annual coupon / Price
        • YTM accounts for both coupon income and capital gain/loss
        """

        return .success(text: result)
    }
}

// MARK: - Bond Yield to Maturity Tool

public struct BondYieldToMaturityTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_bond_ytm",
        description: """
        Calculate yield to maturity (YTM) given bond price.

        YTM is the internal rate of return if you buy the bond at current price
        and hold to maturity, assuming all coupons are reinvested at the YTM.

        Interpretation:
        • YTM > Coupon Rate → Bond trading at discount
        • YTM < Coupon Rate → Bond trading at premium
        • YTM = Coupon Rate → Bond at par

        Uses iterative Newton-Raphson method for accurate calculation.

        Example: $1,000 bond, 6% coupon, 5 years, trading at $980 = 6.45% YTM
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "faceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value/par value of bond (default: 1000.0)"
                ),
                "couponRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual coupon rate (as decimal)"
                ),
                "yearsToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years until bond matures"
                ),
                "marketPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current market price of bond"
                ),
                "paymentFrequency": MCPSchemaProperty(
                    type: "string",
                    description: "Payment frequency: annual, semiAnnual, quarterly, or monthly (default: semiAnnual)"
                )
            ],
            required: ["couponRate", "yearsToMaturity", "marketPrice"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let faceValue = (try? args.getDouble("faceValue")) ?? 1000.0
        let couponRate = try args.getDouble("couponRate")
        let yearsToMaturity = try args.getDouble("yearsToMaturity")
        let marketPrice = try args.getDouble("marketPrice")
        let freqString = (try? args.getString("paymentFrequency")) ?? "semiAnnual"

        let frequency = parsePaymentFrequency(freqString)

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: Int(yearsToMaturity), to: today)!

        let bond = Bond(
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturity,
            paymentFrequency: frequency,
            issueDate: today
        )

        let ytm = try bond.yieldToMaturity(price: marketPrice, asOf: today)
        let currentYield = bond.currentYield(price: marketPrice)
        let annualCoupon = faceValue * couponRate

        // Calculate capital gain/loss component
        let totalReturn = (faceValue - marketPrice + (annualCoupon * yearsToMaturity)) / marketPrice
        let annualizedReturn = pow(1 + totalReturn, 1 / yearsToMaturity) - 1

        let result = """
        Yield to Maturity Analysis
        ===========================

        Bond Details:
          Face Value: \(faceValue.currency())
          Coupon Rate: \(couponRate.percent())
          Years to Maturity: \(formatNumber(yearsToMaturity, decimals: 1))
          Market Price: \(marketPrice.currency())

        Yield Metrics:
          Yield to Maturity (YTM): \(ytm.percent())
          Current Yield: \(currentYield.percent())
          Coupon Rate: \(couponRate.percent())

        Interpretation:
        • YTM = \(ytm.percent()) is your total return if held to maturity
        • \(ytm > couponRate ? "YTM > Coupon: Bond at discount, includes capital gain" : ytm < couponRate ? "YTM < Coupon: Bond at premium, includes capital loss" : "YTM = Coupon: Bond at par, return is all coupon")
        • Current yield only reflects coupon income, not capital gain/loss
        • YTM assumes all coupons reinvested at \(ytm.percent())
        """

        return .success(text: result)
    }
}

// MARK: - Bond Duration Tool

public struct BondDurationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_bond_duration",
        description: """
        Calculate bond duration and convexity for interest rate risk analysis.

        Duration measures price sensitivity to yield changes. Convexity captures
        the curvature of the price-yield relationship.

        Key Metrics:
        • Macaulay Duration: Weighted average time to cash flows
        • Modified Duration: Price sensitivity (-dP/dy / P)
        • Convexity: Curvature of price-yield relationship

        Duration Rules:
        • Zero-coupon: Duration = Maturity
        • Lower coupon → Higher duration
        • Longer maturity → Higher duration

        Example: 5-year bond, 6% coupon, 5% yield = 4.33 duration
        1% yield increase → ~4.33% price decrease
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "faceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value of bond (default: 1000.0)"
                ),
                "couponRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual coupon rate (as decimal)"
                ),
                "yearsToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years to maturity"
                ),
                "yieldToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Current yield (as decimal)"
                ),
                "paymentFrequency": MCPSchemaProperty(
                    type: "string",
                    description: "Payment frequency (default: semiAnnual)"
                )
            ],
            required: ["couponRate", "yearsToMaturity", "yieldToMaturity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let faceValue = (try? args.getDouble("faceValue")) ?? 1000.0
        let couponRate = try args.getDouble("couponRate")
        let yearsToMaturity = try args.getDouble("yearsToMaturity")
        let ytm = try args.getDouble("yieldToMaturity")
        let freqString = (try? args.getString("paymentFrequency")) ?? "semiAnnual"

        let frequency = parsePaymentFrequency(freqString)

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: Int(yearsToMaturity), to: today)!

        let bond = Bond(
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturity,
            paymentFrequency: frequency,
            issueDate: today
        )

        let price = bond.price(yield: ytm, asOf: today)
        let macaulayDuration = bond.macaulayDuration(yield: ytm, asOf: today)
        let modifiedDuration = bond.modifiedDuration(yield: ytm, asOf: today)
        let convexity = bond.convexity(yield: ytm, asOf: today)

        // Estimate price change for 1% yield increase
        let yieldChange = 0.01  // 100 bps
        let durationEstimate = -modifiedDuration * yieldChange * 100
        let convexityAdjustment = 0.5 * convexity * yieldChange * yieldChange * 100
        let totalEstimate = durationEstimate + convexityAdjustment

        // Calculate actual price change
        let newPrice = bond.price(yield: ytm + yieldChange, asOf: today)
        let actualChange = ((newPrice / price) - 1.0) * 100

        let result = """
        Bond Duration & Convexity Analysis
        ===================================

        Bond Specifications:
          Face Value: \(faceValue.currency())
          Coupon Rate: \(couponRate.percent())
          Years to Maturity: \(formatNumber(yearsToMaturity, decimals: 1))
          Current Yield: \(ytm.percent())
          Current Price: \(price.currency())

        Risk Metrics:
          Macaulay Duration: \(formatNumber(macaulayDuration, decimals: 2)) years
          Modified Duration: \(formatNumber(modifiedDuration, decimals: 2))
          Convexity: \(formatNumber(convexity, decimals: 2))

        Price Sensitivity Analysis (100 bps yield increase):
          Duration Estimate: \(formatNumber(durationEstimate, decimals: 2))%
          Convexity Adjustment: +\(formatNumber(convexityAdjustment, decimals: 2))%
          Total Estimate: \(formatNumber(totalEstimate, decimals: 2))%
          Actual Change: \(formatNumber(actualChange, decimals: 2))%

        Interpretation:
        • Duration = \(formatNumber(modifiedDuration, decimals: 2)) means 1% yield change
          causes ~\(formatNumber(modifiedDuration, decimals: 2))% opposite price change
        • Convexity improves duration estimate for large yield changes
        • Higher duration = Higher interest rate risk
        • Macaulay duration = Weighted average time to cash flows
        """

        return .success(text: result)
    }
}

// MARK: - Credit Spread Analysis Tool

public struct CreditSpreadAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_credit_spread",
        description: """
        Analyze credit risk and calculate appropriate credit spreads.

        Converts company credit metrics (Altman Z-Score) to default probability
        and determines fair credit spread over risk-free rate.

        Z-Score Zones:
        • > 2.99: Safe (investment grade)
        • 1.81-2.99: Grey zone (moderate risk)
        • < 1.81: Distress (high default risk)

        Recovery Rates by Seniority:
        • Senior Secured: 70%
        • Senior Unsecured: 50%
        • Subordinated: 30%
        • Junior: 10%

        Example: Z=2.3, 5yr maturity, senior unsecured = ~150 bps spread
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "zScore": MCPSchemaProperty(
                    type: "number",
                    description: "Altman Z-Score (credit quality metric)"
                ),
                "maturityYears": MCPSchemaProperty(
                    type: "number",
                    description: "Bond maturity in years"
                ),
                "seniority": MCPSchemaProperty(
                    type: "string",
                    description: "Debt seniority: seniorSecured, seniorUnsecured, subordinated, or junior (default: seniorUnsecured)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate (Treasury yield, as decimal) (default: 0.03)"
                )
            ],
            required: ["zScore", "maturityYears"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let zScore = try args.getDouble("zScore")
        let maturityYears = try args.getDouble("maturityYears")
        let seniorityString = (try? args.getString("seniority")) ?? "seniorUnsecured"
        let riskFreeRate = (try? args.getDouble("riskFreeRate")) ?? 0.03

        let seniority = parseSeniority(seniorityString)

        let creditModel = CreditSpreadModel<Double>()
        let defaultProbability = creditModel.defaultProbability(zScore: zScore)
        let recoveryRate = RecoveryModel<Double>.standardRecoveryRate(seniority: seniority)
        let creditSpread = creditModel.creditSpread(
            defaultProbability: defaultProbability,
            recoveryRate: recoveryRate,
            maturity: maturityYears
        )
        let corporateYield = creditModel.corporateBondYield(
            riskFreeRate: riskFreeRate,
            creditSpread: creditSpread
        )

        let creditZone: String
        if zScore > 2.99 {
            creditZone = "SAFE ZONE (Investment Grade)"
        } else if zScore > 1.81 {
            creditZone = "GREY ZONE (Moderate Risk)"
        } else {
            creditZone = "DISTRESS ZONE (High Risk)"
        }

        let result = """
        Credit Spread Analysis
        ======================

        Company Credit Profile:
          Altman Z-Score: \(formatNumber(zScore, decimals: 2))
          Credit Zone: \(creditZone)
          Default Probability: \(defaultProbability.percent())

        Bond Characteristics:
          Maturity: \(formatNumber(maturityYears, decimals: 1)) years
          Seniority: \(seniorityString)
          Expected Recovery: \(recoveryRate.percent())

        Spread Analysis:
          Risk-Free Rate: \(riskFreeRate.percent())
          Credit Spread: \(formatNumber(creditSpread * 10000, decimals: 0)) bps
          Corporate Yield: \(corporateYield.percent())

        Interpretation:
        • Z-Score of \(formatNumber(zScore, decimals: 2)) indicates \(creditZone.lowercased())
        • \(defaultProbability.percent()) chance of default over \(formatNumber(maturityYears, decimals: 0)) years
        • \(seniorityString) debt expects \(recoveryRate.percent()) recovery
        • Spread of \(formatNumber(creditSpread * 10000, decimals: 0)) bps compensates for credit risk
        • Total yield: \(riskFreeRate.percent()) + \(formatNumber(creditSpread * 10000, decimals: 0)) bps = \(corporateYield.percent())
        """

        return .success(text: result)
    }
}

// MARK: - Callable Bond Price Tool

public struct CallableBondPriceTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "price_callable_bond",
        description: """
        Price bonds with embedded call options.

        Callable bonds give the issuer the right to redeem early (typically
        when rates fall). This valuable option makes callable bonds trade
        below equivalent non-callable bonds.

        Key Concepts:
        • Call option has value to issuer (bad for bondholders)
        • Higher volatility → More valuable call option
        • Callable price = Non-callable price - Call option value

        Uses binomial interest rate tree for accurate pricing.

        Example: 10yr bond, 7% coupon, callable at $1,040 after 3 years,
        15% volatility = trades ~$50 below non-callable
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "faceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value of bond (default: 1000.0)"
                ),
                "couponRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual coupon rate (as decimal)"
                ),
                "yearsToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years to maturity"
                ),
                "callYears": MCPSchemaProperty(
                    type: "number",
                    description: "Years until bond becomes callable"
                ),
                "callPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Price at which bond can be called"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate (as decimal)"
                ),
                "creditSpread": MCPSchemaProperty(
                    type: "number",
                    description: "Credit spread over risk-free (as decimal)"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate volatility (as decimal, e.g., 0.15 for 15%)"
                )
            ],
            required: ["couponRate", "yearsToMaturity", "callYears", "callPrice",
                      "riskFreeRate", "creditSpread", "volatility"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let faceValue = (try? args.getDouble("faceValue")) ?? 1000.0
        let couponRate = try args.getDouble("couponRate")
        let yearsToMaturity = try args.getDouble("yearsToMaturity")
        let callYears = try args.getDouble("callYears")
        let callPrice = try args.getDouble("callPrice")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let creditSpread = try args.getDouble("creditSpread")
        let volatility = try args.getDouble("volatility")

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: Int(yearsToMaturity), to: today)!
        let callDate = calendar.date(byAdding: .year, value: Int(callYears), to: today)!

        let bond = Bond(
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callSchedule = [CallProvision(date: callDate, callPrice: callPrice)]
        let callableBond = CallableBond(bond: bond, callSchedule: callSchedule)

        // Price non-callable bond
        let straightYield = riskFreeRate + creditSpread
        let straightPrice = bond.price(yield: straightYield, asOf: today)

        // Price callable bond
        let callablePrice = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        // Calculate call option value
        let callOptionValue = callableBond.callOptionValue(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        // Calculate durations
        let straightDuration = bond.macaulayDuration(yield: straightYield, asOf: today)
        let effectiveDuration = callableBond.effectiveDuration(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        let callPremium = ((callPrice / faceValue) - 1.0) * 100

        let result = """
        Callable Bond Analysis
        ======================

        Bond Specifications:
          Face Value: \(faceValue.currency())
          Coupon Rate: \(couponRate.percent())
          Maturity: \(formatNumber(yearsToMaturity, decimals: 0)) years

        Call Provision:
          Callable After: \(formatNumber(callYears, decimals: 0)) years
          Call Price: \(callPrice.currency())
          Call Premium: \(formatNumber(callPremium, decimals: 1))%

        Market Conditions:
          Risk-Free Rate: \(riskFreeRate.percent())
          Credit Spread: \(formatNumber(creditSpread * 10000, decimals: 0)) bps
          Rate Volatility: \(volatility.percent())

        Valuation:
          Non-Callable Price: \(straightPrice.currency())
          Callable Price: \(callablePrice.currency())
          Call Option Value: \(callOptionValue.currency())

        Risk Metrics:
          Non-Callable Duration: \(formatNumber(straightDuration, decimals: 2)) years
          Effective Duration: \(formatNumber(effectiveDuration, decimals: 2)) years
          Duration Reduction: \(formatNumber(((1 - effectiveDuration / straightDuration) * 100), decimals: 1))%

        Interpretation:
        • Callable bond trades \((straightPrice - callablePrice).currency()) below non-callable
        • Call option worth \(callOptionValue.currency()) to issuer
        • Effective duration \(formatNumber(effectiveDuration, decimals: 2)) < \(formatNumber(straightDuration, decimals: 2)) due to call risk
        • Higher volatility increases call option value (lowers bond price)
        """

        return .success(text: result)
    }
}

// MARK: - Option-Adjusted Spread Tool

public struct OptionAdjustedSpreadTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_oas",
        description: """
        Calculate Option-Adjusted Spread (OAS) for callable bonds.

        OAS isolates the credit risk component by removing the embedded
        option value from the nominal spread. It represents the pure
        credit spread after adjusting for the call option.

        Formula: Nominal Spread = OAS + Option Spread

        Key Uses:
        • Compare bonds with different embedded options
        • Isolate credit risk from option risk
        • Assess relative value across callable bonds
        • Determine if call protection is adequately compensated

        Example: 200 bps nominal spread, 50 bps option value = 150 bps OAS
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "faceValue": MCPSchemaProperty(
                    type: "number",
                    description: "Face value of bond (default: 1000.0)"
                ),
                "couponRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual coupon rate (as decimal)"
                ),
                "yearsToMaturity": MCPSchemaProperty(
                    type: "number",
                    description: "Years to maturity"
                ),
                "callYears": MCPSchemaProperty(
                    type: "number",
                    description: "Years until callable"
                ),
                "callPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Call price"
                ),
                "marketPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current market price"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate (as decimal)"
                ),
                "volatility": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate volatility (as decimal)"
                )
            ],
            required: ["couponRate", "yearsToMaturity", "callYears", "callPrice",
                      "marketPrice", "riskFreeRate", "volatility"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let faceValue = (try? args.getDouble("faceValue")) ?? 1000.0
        let couponRate = try args.getDouble("couponRate")
        let yearsToMaturity = try args.getDouble("yearsToMaturity")
        let callYears = try args.getDouble("callYears")
        let callPrice = try args.getDouble("callPrice")
        let marketPrice = try args.getDouble("marketPrice")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let volatility = try args.getDouble("volatility")

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: Int(yearsToMaturity), to: today)!
        let callDate = calendar.date(byAdding: .year, value: Int(callYears), to: today)!

        let bond = Bond(
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callSchedule = [CallProvision(date: callDate, callPrice: callPrice)]
        let callableBond = CallableBond(bond: bond, callSchedule: callSchedule)

        // Calculate OAS
        let oas = try callableBond.optionAdjustedSpread(
            marketPrice: marketPrice,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            asOf: today
        )

        // Calculate nominal spread from non-callable YTM
        let nominalYTM = try bond.yieldToMaturity(price: marketPrice, asOf: today)
        let nominalSpread = nominalYTM - riskFreeRate

        // Option spread is the difference
        let optionSpread = nominalSpread - oas

        let result = """
        Option-Adjusted Spread Analysis
        ================================

        Bond Details:
          Face Value: \(faceValue.currency())
          Coupon Rate: \(couponRate.percent())
          Maturity: \(formatNumber(yearsToMaturity, decimals: 0)) years
          Callable After: \(formatNumber(callYears, decimals: 0)) years
          Call Price: \(callPrice.currency())

        Market Data:
          Market Price: \(marketPrice.currency())
          Risk-Free Rate: \(riskFreeRate.percent())
          Rate Volatility: \(volatility.percent())

        Spread Decomposition:
          Nominal Spread: \(formatNumber(nominalSpread * 10000, decimals: 0)) bps
          Option-Adjusted Spread (OAS): \(formatNumber(oas * 10000, decimals: 0)) bps
          Option Spread: \(formatNumber(optionSpread * 10000, decimals: 0)) bps

        Interpretation:
        • OAS = \(formatNumber(oas * 10000, decimals: 0)) bps represents pure credit risk
        • Option component = \(formatNumber(optionSpread * 10000, decimals: 0)) bps compensates for call risk
        • Nominal spread = OAS + Option spread
        • Use OAS to compare bonds with different embedded options
        • Higher OAS → Better compensation for credit risk
        """

        return .success(text: result)
    }
}

// MARK: - Expected Loss Tool

public struct ExpectedLossTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_expected_loss",
        description: """
        Calculate expected loss for bond portfolio credit risk.

        Expected Loss = Probability of Default × Loss Given Default × Exposure
        Where: LGD = 1 - Recovery Rate

        Key Applications:
        • Loan loss reserves (CECL/IFRS 9)
        • Credit risk capital requirements
        • Bond portfolio risk assessment
        • Credit VaR calculations

        Recovery rates vary by seniority:
        • Senior Secured: 70% (30% LGD)
        • Senior Unsecured: 50% (50% LGD)
        • Subordinated: 30% (70% LGD)
        • Junior: 10% (90% LGD)

        Example: 2% PD, 50% recovery, $1M exposure = $10,000 expected loss
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "exposure": MCPSchemaProperty(
                    type: "number",
                    description: "Exposure amount (bond investment)"
                ),
                "defaultProbability": MCPSchemaProperty(
                    type: "number",
                    description: "Probability of default (as decimal, or provide zScore)"
                ),
                "zScore": MCPSchemaProperty(
                    type: "number",
                    description: "Altman Z-Score (alternative to providing PD directly)"
                ),
                "seniority": MCPSchemaProperty(
                    type: "string",
                    description: "Debt seniority: seniorSecured, seniorUnsecured, subordinated, or junior (default: seniorUnsecured)"
                )
            ],
            required: ["exposure"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let exposure = try args.getDouble("exposure")
        let seniorityString = (try? args.getString("seniority")) ?? "seniorUnsecured"
        let seniority = parseSeniority(seniorityString)

        // Get default probability (either directly or from Z-Score)
        let defaultProbability: Double
        if let pd = try? args.getDouble("defaultProbability") {
            defaultProbability = pd
        } else if let zScore = try? args.getDouble("zScore") {
            let creditModel = CreditSpreadModel<Double>()
            defaultProbability = creditModel.defaultProbability(zScore: zScore)
        } else {
            throw ToolError.invalidArguments("Must provide either defaultProbability or zScore")
        }

        let recoveryModel = RecoveryModel<Double>()
        let recoveryRate = RecoveryModel<Double>.standardRecoveryRate(seniority: seniority)
        let lgd = recoveryModel.lossGivenDefault(recoveryRate: recoveryRate)
        let expectedLoss = recoveryModel.expectedLoss(
            defaultProbability: defaultProbability,
            recoveryRate: recoveryRate,
            exposure: exposure
        )

        let lossRate = (expectedLoss / exposure) * 100

        let result = """
        Expected Loss Analysis
        ======================

        Portfolio Position:
          Exposure: \(exposure.currency())
          Seniority: \(seniorityString)

        Credit Risk Parameters:
          Default Probability: \(defaultProbability.percent())
          Recovery Rate: \(recoveryRate.percent())
          Loss Given Default: \(lgd.percent())

        Expected Loss Calculation:
          EL = PD × LGD × Exposure
          EL = \(defaultProbability.percent()) × \(lgd.percent()) × \(exposure.currency())
          Expected Loss: \(expectedLoss.currency())
          Loss Rate: \(formatNumber(lossRate, decimals: 2))%

        Interpretation:
        • Expected loss = \(expectedLoss.currency()) on average
        • Loss rate = \(formatNumber(lossRate, decimals: 2))% of exposure
        • Actual loss is binary: either 0 or LGD × Exposure
        • Use for loan loss reserves and credit risk capital
        • Higher seniority → Lower loss given default
        """

        return .success(text: result)
    }
}

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}


private func parsePaymentFrequency(_ string: String) -> PaymentFrequency {
    switch string.lowercased() {
    case "annual": return .annual
    case "semiannual", "semi-annual": return .semiAnnual
    case "quarterly": return .quarterly
    case "monthly": return .monthly
    default: return .semiAnnual
    }
}

private func parseSeniority(_ string: String) -> Seniority {
    switch string.lowercased() {
    case "seniorsecured", "senior_secured", "senior secured": return .seniorSecured
    case "seniorunsecured", "senior_unsecured", "senior unsecured": return .seniorUnsecured
    case "subordinated", "sub": return .subordinated
    case "junior": return .junior
    default: return .seniorUnsecured
    }
}
