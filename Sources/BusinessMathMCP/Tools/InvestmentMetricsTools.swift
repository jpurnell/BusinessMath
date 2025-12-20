//
//  InvestmentMetricsTools.swift
//  BusinessMath MCP Server
//
//  Investment decision and analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all investment metrics tools
public func getInvestmentMetricsTools() -> [any MCPToolHandler] {
    return [
        ProfitabilityIndexTool(),
        PaybackPeriodTool(),
        DiscountedPaybackPeriodTool(),
        MIRRTool()
    ]
}

// MARK: - Helper Functions

/// Format a rate as percentage
private func formatRate(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

// MARK: - Profitability Index

public struct ProfitabilityIndexTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_profitability_index",
        description: """
        Calculate Profitability Index (PI) for investment decision-making.

        PI measures the value created per unit of investment. It's the ratio of the present
        value of future cash flows to the present value of investments.

        Formula: PI = PV(positive flows) / |PV(negative flows)|

        Decision Rules:
        • PI > 1: Accept project (positive NPV, value creation)
        • PI < 1: Reject project (negative NPV, value destruction)
        • PI = 1: Break-even (NPV = 0)

        Advantages Over NPV:
        • Useful for ranking projects when capital is limited (capital rationing)
        • Shows efficiency of capital use (value per dollar invested)
        • Better for comparing projects of different sizes
        • Dimensionless metric (easier to communicate)

        Use Cases:
        • Capital rationing decisions (limited budget, must rank projects)
        • Comparing multiple investment opportunities
        • Efficiency analysis (which project uses capital most effectively)
        • Portfolio optimization (maximizing return per dollar)

        Example 1 - Strong Project:
        Investment: -$1,000 today
        Returns: $600/year for 2 years
        Discount Rate: 10%
        PI: ~1.041 → Accept (generates $1.04 per $1 invested)

        Example 2 - Weak Project:
        Investment: -$1,000 today
        Returns: $400/year for 2 years
        Discount Rate: 10%
        PI: ~0.694 → Reject (only returns $0.69 per $1 invested)

        Example 3 - Capital Rationing:
        Project A: PI = 1.50, Investment = $100k
        Project B: PI = 1.30, Investment = $200k
        Budget: $150k → Choose Project A (higher PI, fits budget)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Discount rate per period (e.g., 0.10 for 10% annual rate)"
                ),
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows where negative = investments, positive = returns. First element is typically initial investment at t=0.",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["discountRate", "cashFlows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("discountRate")
        let cashFlows = try args.getDoubleArray("cashFlows")

        // Validate inputs
        guard cashFlows.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 cash flows")
        }

        // Calculate PI
        let pi = profitabilityIndex(rate: rate, cashFlows: cashFlows)

        // Calculate NPV for context
		let npValue = try? npv(discountRate: rate, cashFlows: cashFlows)
		let npvValue = (npValue ?? 0.0)

        // Calculate PV components
        var pvPositive = 0.0
        var pvNegative = 0.0
        for (period, flow) in cashFlows.enumerated() {
            let discountFactor = pow(1.0 + rate, Double(period))
            let pv = flow / discountFactor
            if flow > 0 {
                pvPositive += pv
            } else if flow < 0 {
                pvNegative += pv
            }
        }

        // Interpretation
        let decision: String
        let interpretation: String

        if pi > 1.20 {
            decision = "Strong Accept"
            interpretation = "Excellent investment - generates significant value per dollar invested"
        } else if pi > 1.0 {
            decision = "Accept"
            interpretation = "Good investment - creates positive value"
        } else if pi > 0.90 {
            decision = "Marginal"
            interpretation = "Close to break-even - consider risk and alternatives"
        } else {
            decision = "Reject"
            interpretation = "Poor investment - destroys value"
        }

        let output = """
        Profitability Index (PI) Analysis

        Cash Flows:
        \(cashFlows.enumerated().map { "  Period \($0): \($1.currency())" }.joined(separator: "\n"))

        Discount Rate: \(formatRate(rate))

        Calculation:
        • PV of Positive Cash Flows: \(pvPositive.currency())
        • PV of Negative Cash Flows: \(pvNegative.currency())
        • Absolute PV of Investments: \((-pvNegative).currency())

        Result:
        • Profitability Index: \(formatNumber(pi, decimals: 3))
        • NPV: \(npvValue.currency())
        • Value per Dollar Invested: \(pi.currency())

        Decision: \(decision)

        Interpretation:
        \(interpretation)

        \(pi > 1.0 ? """
        • For every $1.00 invested, you receive $\(formatNumber(pi, decimals: 2)) in present value
        • Total value created: \(npvValue.currency())
        """ : """
        • For every $1.00 invested, you only receive $\(formatNumber(pi, decimals: 2)) in present value
        • Total value destroyed: \(npvValue.currency())
        """)

        Capital Rationing Note:
        When comparing multiple projects with limited budget, rank by PI (highest first)
        and select projects until budget is exhausted.
        """

        return .success(text: output)
    }
}

// MARK: - Payback Period

public struct PaybackPeriodTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_payback_period",
        description: """
        Calculate payback period (undiscounted) for investment recovery analysis.

        The payback period is the number of periods required for cumulative cash flows
        to become positive (i.e., recover the initial investment).

        Important: This is the SIMPLE payback period (ignores time value of money).
        For more accurate analysis, use calculate_discounted_payback_period.

        Decision Rules:
        • Shorter payback = Less risk (capital recovered faster)
        • Set maximum acceptable threshold (e.g., 3 years)
        • Projects exceeding threshold are rejected

        Advantages:
        • Simple to understand and calculate
        • Good for quick risk assessment
        • Useful in liquidity-constrained situations
        • Measures capital recovery speed

        Limitations:
        • Ignores time value of money (no discounting)
        • Ignores cash flows after payback
        • Doesn't measure profitability
        • Can favor short-term over long-term value

        Use Cases:
        • Quick screening of investment opportunities
        • Liquidity-constrained decisions
        • High-risk or uncertain environments
        • Industries with rapid technological change
        • Preliminary project evaluation

        Example 1 - Fast Payback:
        Investment: -$1,000
        Returns: $600, $600
        Payback: 2 periods (recovered in year 2)

        Example 2 - Slow Payback:
        Investment: -$1,000
        Returns: $300, $300, $300, $300
        Payback: 4 periods (recovered in year 4)

        Example 3 - No Payback:
        Investment: -$1,000
        Returns: $100, $100, $100
        Payback: Never (insufficient returns)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows. First element is typically negative (initial investment at t=0).",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["cashFlows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let cashFlows = try args.getDoubleArray("cashFlows")

        // Validate inputs
        guard cashFlows.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 cash flows")
        }

        // Calculate payback period
        let payback = paybackPeriod(cashFlows: cashFlows)

        // Build cumulative flow table
        var cumulativeFlows: [Double] = []
        var cumulative = 0.0
        for flow in cashFlows {
            cumulative += flow
            cumulativeFlows.append(cumulative)
        }

        let output: String

        if let paybackPeriod = payback {
            let interpretation: String
            if paybackPeriod <= 2 {
                interpretation = "Excellent - Very fast capital recovery (low risk)"
            } else if paybackPeriod <= 3 {
                interpretation = "Good - Reasonable payback timeframe"
            } else if paybackPeriod <= 5 {
                interpretation = "Moderate - Longer wait for capital recovery"
            } else {
                interpretation = "Long - Extended payback period (higher risk)"
            }

            output = """
            Payback Period Analysis (Undiscounted)

            Cash Flows & Cumulative Recovery:
            \(cashFlows.enumerated().map { period, flow in
                let cumFlow = cumulativeFlows[period]
                let status = cumFlow >= 0 ? "✓ Recovered" : "⧗ Recovering"
                return "  Period \(period): \(flow.currency()) → Cumulative: \(cumFlow.currency()) \(status)"
            }.joined(separator: "\n"))

            Result:
            • Payback Period: \(paybackPeriod) periods
            • Investment recovered by end of period \(paybackPeriod)

            Risk Assessment: \(interpretation)

            Note: This is SIMPLE payback (undiscounted).
            • Does NOT account for time value of money
            • Does NOT measure profitability
            • Use discounted payback for more accurate analysis
            • Use NPV or PI to measure value creation

            Recommendation:
            \(paybackPeriod <= 3 ? "✓ Short payback suggests lower risk profile" : "⚠ Longer payback increases risk - ensure strong NPV to justify")
            """
        } else {
            output = """
            Payback Period Analysis (Undiscounted)

            Cash Flows & Cumulative Recovery:
            \(cashFlows.enumerated().map { period, flow in
                let cumFlow = cumulativeFlows[period]
                return "  Period \(period): \(flow.currency()) → Cumulative: \(cumFlow.currency())"
            }.joined(separator: "\n"))

            Result:
            • Payback Period: NEVER
            • Investment is never fully recovered
            • Final cumulative cash flow: \((cumulativeFlows.last ?? 0).currency())

            Risk Assessment: High Risk - No Payback

            Interpretation:
            The cumulative cash flows never become positive. This investment does not
            recover its initial capital within the projection period.

            Recommendation:
            ✗ REJECT - Investment fails to recover capital
            • Consider extending projection period if project continues beyond
            • Verify cash flow projections are accurate
            • This project likely has negative NPV
            """
        }

        return .success(text: output)
    }
}

// MARK: - Discounted Payback Period

public struct DiscountedPaybackPeriodTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_discounted_payback_period",
        description: """
        Calculate discounted payback period with time value of money.

        Similar to regular payback period, but accounts for the time value of money
        by discounting cash flows before calculating cumulative total. This provides
        a more accurate assessment of when an investment truly breaks even.

        Formula: Find period where Σ(CF_t / (1+r)^t) ≥ 0

        Advantages Over Simple Payback:
        • Considers time value of money (opportunity cost)
        • More accurate risk assessment
        • Better aligns with NPV/IRR methods
        • More conservative estimate (always ≥ simple payback)

        Decision Rules:
        • Shorter discounted payback = Lower risk
        • Compare against required payback threshold
        • Always longer than simple payback period

        Use Cases:
        • Capital budgeting with time value consideration
        • Risk-adjusted project evaluation
        • Comparing investments with different timing patterns
        • Situations requiring liquidity analysis with accuracy

        Example 1 - Effect of Discounting:
        Investment: -$1,000
        Returns: $500/year for 3 years
        At 10% discount rate:
        • Simple payback: 2 years
        • Discounted payback: 3 years (takes longer in PV terms)

        Example 2 - High Discount Rate:
        Investment: -$1,000
        Returns: $400/year for 4 years
        At 15% discount rate: Payback in 3-4 years (vs 2.5 years undiscounted)

        Limitation: Still ignores cash flows after payback. Use NPV for overall profitability.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Discount rate per period (e.g., 0.10 for 10% annual rate)"
                ),
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows. First element is typically initial investment at t=0.",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["discountRate", "cashFlows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("discountRate")
        let cashFlows = try args.getDoubleArray("cashFlows")

        // Validate inputs
        guard cashFlows.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 cash flows")
        }

        // Calculate discounted payback period
        let discountedPayback = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)

        // Also calculate simple payback for comparison
        let simplePayback = paybackPeriod(cashFlows: cashFlows)

        // Build tables
        var presentValues: [Double] = []
        var cumulativePVs: [Double] = []
        var cumulativeUndiscounted: [Double] = []

        var cumPV = 0.0
        var cumUndiscounted = 0.0

        for (period, flow) in cashFlows.enumerated() {
            let discountFactor = pow(1.0 + rate, Double(period))
            let pv = flow / discountFactor

            cumPV += pv
            cumUndiscounted += flow

            presentValues.append(pv)
            cumulativePVs.append(cumPV)
            cumulativeUndiscounted.append(cumUndiscounted)
        }

        let output: String

        if let discPayback = discountedPayback {
            let interpretation: String
            if discPayback <= 2 {
                interpretation = "Excellent - Very fast recovery in present value terms"
            } else if discPayback <= 3 {
                interpretation = "Good - Reasonable discounted payback"
            } else if discPayback <= 5 {
                interpretation = "Moderate - Longer discounted recovery period"
            } else {
                interpretation = "Long - Extended discounted payback (higher risk)"
            }

            let comparison: String
            if let simplePayback = simplePayback {
                let difference = discPayback - simplePayback
                comparison = """

                Comparison with Simple Payback:
                • Simple Payback: \(simplePayback) periods
                • Discounted Payback: \(discPayback) periods
                • Difference: \(difference) period(s) longer due to time value of money
                """
            } else {
                comparison = "\n• Simple payback never achieved"
            }

            output = """
            Discounted Payback Period Analysis

            Discount Rate: \(formatRate(rate))

            Cash Flows with Present Values:
            \(cashFlows.enumerated().map { period, flow in
                let pv = presentValues[period]
                let cumPV = cumulativePVs[period]
                let status = cumPV >= 0 ? "✓ Recovered (PV)" : "⧗ Recovering"
                return """
                  Period \(period): \(flow.currency())
                    → PV: \(pv.currency())
                    → Cumulative PV: \(cumPV.currency()) \(status)
                """
            }.joined(separator: "\n"))

            Result:
            • Discounted Payback Period: \(discPayback) periods
            • Investment recovered (in PV terms) by end of period \(discPayback)\(comparison)

            Risk Assessment: \(interpretation)

            Interpretation:
            After discounting at \(formatRate(rate)), the investment breaks even
            at period \(discPayback). This accounts for the opportunity cost of capital.

            Recommendation:
            \(discPayback <= 3 ? "✓ Acceptable discounted payback for most projects" : "⚠ Extended payback - verify strong NPV justifies the wait")
            """
        } else {
            let comparison: String
            if let simplePayback = simplePayback {
                comparison = """

                • Simple Payback: \(simplePayback) periods (achieved)
                • Discounted Payback: NEVER (not achieved)
                • Despite nominal recovery, project never breaks even in PV terms
                """
            } else {
                comparison = "\n• Simple payback also never achieved"
            }

            output = """
            Discounted Payback Period Analysis

            Discount Rate: \(formatRate(rate))

            Cash Flows with Present Values:
            \(cashFlows.enumerated().map { period, flow in
                let pv = presentValues[period]
                let cumPV = cumulativePVs[period]
                return """
                  Period \(period): \(flow.currency())
                    → PV: \(pv.currency())
                    → Cumulative PV: \(cumPV.currency())
                """
            }.joined(separator: "\n"))

            Result:
            • Discounted Payback Period: NEVER
            • Investment is never recovered in present value terms
            • Final cumulative PV: \((cumulativePVs.last ?? 0).currency())\(comparison)

            Risk Assessment: High Risk - No Discounted Payback

            Interpretation:
            Even after the entire projection period, the cumulative present value
            remains negative. The project fails to recover its investment when
            accounting for the time value of money.

            Recommendation:
            ✗ REJECT - Investment fails to break even in PV terms
            • This project almost certainly has negative NPV
            • Time value of money makes this investment unprofitable
            • Consider projects with better cash flow timing or higher returns
            """
        }

        return .success(text: output)
    }
}

// MARK: - Modified IRR (MIRR)

public struct MIRRTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_mirr",
        description: """
        Calculate Modified Internal Rate of Return (MIRR) for realistic return analysis.

        MIRR addresses key limitations of traditional IRR by using different rates
        for financing and reinvestment, providing a more realistic return measure.

        Formula: MIRR = (FV_positive / |PV_negative|)^(1/n) - 1

        Where:
        • FV_positive = Future value of positive cash flows at reinvestment rate
        • PV_negative = Present value of negative cash flows at finance rate
        • n = Number of periods

        MIRR vs IRR - Key Differences:

        Traditional IRR Problems:
        • Assumes reinvestment at IRR (often unrealistic)
        • Can produce multiple solutions (multiple sign changes)
        • Favors projects with high early returns

        MIRR Advantages:
        • Uses realistic separate rates for financing and reinvestment
        • Always produces unique answer (no multiple solutions)
        • More conservative and realistic return estimate
        • Better for comparing projects with different patterns

        When MIRR < IRR:
        • Reinvestment rate < IRR (most common)
        • Indicates IRR overstates actual returns

        When MIRR > IRR:
        • Reinvestment rate > IRR (rare)
        • Can occur with unusual cash flow patterns

        Use Cases:
        • Comparing projects with different cash flow timing
        • Corporate finance and capital budgeting
        • Private equity and real estate analysis
        • Any situation where IRR assumptions are unrealistic

        Example - Real Estate Investment:
        Investment: -$100,000
        Year 1-4: $15,000 rent/year
        Year 5: $130,000 (rent + sale)
        Finance rate: 8% (cost of capital)
        Reinvestment rate: 6% (treasury rate)
        MIRR: More realistic than high IRR from property sale

        Typical Rate Choices:
        • Finance rate: Cost of capital, loan rate, WACC
        • Reinvestment rate: Treasury rate, savings rate, alternative investment return
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows (negative = investments/outflows, positive = returns/inflows). First element is typically initial investment at t=0.",
                    items: MCPSchemaItems(type: "array")
                ),
                "financeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Rate at which negative cash flows (investments) are financed - typically cost of capital or borrowing rate (e.g., 0.08 for 8%)"
                ),
                "reinvestmentRate": MCPSchemaProperty(
                    type: "number",
                    description: "Rate at which positive cash flows (returns) are reinvested - typically market rate or alternative investment return (e.g., 0.06 for 6%)"
                )
            ],
            required: ["cashFlows", "financeRate", "reinvestmentRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let cashFlows = try args.getDoubleArray("cashFlows")
        let financeRate = try args.getDouble("financeRate")
        let reinvestmentRate = try args.getDouble("reinvestmentRate")

        // Validate inputs
        guard cashFlows.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 cash flows")
        }

        // Calculate MIRR
        let mirrValue: Double
        do {
            mirrValue = try mirr(
                cashFlows: cashFlows,
                financeRate: financeRate,
                reinvestmentRate: reinvestmentRate
            )
        } catch {
			throw ToolError.executionFailed("calculate_mirr", "MIRR calculation failed: \(error.localizedDescription)")
        }

        // Calculate IRR for comparison
        let irrValue: Double?
        do {
            irrValue = try irr(cashFlows: cashFlows)
        } catch {
            irrValue = nil
        }

        // Calculate components
        let n = cashFlows.count - 1
        var pvNegative = 0.0
        var fvPositive = 0.0

        for (period, cashFlow) in cashFlows.enumerated() {
            if cashFlow < 0 {
                let pv = cashFlow / pow(1.0 + financeRate, Double(period))
                pvNegative += pv
            } else if cashFlow > 0 {
                let periodsToEnd = n - period
                let fv = cashFlow * pow(1.0 + reinvestmentRate, Double(periodsToEnd))
                fvPositive += fv
            }
        }

        // Interpretation
        let decision: String
        let interpretation: String

        if mirrValue > 0.15 {
            decision = "Excellent"
            interpretation = "Strong return - significantly exceeds typical cost of capital"
        } else if mirrValue > 0.10 {
            decision = "Good"
            interpretation = "Solid return - exceeds most hurdle rates"
        } else if mirrValue > 0.05 {
            decision = "Moderate"
            interpretation = "Acceptable return - compare with alternatives"
        } else if mirrValue > 0 {
            decision = "Marginal"
            interpretation = "Low return - verify this exceeds cost of capital"
        } else {
            decision = "Reject"
            interpretation = "Negative return - destroys value"
        }

        let irrComparison: String
        if let irr = irrValue {
            let difference = mirrValue - irr
            let explanation: String
            if difference < -0.02 {
                explanation = "MIRR is significantly lower - IRR likely overstates realistic returns"
            } else if difference < 0 {
                explanation = "MIRR is slightly lower - more conservative estimate"
            } else if difference > 0.02 {
                explanation = "MIRR is higher - unusual cash flow pattern"
            } else {
                explanation = "MIRR and IRR are similar - reinvestment assumptions matter less"
            }

            irrComparison = """

            Comparison with Traditional IRR:
            • Traditional IRR: \(formatRate(irr))
            • MIRR: \(formatRate(mirrValue))
            • Difference: \(formatRate(abs(difference))) \(difference < 0 ? "lower" : "higher")
            • \(explanation)
            """
        } else {
            irrComparison = "\n• Traditional IRR could not be calculated (unusual cash flows)"
        }

        let output = """
        Modified Internal Rate of Return (MIRR) Analysis

        Cash Flows:
        \(cashFlows.enumerated().map { "  Period \($0): \($1.currency())" }.joined(separator: "\n"))

        Assumptions:
        • Finance Rate: \(formatRate(financeRate)) (cost of capital for investments)
        • Reinvestment Rate: \(formatRate(reinvestmentRate)) (return on positive cash flows)

        Calculation Components:
        • PV of Investments (at finance rate): \(pvNegative.currency())
        • FV of Returns (at reinvestment rate): \(fvPositive.currency())
        • Number of Periods: \(n)

        Result:
        • Modified Internal Rate of Return (MIRR): \(formatRate(mirrValue))

        Decision: \(decision)

        Interpretation:
        \(interpretation)\(irrComparison)

        Why MIRR is More Realistic:
        • Separates financing and reinvestment assumptions
        • More conservative than IRR (typically)
        • Always produces unique answer
        • Better reflects actual project economics

        Recommendation:
        \(mirrValue > financeRate ? "✓ MIRR exceeds finance rate - project adds value" : "✗ MIRR below finance rate - project destroys value")
        \(mirrValue > reinvestmentRate ? "✓ Project outperforms alternative investments" : "⚠ Alternative investments may be more attractive")
        """

        return .success(text: output)
    }
}
