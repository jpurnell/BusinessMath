//
//  LoanPaymentAnalysisTools.swift
//  BusinessMath MCP Server
//
//  Loan payment breakdown and analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all loan payment analysis tools
public func getLoanPaymentAnalysisTools() -> [any MCPToolHandler] {
    return [
        PrincipalPaymentTool(),
        InterestPaymentTool(),
        CumulativeInterestTool(),
        CumulativePrincipalTool()
    ]
}

// MARK: - Helper Functions

/// Format a rate as percentage
private func formatRate(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

/// Format percentage

// MARK: - Principal Payment (PPMT)

public struct PrincipalPaymentTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_principal_payment",
        description: """
        Calculate the principal portion of a specific loan payment (Excel PPMT equivalent).

        This tool shows how much of a particular payment goes toward reducing the loan
        principal (the amount owed), rather than paying interest.

        Key Insight: Early in loan life, most payment is interest. Later, most is principal.

        Formula: Principal = Total Payment - Interest Payment

        Where principal increases over time because:
        • Each payment reduces remaining balance
        • Interest is charged on remaining balance
        • As balance decreases, interest decreases
        • Fixed payment means more goes to principal

        Use Cases:
        • Understanding loan amortization
        • Tracking equity buildup in mortgages
        • Planning loan payoff strategies
        • Tax planning (principal is NOT tax deductible)
        • Analyzing refinancing opportunities

        Example - $200,000 Mortgage at 4% for 30 years:
        Period 1 (Month 1):
        • Total Payment: $954.83
        • Interest: $666.67 (70%)
        • Principal: $288.16 (30%)

        Period 180 (Year 15):
        • Total Payment: $954.83
        • Interest: $463.59 (49%)
        • Principal: $491.24 (51%)

        Period 360 (Final):
        • Total Payment: $954.83
        • Interest: $3.16 (0.3%)
        • Principal: $951.67 (99.7%)

        Pattern: Principal payment increases geometrically over loan life.

        Business Applications:
        • Real estate: Track equity for refinancing decisions
        • Auto loans: Determine when to trade in (when equity is positive)
        • Equipment financing: Plan for upgrades when asset is paid off
        • Working capital: Understand true cost of debt service
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "interestRate": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate per period (e.g., 0.05/12 for 5% annual rate with monthly payments)"
                ),
                "period": MCPSchemaProperty(
                    type: "number",
                    description: "The specific payment period to analyze (1-indexed, e.g., 1 for first payment)"
                ),
                "totalPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Total number of payment periods (e.g., 360 for 30-year monthly mortgage)"
                ),
                "loanAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Initial loan amount (present value)"
                ),
                "balloonPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Optional balloon payment at end (future value, default: 0)"
                ),
                "paymentTiming": MCPSchemaProperty(
                    type: "string",
                    description: "When payments occur: 'ordinary' (end of period, default) or 'due' (start of period)"
                )
            ],
            required: ["interestRate", "period", "totalPeriods", "loanAmount"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("interestRate")
        let period = try args.getInt("period")
        let totalPeriods = try args.getInt("totalPeriods")
        let loanAmount = try args.getDouble("loanAmount")
        let balloonPayment = args.getDoubleOptional("balloonPayment") ?? 0.0
        let timingStr = args.getStringOptional("paymentTiming") ?? "ordinary"

        // Validate inputs
        guard period > 0 && period <= totalPeriods else {
            throw ToolError.invalidArguments("Period must be between 1 and \(totalPeriods)")
        }

        let annuityType: AnnuityType = timingStr.lowercased() == "due" ? .due : .ordinary

        // Calculate components
        let totalPayment = payment(
            presentValue: loanAmount,
            rate: rate,
            periods: totalPeriods,
            futureValue: balloonPayment,
            type: annuityType
        )

        let principalPmt = principalPayment(
            rate: rate,
            period: period,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let interestPmt = interestPayment(
            rate: rate,
            period: period,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        // Calculate remaining balance before and after this payment
        let remainingBefore = loanAmount * pow(1.0 + rate, Double(period - 1)) -
                              totalPayment * ((pow(1.0 + rate, Double(period - 1)) - 1.0) / rate)
        let remainingAfter = remainingBefore - principalPmt

        // Calculate percentages
        let principalPct = principalPmt / totalPayment
        let interestPct = interestPmt / totalPayment

        // Lifetime context
        let lifetimePayments = totalPayment * Double(totalPeriods) + balloonPayment
        let totalInterest = lifetimePayments - loanAmount
        let progressPct = Double(period) / Double(totalPeriods)

        let output = """
        Principal Payment Analysis (Period \(period) of \(totalPeriods))

        Loan Details:
        • Loan Amount: \(loanAmount.currency())
        • Interest Rate: \(formatRate(rate)) per period
        • Total Periods: \(totalPeriods)
        • Payment Timing: \(timingStr.capitalized) annuity
        \(balloonPayment > 0 ? "• Balloon Payment: \(balloonPayment.currency())" : "")

        Period \(period) Payment Breakdown:
        • Total Payment: \(totalPayment.currency())
        • Principal Portion: \(principalPmt.currency()) (\(principalPct.percent()))
        • Interest Portion: \(interestPmt.currency()) (\(interestPct.percent()))

        Loan Balance:
        • Balance Before Payment: \(remainingBefore.currency())
        • Principal Reduction: \(principalPmt.currency())
        • Balance After Payment: \(remainingAfter.currency())
        • Equity Built: \((loanAmount - remainingAfter).currency())

        Progress:
        • Loan Progress: \(progressPct.percent()) complete
        • Principal Percentage: \(principalPct.percent()) of payment

        Lifetime Context:
        • Total Payments: \(lifetimePayments.currency())
        • Total Interest: \(totalInterest.currency())
        • Interest as % of Loan: \((totalInterest / loanAmount).percent())

        Interpretation:
        \(period <= totalPeriods / 4 ? """
        Early in loan life: Only \(principalPct.percent()) goes to principal.
        Most of your payment is interest. Consider extra principal payments to save interest.
        """ : period <= totalPeriods / 2 ? """
        Mid-loan: \(principalPct.percent()) goes to principal, building equity faster.
        This is often a good time to evaluate refinancing opportunities.
        """ : period <= 3 * totalPeriods / 4 ? """
        Later stage: \(principalPct.percent()) goes to principal.
        You're building significant equity. Refinancing may not save much at this point.
        """ : """
        Final stages: \(principalPct.percent()) goes to principal!
        Almost all payment reduces the balance. Nearly debt-free.
        """)

        Tax Note:
        Principal payments are NOT tax deductible. Only interest may be deductible.
        """

        return .success(text: output)
    }
}

// MARK: - Interest Payment (IPMT)

public struct InterestPaymentTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_interest_payment",
        description: """
        Calculate the interest portion of a specific loan payment (Excel IPMT equivalent).

        This tool shows how much of a particular payment goes toward interest charges,
        rather than reducing the principal owed.

        Key Insight: Interest is calculated on remaining balance, so it decreases over time.

        Formula: Interest = Remaining Balance × Interest Rate

        Why interest decreases over time:
        • Each payment reduces the principal balance
        • Interest is charged only on remaining principal
        • As principal decreases, interest charges decrease
        • More of fixed payment goes to principal

        Use Cases:
        • Tax planning (interest may be tax deductible)
        • Understanding true cost of borrowing
        • Comparing loan options
        • Planning prepayment strategies
        • Financial statement preparation

        Example - $200,000 Mortgage at 4% annual (0.333%/month) for 30 years:
        Period 1 (Month 1):
        • Balance: $200,000
        • Interest: $666.67 (0.333% of $200,000)
        • 70% of payment

        Period 120 (Year 10):
        • Balance: $150,000
        • Interest: $500.00 (0.333% of $150,000)
        • 52% of payment

        Period 240 (Year 20):
        • Balance: $85,000
        • Interest: $283.33 (0.333% of $85,000)
        • 30% of payment

        Period 360 (Final):
        • Balance: $951
        • Interest: $3.16 (0.333% of $951)
        • 0.3% of payment

        Pattern: Interest payment decreases each period as balance is paid down.

        Tax Planning:
        • Mortgage interest: Often tax deductible (consult tax advisor)
        • Student loans: Limited deductibility based on income
        • Business loans: Generally deductible as business expense
        • Personal loans: Typically NOT deductible
        • HELOC: Deductibility depends on use of funds

        Strategic Implications:
        • High earners may benefit from maintaining mortgage for deduction
        • Lower earners may benefit from paying off loan faster
        • Always compare after-tax cost of debt vs alternative investments
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "interestRate": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate per period (e.g., 0.04/12 for 4% annual rate with monthly payments)"
                ),
                "period": MCPSchemaProperty(
                    type: "number",
                    description: "The specific payment period to analyze (1-indexed)"
                ),
                "totalPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Total number of payment periods"
                ),
                "loanAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Initial loan amount"
                ),
                "balloonPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Optional balloon payment at end (default: 0)"
                ),
                "paymentTiming": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (default) or 'due'"
                )
            ],
            required: ["interestRate", "period", "totalPeriods", "loanAmount"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("interestRate")
        let period = try args.getInt("period")
        let totalPeriods = try args.getInt("totalPeriods")
        let loanAmount = try args.getDouble("loanAmount")
        let balloonPayment = args.getDoubleOptional("balloonPayment") ?? 0.0
        let timingStr = args.getStringOptional("paymentTiming") ?? "ordinary"

        // Validate inputs
        guard period > 0 && period <= totalPeriods else {
            throw ToolError.invalidArguments("Period must be between 1 and \(totalPeriods)")
        }

        let annuityType: AnnuityType = timingStr.lowercased() == "due" ? .due : .ordinary

        // Calculate components
        let totalPayment = payment(
            presentValue: loanAmount,
            rate: rate,
            periods: totalPeriods,
            futureValue: balloonPayment,
            type: annuityType
        )

        let interestPmt = interestPayment(
            rate: rate,
            period: period,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let principalPmt = principalPayment(
            rate: rate,
            period: period,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        // Calculate remaining balance
        let remainingBalance = loanAmount * pow(1.0 + rate, Double(period - 1)) -
                               totalPayment * ((pow(1.0 + rate, Double(period - 1)) - 1.0) / rate)

        // Calculate percentages
        let interestPct = interestPmt / totalPayment
        let principalPct = principalPmt / totalPayment

        // Lifetime calculations
        let totalPaid = totalPayment * Double(totalPeriods) + balloonPayment
        let totalInterestPaid = totalPaid - loanAmount

        // Calculate total interest in first year
        let firstYearEnd = min(12, totalPeriods)
        let firstYearInterest = cumulativeInterest(
            rate: rate,
            startPeriod: 1,
            endPeriod: firstYearEnd,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let output = """
        Interest Payment Analysis (Period \(period) of \(totalPeriods))

        Loan Details:
        • Loan Amount: \(loanAmount.currency())
        • Interest Rate: \(formatRate(rate)) per period
        • Remaining Balance (start of period): \(remainingBalance.currency())

        Period \(period) Payment Breakdown:
        • Total Payment: \(totalPayment.currency())
        • Interest Portion: \(interestPmt.currency()) (\(interestPct.percent()))
        • Principal Portion: \(principalPmt.currency()) (\(principalPct.percent()))

        Interest Calculation:
        • Formula: Balance × Rate = Interest
        • \(remainingBalance.currency()) × \(formatRate(rate)) = \(interestPmt.currency())

        Lifetime Interest Cost:
        • Total Interest Over Life: \(totalInterestPaid.currency())
        • Interest as % of Loan: \((totalInterestPaid / loanAmount).percent())
        • Interest in Period \(period): \(interestPmt.currency())
        • Interest Paid So Far: \(((totalPayment * Double(period)) - (loanAmount - remainingBalance)).currency())
        \(firstYearEnd == 12 ? "\n• First Year Interest: \(firstYearInterest.currency()) (may be tax relevant)" : "")

        Tax Considerations:
        \(period <= 12 ? """
        Early payments have high interest portion. For tax purposes:
        • Mortgage interest: Often deductible (check current limits)
        • Interest deduction may reduce effective interest rate significantly
        • Consult tax advisor about specific deductibility
        """ : """
        Later payments have lower interest. Tax benefits decrease over time.
        • May affect decision to pay off early vs invest
        • Compare after-tax cost of debt to investment returns
        """)

        Strategic Insight:
        \(interestPct > 0.60 ? """
        ⚠ Over 60% of payment is interest. Consider:
        • Making extra principal payments to reduce future interest
        • Refinancing if better rates available
        • Accelerated payment schedule
        """ : interestPct > 0.30 ? """
        ℹ Interest represents \(interestPct.percent()) of payment.
        • Balance between interest and principal
        • Evaluate extra payments vs other investments
        """ : """
        ✓ Only \(interestPct.percent()) is interest - mostly principal now.
        • Building significant equity
        • May not be worth prepaying at this stage
        """)
        """

        return .success(text: output)
    }
}

// MARK: - Cumulative Interest

public struct CumulativeInterestTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cumulative_interest",
        description: """
        Calculate total interest paid over a range of loan payments (Excel CUMIPMT).

        This tool sums up all interest payments from a start period to an end period,
        useful for tax planning, loan comparison, and financial reporting.

        Formula: Sum of interest payments from period A to period B

        Common Use Cases:
        • Annual tax reporting (sum interest for calendar year)
        • Comparing loan options (total interest over life)
        • Refinancing analysis (remaining interest vs new loan cost)
        • Budget planning (yearly interest expense)
        • Financial statements (interest expense for period)

        Example - $200,000 Mortgage at 4% for 30 years:
        First Year (Periods 1-12):
        • Cumulative Interest: ~$7,942
        • Average per month: $662
        • Tax deduction value (24% bracket): ~$1,906

        Years 1-5 (Periods 1-60):
        • Cumulative Interest: ~$38,560
        • Shows true 5-year cost of borrowing

        Entire Loan (Periods 1-360):
        • Cumulative Interest: ~$143,739
        • Total cost: $343,739 for $200,000 loan
        • Interest = 72% of loan amount!

        Last Year (Periods 349-360):
        • Cumulative Interest: ~$1,217
        • Much lower due to small remaining balance

        Tax Planning Applications:
        • Calculate annual mortgage interest for Schedule A
        • Determine if itemizing vs standard deduction is better
        • Plan timing of refinancing to maximize tax benefits
        • Compare multiple properties for tax purposes

        Refinancing Decision:
        • Calculate remaining interest on current loan
        • Compare to total cost of new loan (including fees)
        • Break-even analysis for refinancing

        Strategic Insights:
        • First 1/3 of loan: ~60% of lifetime interest paid
        • Middle 1/3: ~30% of lifetime interest
        • Final 1/3: Only ~10% of lifetime interest
        • Early prepayment saves the most interest
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "interestRate": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate per period"
                ),
                "startPeriod": MCPSchemaProperty(
                    type: "number",
                    description: "First period to include (1-indexed, e.g., 1 for first payment)"
                ),
                "endPeriod": MCPSchemaProperty(
                    type: "number",
                    description: "Last period to include (e.g., 12 for first year if monthly)"
                ),
                "totalPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Total number of payment periods in loan"
                ),
                "loanAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Initial loan amount"
                ),
                "balloonPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Optional balloon payment (default: 0)"
                ),
                "paymentTiming": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (default) or 'due'"
                )
            ],
            required: ["interestRate", "startPeriod", "endPeriod", "totalPeriods", "loanAmount"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("interestRate")
        let startPeriod = try args.getInt("startPeriod")
        let endPeriod = try args.getInt("endPeriod")
        let totalPeriods = try args.getInt("totalPeriods")
        let loanAmount = try args.getDouble("loanAmount")
        let balloonPayment = args.getDoubleOptional("balloonPayment") ?? 0.0
        let timingStr = args.getStringOptional("paymentTiming") ?? "ordinary"

        // Validate inputs
        guard startPeriod > 0 && endPeriod <= totalPeriods && startPeriod <= endPeriod else {
            throw ToolError.invalidArguments("Invalid period range")
        }

        let annuityType: AnnuityType = timingStr.lowercased() == "due" ? .due : .ordinary

        // Calculate cumulative interest
        let cumInterest = cumulativeInterest(
            rate: rate,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        // Calculate companion cumulative principal
        let cumPrincipal = cumulativePrincipal(
            rate: rate,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let totalPayment = payment(
            presentValue: loanAmount,
            rate: rate,
            periods: totalPeriods,
            futureValue: balloonPayment,
            type: annuityType
        )

        let periodCount = endPeriod - startPeriod + 1
        let totalPaid = totalPayment * Double(periodCount)

        // Calculate lifetime interest
        let lifetimeInterest = (totalPayment * Double(totalPeriods) + balloonPayment) - loanAmount

        // Calculate percentage of range
        let interestPct = cumInterest / totalPaid

        let output = """
        Cumulative Interest Analysis (Periods \(startPeriod) to \(endPeriod))

        Loan Details:
        • Loan Amount: \(loanAmount.currency())
        • Interest Rate: \(formatRate(rate)) per period
        • Total Periods: \(totalPeriods)
        • Payment per Period: \(totalPayment.currency())

        Period Range Analysis:
        • Start Period: \(startPeriod)
        • End Period: \(endPeriod)
        • Number of Periods: \(periodCount)

        Cumulative Totals (Periods \(startPeriod)-\(endPeriod)):
        • Total Interest Paid: \(cumInterest.currency())
        • Total Principal Paid: \(cumPrincipal.currency())
        • Total Payments Made: \(totalPaid.currency())
        • Average Interest per Period: \((cumInterest / Double(periodCount)).currency())

        Interest Breakdown:
        • Interest as % of Payments: \(interestPct.percent())
        • Principal as % of Payments: \((cumPrincipal / totalPaid).percent())

        Lifetime Context:
        • Total Lifetime Interest: \(lifetimeInterest.currency())
        • Interest in This Range: \(cumInterest.currency())
        • % of Lifetime Interest: \((cumInterest / lifetimeInterest).percent())

        \(periodCount == 12 ? """

        Annual Tax Reporting:
        • This represents one year of interest payments
        • May be deductible (consult tax advisor)
        • Tax benefit at 24% bracket: ~\((cumInterest * 0.24).currency())
        • Effective rate after tax: ~\(formatRate(rate * 0.76))
        """ : "")

        \(startPeriod == 1 && endPeriod == totalPeriods ? """

        Full Loan Analysis:
        • You will pay \(cumInterest.currency()) in interest
        • This is \((cumInterest / loanAmount).percent()) of the loan amount
        • True cost of \(loanAmount.currency()) loan is \((loanAmount + cumInterest).currency())
        """ : "")

        Strategic Insight:
        \(Double(startPeriod) / Double(totalPeriods) < 0.33 ? """
        Early loan stage - interest is highest here. Extra principal payments
        made now will save the most interest over the loan life.
        """ : Double(startPeriod) / Double(totalPeriods) < 0.67 ? """
        Mid-loan stage - interest is moderate. Consider whether extra payments
        or other investments offer better returns.
        """ : """
        Late loan stage - most payments go to principal now. Interest savings
        from extra payments are minimal at this point.
        """)
        """

        return .success(text: output)
    }
}

// MARK: - Cumulative Principal

public struct CumulativePrincipalTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cumulative_principal",
        description: """
        Calculate total principal paid over a range of loan payments (Excel CUMPRINC).

        This tool sums up all principal payments from a start period to an end period,
        showing how much of the loan balance has been paid down (equity buildup).

        Formula: Sum of principal payments from period A to period B

        Common Use Cases:
        • Track equity buildup in home or vehicle
        • Calculate remaining balance after N payments
        • Evaluate equity for refinancing or sale
        • Verify amortization schedule accuracy
        • Plan for future cash needs

        Example - $200,000 Mortgage at 4% for 30 years:
        First Year (Periods 1-12):
        • Cumulative Principal: ~$3,605
        • Only 1.8% of loan paid off
        • Remaining: $196,395

        Years 1-5 (Periods 1-60):
        • Cumulative Principal: ~$19,080
        • 9.5% of loan paid off
        • Remaining: $180,920

        Years 1-10 (Periods 1-120):
        • Cumulative Principal: ~$41,222
        • 20.6% of loan paid off
        • Remaining: $158,778

        Years 1-20 (Periods 1-240):
        • Cumulative Principal: ~$105,500
        • 52.8% of loan paid off
        • Remaining: $94,500

        Entire Loan (Periods 1-360):
        • Cumulative Principal: $200,000
        • 100% paid off
        • Remaining: $0

        Equity Applications:
        • Home equity: Cumulative principal = equity from payments
        • Plus: Property appreciation
        • Minus: Transaction costs
        • Equals: Net equity for refinancing/selling

        Refinancing Analysis:
        • Calculate remaining balance (loan - cumulative principal)
        • Determine equity position
        • Assess if refinancing makes sense
        • Consider closing costs vs interest savings

        Real Estate Insights:
        • First 15 years: Only ~1/3 of loan paid off
        • Second 15 years: Remaining 2/3 paid off
        • Acceleration happens in later years
        • Extra payments early have huge impact

        Vehicle/Equipment Loans:
        • Track when equity exceeds depreciation
        • Plan for trade-in timing
        • Avoid "underwater" situations
        • Manage asset lifecycle
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "interestRate": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate per period"
                ),
                "startPeriod": MCPSchemaProperty(
                    type: "number",
                    description: "First period to include (1-indexed)"
                ),
                "endPeriod": MCPSchemaProperty(
                    type: "number",
                    description: "Last period to include"
                ),
                "totalPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Total number of payment periods in loan"
                ),
                "loanAmount": MCPSchemaProperty(
                    type: "number",
                    description: "Initial loan amount"
                ),
                "balloonPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Optional balloon payment (default: 0)"
                ),
                "paymentTiming": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (default) or 'due'"
                )
            ],
            required: ["interestRate", "startPeriod", "endPeriod", "totalPeriods", "loanAmount"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("interestRate")
        let startPeriod = try args.getInt("startPeriod")
        let endPeriod = try args.getInt("endPeriod")
        let totalPeriods = try args.getInt("totalPeriods")
        let loanAmount = try args.getDouble("loanAmount")
        let balloonPayment = args.getDoubleOptional("balloonPayment") ?? 0.0
        let timingStr = args.getStringOptional("paymentTiming") ?? "ordinary"

        // Validate inputs
        guard startPeriod > 0 && endPeriod <= totalPeriods && startPeriod <= endPeriod else {
            throw ToolError.invalidArguments("Invalid period range")
        }

        let annuityType: AnnuityType = timingStr.lowercased() == "due" ? .due : .ordinary

        // Calculate cumulative principal
        let cumPrincipal = cumulativePrincipal(
            rate: rate,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        // Calculate companion cumulative interest
        let cumInterest = cumulativeInterest(
            rate: rate,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let totalPayment = payment(
            presentValue: loanAmount,
            rate: rate,
            periods: totalPeriods,
            futureValue: balloonPayment,
            type: annuityType
        )

        let periodCount = endPeriod - startPeriod + 1
        let totalPaid = totalPayment * Double(periodCount)

        // Calculate balances
        let balanceAfterStart = loanAmount - cumulativePrincipal(
            rate: rate,
            startPeriod: 1,
            endPeriod: startPeriod - 1,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        let balanceAfterEnd = loanAmount - cumulativePrincipal(
            rate: rate,
            startPeriod: 1,
            endPeriod: endPeriod,
            totalPeriods: totalPeriods,
            presentValue: loanAmount,
            futureValue: balloonPayment,
            type: annuityType
        )

        // Calculate percentages
        let principalPct = cumPrincipal / totalPaid
        let paidOffPct = (loanAmount - balanceAfterEnd) / loanAmount
        let remainingPct = balanceAfterEnd / loanAmount

        let output = """
        Cumulative Principal Analysis (Periods \(startPeriod) to \(endPeriod))

        Loan Details:
        • Loan Amount: \(loanAmount.currency())
        • Interest Rate: \(formatRate(rate)) per period
        • Total Periods: \(totalPeriods)
        • Payment per Period: \(totalPayment.currency())

        Period Range Analysis:
        • Start Period: \(startPeriod)
        • End Period: \(endPeriod)
        • Number of Periods: \(periodCount)

        Cumulative Totals (Periods \(startPeriod)-\(endPeriod)):
        • Total Principal Paid: \(cumPrincipal.currency())
        • Total Interest Paid: \(cumInterest.currency())
        • Total Payments Made: \(totalPaid.currency())
        • Average Principal per Period: \((cumPrincipal / Double(periodCount)).currency())

        Principal Breakdown:
        • Principal as % of Payments: \(principalPct.percent())
        • Interest as % of Payments: \((cumInterest / totalPaid).percent())

        Loan Balance Status:
        • Balance at Start (Period \(startPeriod)): \(balanceAfterStart.currency())
        • Principal Reduction: \(cumPrincipal.currency())
        • Balance at End (Period \(endPeriod)): \(balanceAfterEnd.currency())

        Equity Position:
        • Loan Paid Off: \(paidOffPct.percent())
        • Remaining Balance: \(remainingPct.percent())
        • Equity from Payments: \((loanAmount - balanceAfterEnd).currency())

        \(startPeriod == 1 && endPeriod == totalPeriods ? """

        Complete Loan Summary:
        • Total Principal: \(cumPrincipal.currency()) ← Loan amount repaid
        • Total Interest: \(cumInterest.currency()) ← Cost of borrowing
        • Total Paid: \((totalPaid + balloonPayment).currency())
        • Interest as % of Principal: \((cumInterest / cumPrincipal).percent())
        """ : "")

        \(periodCount == 12 ? """

        Annual Summary:
        • This year you paid down \(cumPrincipal.currency()) of principal
        • This builds equity (ownership) in the asset
        • Current equity from payments: \((loanAmount - balanceAfterEnd).currency())
        """ : "")

        Strategic Insight:
        \(paidOffPct < 0.25 ? """
        Early stage: Only \(paidOffPct.percent()) paid off.
        • Most payment goes to interest
        • Extra principal payments have maximum impact
        • Consider refinancing if rates have dropped significantly
        """ : paidOffPct < 0.50 ? """
        Building momentum: \(paidOffPct.percent()) paid off.
        • Principal payments accelerating
        • Good equity position for refinancing
        • Balance between extra payments and investing
        """ : paidOffPct < 0.75 ? """
        Well along: \(paidOffPct.percent()) paid off!
        • Significant equity built
        • Most payment goes to principal now
        • Refinancing may not be worth costs
        """ : """
        Nearly complete: \(paidOffPct.percent()) paid off!
        • Excellent equity position
        • Very close to full ownership
        • Extra payments save little interest now
        """)

        Remaining Obligation:
        • Balance to pay: \(balanceAfterEnd.currency())
        • Remaining payments: \(totalPeriods - endPeriod)
        • Will be debt-free after period \(totalPeriods)
        """

        return .success(text: output)
    }
}
