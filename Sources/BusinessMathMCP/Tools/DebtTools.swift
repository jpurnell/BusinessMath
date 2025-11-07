import Foundation
import MCP
import BusinessMath

// MARK: - Create Amortization Schedule Tool

public struct CreateAmortizationScheduleTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_amortization_schedule",
        description: "Generate a complete amortization schedule for a loan showing payment breakdown by period (payment, principal, interest, remaining balance). Supports monthly, quarterly, and annual payments.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "principal": MCPSchemaProperty(
                    type: "number",
                    description: "Loan amount or principal"
                ),
                "annualRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual interest rate as decimal (e.g., 0.065 for 6.5%)"
                ),
                "years": MCPSchemaProperty(
                    type: "number",
                    description: "Loan term in years"
                ),
                "frequency": MCPSchemaProperty(
                    type: "string",
                    description: "Payment frequency",
                    enum: ["monthly", "quarterly", "annual"]
                ),
                "showFullSchedule": MCPSchemaProperty(
                    type: "boolean",
                    description: "Show full schedule (true) or summary with first/last payments (false, default)"
                )
            ],
            required: ["principal", "annualRate", "years", "frequency"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let principal = try args.getDouble("principal")
        let annualRate = try args.getDouble("annualRate")
        let years = try args.getInt("years")
        let frequencyString = try args.getString("frequency")
        let showFull = args.getBoolOptional("showFullSchedule") ?? false

        let frequency: PaymentFrequency
        switch frequencyString {
        case "monthly":
            frequency = .monthly
        case "quarterly":
            frequency = .quarterly
        case "annual":
            frequency = .annual
        default:
            throw ToolError.invalidArguments("Invalid frequency: \(frequencyString)")
        }

        // Calculate dates
        let startDate = Date()
        let calendar = Calendar.current
        guard let maturityDate = calendar.date(byAdding: .year, value: years, to: startDate) else {
            throw ToolError.executionFailed("create_amortization_schedule", "Could not calculate maturity date")
        }

        // Create debt instrument
        let debt = DebtInstrument(
            principal: principal,
            interestRate: annualRate,
            startDate: startDate,
            maturityDate: maturityDate,
            paymentFrequency: frequency,
            amortizationType: .levelPayment
        )

        let schedule = debt.schedule()
        let periodsArray = schedule.periods.sorted()

        // Get the periodic payment amount (all payments are equal in level payment amortization)
        let periodicPayment = periodsArray.first.flatMap { schedule.payment[$0] } ?? 0
        let totalPayments = periodicPayment * Double(periodsArray.count)

        var scheduleDetails = ""

        if showFull {
            // Show full schedule
            for (index, period) in periodsArray.enumerated() {
                let pmt = schedule.payment[period] ?? 0
                let prin = schedule.principal[period] ?? 0
                let int = schedule.interest[period] ?? 0
                let bal = schedule.endingBalance[period] ?? 0

                scheduleDetails += "\n  \(index + 1). \(period.label): Payment: \(pmt.formatCurrency()), Principal: \(prin.formatCurrency()), Interest: \(int.formatCurrency()), Balance: \(bal.formatCurrency())"
            }
        } else {
            // Show first 3 and last 3 payments
            let showCount = min(3, periodsArray.count)

            scheduleDetails += "\n  First \(showCount) Payments:"
            for (index, period) in periodsArray.prefix(showCount).enumerated() {
                let pmt = schedule.payment[period] ?? 0
                let prin = schedule.principal[period] ?? 0
                let int = schedule.interest[period] ?? 0
                let bal = schedule.endingBalance[period] ?? 0

                scheduleDetails += "\n    \(index + 1). Payment: \(pmt.formatCurrency()), Principal: \(prin.formatCurrency()), Interest: \(int.formatCurrency()), Balance: \(bal.formatCurrency())"
            }

            if periodsArray.count > 6 {
                scheduleDetails += "\n    ... (\(periodsArray.count - 6) payments omitted)"
            }

            if periodsArray.count > showCount {
                scheduleDetails += "\n\n  Last \(showCount) Payments:"
                for (index, period) in periodsArray.suffix(showCount).enumerated() {
                    let pmt = schedule.payment[period] ?? 0
                    let prin = schedule.principal[period] ?? 0
                    let int = schedule.interest[period] ?? 0
                    let bal = schedule.endingBalance[period] ?? 0

                    let actualIndex = periodsArray.count - showCount + index
                    scheduleDetails += "\n    \(actualIndex + 1). Payment: \(pmt.formatCurrency()), Principal: \(prin.formatCurrency()), Interest: \(int.formatCurrency()), Balance: \(bal.formatCurrency())"
                }
            }
        }

        let result = """
        Amortization Schedule:
        • Loan Amount: \(principal.formatCurrency())
        • Annual Interest Rate: \(annualRate.formatPercentage())
        • Term: \(years) years
        • Payment Frequency: \(frequencyString.capitalized)
        • Number of Payments: \(periodsArray.count)

        Summary:
        • Periodic Payment: \(periodicPayment.formatCurrency())
        • Total of All Payments: \(totalPayments.formatCurrency())
        • Total Interest: \(schedule.totalInterest.formatCurrency())
        • Total Principal: \(schedule.totalPrincipal.formatCurrency())

        Payment Schedule:\(scheduleDetails)
        """

        return .success(text: result)
    }
}

// MARK: - Calculate WACC Tool

public struct CalculateWACCTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_wacc",
        description: "Calculate the Weighted Average Cost of Capital (WACC). WACC represents the average rate a company expects to pay to finance its assets, weighted by the proportion of equity and debt.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "equityValue": MCPSchemaProperty(
                    type: "number",
                    description: "Market value of equity"
                ),
                "debtValue": MCPSchemaProperty(
                    type: "number",
                    description: "Market value of debt"
                ),
                "costOfEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of equity capital as decimal (e.g., 0.12 for 12%)"
                ),
                "costOfDebt": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of debt before tax as decimal (e.g., 0.05 for 5%)"
                ),
                "taxRate": MCPSchemaProperty(
                    type: "number",
                    description: "Corporate tax rate as decimal (e.g., 0.25 for 25%)"
                )
            ],
            required: ["equityValue", "debtValue", "costOfEquity", "costOfDebt", "taxRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let equityValue = try args.getDouble("equityValue")
        let debtValue = try args.getDouble("debtValue")
        let costOfEquity = try args.getDouble("costOfEquity")
        let costOfDebt = try args.getDouble("costOfDebt")
        let taxRate = try args.getDouble("taxRate")

        let waccValue = wacc(
            equityValue: equityValue,
            debtValue: debtValue,
            costOfEquity: costOfEquity,
            costOfDebt: costOfDebt,
            taxRate: taxRate
        )

        let totalValue = equityValue + debtValue
        let equityWeight = totalValue > 0 ? equityValue / totalValue : 0
        let debtWeight = totalValue > 0 ? debtValue / totalValue : 0
        let afterTaxCostOfDebt = costOfDebt * (1 - taxRate)

        let result = """
        Weighted Average Cost of Capital (WACC):

        Capital Structure:
        • Equity Value: \(equityValue.formatCurrency())
        • Debt Value: \(debtValue.formatCurrency())
        • Total Value: \(totalValue.formatCurrency())
        • Equity Weight: \(equityWeight.formatPercentage())
        • Debt Weight: \(debtWeight.formatPercentage())

        Cost Components:
        • Cost of Equity: \(costOfEquity.formatPercentage())
        • Cost of Debt (before tax): \(costOfDebt.formatPercentage())
        • Tax Rate: \(taxRate.formatPercentage())
        • After-Tax Cost of Debt: \(afterTaxCostOfDebt.formatPercentage())

        WACC: \(waccValue.formatPercentage())

        Formula: WACC = (E/V × Re) + (D/V × Rd × (1 - Tc))
        Where E = Equity, D = Debt, V = Total Value, Re = Cost of Equity,
              Rd = Cost of Debt, Tc = Tax Rate

        Use WACC as the discount rate for evaluating projects and investments.
        """

        return .success(text: result)
    }
}

// MARK: - Calculate CAPM Tool

public struct CalculateCAPMTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_capm",
        description: "Calculate the expected return on equity using the Capital Asset Pricing Model (CAPM). CAPM determines the required return based on systematic risk (beta).",
        inputSchema: MCPToolInputSchema(
            properties: [
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate as decimal (e.g., 0.03 for 3% T-bill rate)"
                ),
                "beta": MCPSchemaProperty(
                    type: "number",
                    description: "Beta coefficient (systematic risk). 1.0 = market risk, >1.0 = more volatile, <1.0 = less volatile"
                ),
                "marketReturn": MCPSchemaProperty(
                    type: "number",
                    description: "Expected market return as decimal (e.g., 0.10 for 10%)"
                )
            ],
            required: ["riskFreeRate", "beta", "marketReturn"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let riskFreeRate = try args.getDouble("riskFreeRate")
        let beta = try args.getDouble("beta")
        let marketReturn = try args.getDouble("marketReturn")

        let expectedReturn = capm(
            riskFreeRate: riskFreeRate,
            beta: beta,
            marketReturn: marketReturn
        )

        let marketRiskPremium = marketReturn - riskFreeRate
        let riskPremium = beta * marketRiskPremium

        let riskProfile = if beta > 1.2 {
            "High Risk (beta > 1.2) - More volatile than market"
        } else if beta > 0.8 {
            "Moderate Risk (0.8 < beta < 1.2) - Similar to market"
        } else if beta > 0 {
            "Low Risk (beta < 0.8) - Less volatile than market"
        } else {
            "Defensive (beta ≤ 0) - Inverse correlation with market"
        }

        let result = """
        Capital Asset Pricing Model (CAPM):

        Inputs:
        • Risk-Free Rate: \(riskFreeRate.formatPercentage())
        • Beta (β): \(beta.formatDecimal(decimals: 2))
        • Expected Market Return: \(marketReturn.formatPercentage())

        Calculations:
        • Market Risk Premium: \(marketRiskPremium.formatPercentage())
        • Equity Risk Premium: \(riskPremium.formatPercentage())

        Expected Return on Equity: \(expectedReturn.formatPercentage())
        Risk Profile: \(riskProfile)

        Formula: E(R) = Rf + β × (Rm - Rf)
        Where E(R) = Expected Return, Rf = Risk-Free Rate,
              β = Beta, Rm = Market Return

        Use this as the cost of equity in WACC calculations.
        """

        return .success(text: result)
    }
}

// MARK: - Debt Service Coverage Ratio Tool

public struct DebtServiceCoverageRatioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_dscr",
        description: "Calculate the Debt Service Coverage Ratio (DSCR). DSCR measures ability to pay debt obligations. Lenders typically require DSCR ≥ 1.25. DSCR = Net Operating Income / Total Debt Service",
        inputSchema: MCPToolInputSchema(
            properties: [
                "netOperatingIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net operating income (NOI) or EBITDA"
                ),
                "totalDebtService": MCPSchemaProperty(
                    type: "number",
                    description: "Total annual debt service (principal + interest payments)"
                )
            ],
            required: ["netOperatingIncome", "totalDebtService"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let noi = try args.getDouble("netOperatingIncome")
        let debtService = try args.getDouble("totalDebtService")

        guard debtService > 0 else {
            throw ToolError.invalidArguments("Total debt service must be positive")
        }

        let dscr = noi / debtService

        let assessment: String
        let creditRating: String

        if dscr >= 2.0 {
            assessment = "Excellent - Very strong ability to service debt"
            creditRating = "Very Low Risk"
        } else if dscr >= 1.5 {
            assessment = "Good - Strong ability to service debt"
            creditRating = "Low Risk"
        } else if dscr >= 1.25 {
            assessment = "Adequate - Meets typical lender requirements"
            creditRating = "Acceptable Risk"
        } else if dscr >= 1.0 {
            assessment = "Marginal - Below typical lender requirements"
            creditRating = "Higher Risk"
        } else {
            assessment = "Poor - Insufficient income to cover debt service"
            creditRating = "High Risk / Default Risk"
        }

        let cushion = noi - debtService

        let result = """
        Debt Service Coverage Ratio (DSCR):

        Inputs:
        • Net Operating Income: \(noi.formatCurrency())
        • Total Debt Service: \(debtService.formatCurrency())

        DSCR: \(dscr.formatDecimal(decimals: 2))x
        Assessment: \(assessment)
        Credit Risk: \(creditRating)

        Analysis:
        • Income Available After Debt Service: \(cushion.formatCurrency())
        • Debt Service as % of Income: \((debtService / noi * 100).formatDecimal(decimals: 1))%

        Typical Lender Requirements:
        • Commercial Real Estate: DSCR ≥ 1.25
        • Corporate Loans: DSCR ≥ 1.20
        • Conservative Lending: DSCR ≥ 1.50

        Formula: DSCR = Net Operating Income / Total Debt Service
        """

        return .success(text: result)
    }
}

// MARK: - Altman Z-Score Tool

public struct AltmanZScoreTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_altman_z_score",
        description: "Calculate the Altman Z-Score for bankruptcy prediction. Z-Score uses financial ratios to predict probability of bankruptcy within 2 years. Z > 2.99 = Safe, 1.81-2.99 = Gray, < 1.81 = Distress",
        inputSchema: MCPToolInputSchema(
            properties: [
                "workingCapital": MCPSchemaProperty(
                    type: "number",
                    description: "Working capital (current assets - current liabilities)"
                ),
                "retainedEarnings": MCPSchemaProperty(
                    type: "number",
                    description: "Retained earnings"
                ),
                "ebit": MCPSchemaProperty(
                    type: "number",
                    description: "Earnings before interest and taxes"
                ),
                "marketValueEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Market value of equity (for public companies) or book value (for private)"
                ),
                "totalLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total liabilities"
                ),
                "totalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total assets"
                ),
                "sales": MCPSchemaProperty(
                    type: "number",
                    description: "Total sales/revenue"
                )
            ],
            required: ["workingCapital", "retainedEarnings", "ebit", "marketValueEquity", "totalLiabilities", "totalAssets", "sales"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let workingCapital = try args.getDouble("workingCapital")
        let retainedEarnings = try args.getDouble("retainedEarnings")
        let ebit = try args.getDouble("ebit")
        let marketValueEquity = try args.getDouble("marketValueEquity")
        let totalLiabilities = try args.getDouble("totalLiabilities")
        let totalAssets = try args.getDouble("totalAssets")
        let sales = try args.getDouble("sales")

        guard totalAssets > 0 else {
            throw ToolError.invalidArguments("Total assets must be positive")
        }

        // Calculate Altman Z-Score manually
        // Z = 1.2×X1 + 1.4×X2 + 3.3×X3 + 0.6×X4 + 1.0×X5
        let x1 = workingCapital / totalAssets
        let x2 = retainedEarnings / totalAssets
        let x3 = ebit / totalAssets
        let x4 = marketValueEquity / totalLiabilities
        let x5 = sales / totalAssets

        let zScore = 1.2 * x1 + 1.4 * x2 + 3.3 * x3 + 0.6 * x4 + 1.0 * x5

        let prediction: String
        let risk: String
        let recommendation: String

        if zScore > 2.99 {
            prediction = "Safe Zone - Low bankruptcy risk"
            risk = "Low"
            recommendation = "Company appears financially healthy"
        } else if zScore > 1.81 {
            prediction = "Gray Zone - Possible bankruptcy risk"
            risk = "Medium"
            recommendation = "Monitor closely, investigate further"
        } else {
            prediction = "Distress Zone - High bankruptcy risk"
            risk = "High"
            recommendation = "Significant financial distress indicated"
        }

        let result = """
        Altman Z-Score Analysis:

        Z-Score: \(zScore.formatDecimal(decimals: 2))
        Prediction: \(prediction)
        Bankruptcy Risk: \(risk)
        Recommendation: \(recommendation)

        Component Ratios:
        • X1 (Working Capital / Total Assets): \(x1.formatDecimal(decimals: 3))
        • X2 (Retained Earnings / Total Assets): \(x2.formatDecimal(decimals: 3))
        • X3 (EBIT / Total Assets): \(x3.formatDecimal(decimals: 3))
        • X4 (Market Value Equity / Total Liabilities): \(x4.formatDecimal(decimals: 3))
        • X5 (Sales / Total Assets): \(x5.formatDecimal(decimals: 3))

        Interpretation Scale:
        • Z > 2.99: Safe Zone (low bankruptcy risk)
        • 1.81 < Z < 2.99: Gray Zone (moderate risk, unclear)
        • Z < 1.81: Distress Zone (high bankruptcy risk)

        Formula: Z = 1.2×X1 + 1.4×X2 + 3.3×X3 + 0.6×X4 + 1.0×X5

        Note: Most accurate for publicly-traded manufacturing companies.
        Use with caution for service companies or private firms.
        """

        return .success(text: result)
    }
}

// MARK: - Compare Financing Options Tool

public struct CompareFinancingOptionsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "compare_financing_options",
        description: "Compare multiple financing options (loans, leases, equity) side-by-side based on total cost, monthly payment, and effective annual rate. Helps choose the best financing method.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "amount": MCPSchemaProperty(
                    type: "number",
                    description: "Amount to finance"
                ),
                "option1Rate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual rate for option 1 as decimal"
                ),
                "option1Years": MCPSchemaProperty(
                    type: "number",
                    description: "Term in years for option 1"
                ),
                "option1Name": MCPSchemaProperty(
                    type: "string",
                    description: "Name of option 1 (e.g., 'Bank Loan', 'Lease')"
                ),
                "option2Rate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual rate for option 2 as decimal"
                ),
                "option2Years": MCPSchemaProperty(
                    type: "number",
                    description: "Term in years for option 2"
                ),
                "option2Name": MCPSchemaProperty(
                    type: "string",
                    description: "Name of option 2"
                ),
                "option3Rate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual rate for option 3 (optional)"
                ),
                "option3Years": MCPSchemaProperty(
                    type: "number",
                    description: "Term in years for option 3 (optional)"
                ),
                "option3Name": MCPSchemaProperty(
                    type: "string",
                    description: "Name of option 3 (optional)"
                )
            ],
            required: ["amount", "option1Rate", "option1Years", "option1Name", "option2Rate", "option2Years", "option2Name"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let amount = try args.getDouble("amount")

        struct FinancingOption {
            let name: String
            let rate: Double
            let years: Int
            let monthlyPayment: Double
            let totalPayments: Double
            let totalInterest: Double
        }

        var options: [FinancingOption] = []

        // Option 1
        let rate1 = try args.getDouble("option1Rate")
        let years1 = try args.getInt("option1Years")
        let name1 = try args.getString("option1Name")
        let periods1 = years1 * 12
        let monthlyRate1 = rate1 / 12
        let payment1 = payment(presentValue: amount, rate: monthlyRate1, periods: periods1, futureValue: 0, type: .ordinary)
        let total1 = payment1 * Double(periods1)
        options.append(FinancingOption(
            name: name1,
            rate: rate1,
            years: years1,
            monthlyPayment: payment1,
            totalPayments: total1,
            totalInterest: total1 - amount
        ))

        // Option 2
        let rate2 = try args.getDouble("option2Rate")
        let years2 = try args.getInt("option2Years")
        let name2 = try args.getString("option2Name")
        let periods2 = years2 * 12
        let monthlyRate2 = rate2 / 12
        let payment2 = payment(presentValue: amount, rate: monthlyRate2, periods: periods2, futureValue: 0, type: .ordinary)
        let total2 = payment2 * Double(periods2)
        options.append(FinancingOption(
            name: name2,
            rate: rate2,
            years: years2,
            monthlyPayment: payment2,
            totalPayments: total2,
            totalInterest: total2 - amount
        ))

        // Option 3 (optional)
        if let rate3 = args.getDoubleOptional("option3Rate"),
           let years3 = args.getIntOptional("option3Years"),
           let name3 = args.getStringOptional("option3Name") {
            let periods3 = years3 * 12
            let monthlyRate3 = rate3 / 12
            let payment3 = payment(presentValue: amount, rate: monthlyRate3, periods: periods3, futureValue: 0, type: .ordinary)
            let total3 = payment3 * Double(periods3)
            options.append(FinancingOption(
                name: name3,
                rate: rate3,
                years: years3,
                monthlyPayment: payment3,
                totalPayments: total3,
                totalInterest: total3 - amount
            ))
        }

        // Sort by total cost
        let sortedOptions = options.sorted { $0.totalInterest < $1.totalInterest }

        var comparison = ""
        for (index, option) in sortedOptions.enumerated() {
            let rank = index == 0 ? "👑 BEST" : "#\(index + 1)"
            comparison += """
            \n
            \(rank) - \(option.name):
            • Annual Rate: \(option.rate.formatPercentage())
            • Term: \(option.years) years
            • Monthly Payment: \(option.monthlyPayment.formatCurrency())
            • Total Payments: \(option.totalPayments.formatCurrency())
            • Total Interest: \(option.totalInterest.formatCurrency())
            """
        }

        let bestOption = sortedOptions[0]
        let savings = sortedOptions.last!.totalInterest - bestOption.totalInterest

        let result = """
        Financing Options Comparison:
        • Amount to Finance: \(amount.formatCurrency())
        \(comparison)

        Recommendation:
        Choose '\(bestOption.name)' to save \(savings.formatCurrency()) in total interest compared to the most expensive option.

        Considerations:
        • Lower monthly payment may be better for cash flow despite higher total cost
        • Shorter term builds equity faster
        • Compare APR if options have different fees
        """

        return .success(text: result)
    }
}

/// Get all Debt & Financing tools
public func getDebtTools() -> [any MCPToolHandler] {
    return [
        CreateAmortizationScheduleTool(),
        CalculateWACCTool(),
        CalculateCAPMTool(),
        DebtServiceCoverageRatioTool(),
        AltmanZScoreTool(),
        CompareFinancingOptionsTool()
    ]
}
