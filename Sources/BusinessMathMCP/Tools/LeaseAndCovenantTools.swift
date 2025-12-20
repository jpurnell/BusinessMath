//
//  LeaseAndCovenantTools.swift
//  BusinessMath MCP Server
//
//  Lease liability and debt covenant tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}


// MARK: - Lease Liability Analysis

public struct LeaseLiabilityTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_lease_liability",
        description: """
        Calculate Right-of-Use (ROU) asset and lease liability under IFRS 16 / ASC 842.

        New lease accounting standards require most leases to be recognized on the balance sheet.

        Calculations:
        • Lease Liability = PV of future lease payments
        • ROU Asset = Lease Liability + Initial Direct Costs + Prepayments - Lease Incentives

        Use Cases:
        • Lease accounting compliance (IFRS 16, ASC 842)
        • Balance sheet impact analysis
        • Operating vs. finance lease classification
        • Financial statement preparation

        Example: 5-year lease, $10K/month, 5% discount rate
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "monthlyPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Monthly lease payment amount"
                ),
                "leaseTerm": MCPSchemaProperty(
                    type: "number",
                    description: "Lease term in months"
                ),
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Incremental borrowing rate as annual decimal (e.g., 0.05 for 5%)"
                ),
                "initialDirectCosts": MCPSchemaProperty(
                    type: "number",
                    description: "Initial direct costs (optional)"
                ),
                "prepayments": MCPSchemaProperty(
                    type: "number",
                    description: "Prepaid lease payments (optional)"
                ),
                "leaseIncentives": MCPSchemaProperty(
                    type: "number",
                    description: "Lease incentives received (optional)"
                )
            ],
            required: ["monthlyPayment", "leaseTerm", "discountRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let monthlyPmt = try args.getDouble("monthlyPayment")
        let term = try args.getInt("leaseTerm")
        let annualRate = try args.getDouble("discountRate")
        let initialCosts = args.getDoubleOptional("initialDirectCosts") ?? 0
        let prepayments = args.getDoubleOptional("prepayments") ?? 0
        let incentives = args.getDoubleOptional("leaseIncentives") ?? 0

        // Convert annual rate to monthly
        let monthlyRate = annualRate / 12.0

        // Calculate present value of lease payments (ordinary annuity)
        let leaseLiability = presentValueAnnuity(payment: monthlyPmt, rate: monthlyRate, periods: term, type: .ordinary)

        // Calculate ROU Asset
        let rouAsset = leaseLiability + initialCosts + prepayments - incentives

        // Calculate total payments
        let totalPayments = monthlyPmt * Double(term)
        let totalInterest = totalPayments - leaseLiability

        let output = """
        Lease Liability Analysis (IFRS 16 / ASC 842):

        Lease Terms:
        • Monthly Payment: $\(formatNumber(monthlyPmt, decimals: 0))
        • Lease Term: \(term) months (\(formatNumber(Double(term) / 12.0, decimals: 1)) years)
        • Discount Rate: \(annualRate.percent()) annual

        Initial Recognition:
        • Lease Liability (PV of payments): $\(formatNumber(leaseLiability, decimals: 0))
        • Initial Direct Costs: $\(formatNumber(initialCosts, decimals: 0))
        • Prepayments: $\(formatNumber(prepayments, decimals: 0))
        • Lease Incentives: $\(formatNumber(incentives, decimals: 0))
        • Right-of-Use (ROU) Asset: $\(formatNumber(rouAsset, decimals: 0))

        Payment Analysis:
        • Total Cash Payments: $\(formatNumber(totalPayments, decimals: 0))
        • Total Interest Expense: $\(formatNumber(totalInterest, decimals: 0))

        Balance Sheet Impact:
        Assets increase by: $\(formatNumber(rouAsset, decimals: 0)) (ROU Asset)
        Liabilities increase by: $\(formatNumber(leaseLiability, decimals: 0)) (Lease Liability)

        Note: Lease liability will be amortized over the lease term using the
        effective interest method. ROU asset will be depreciated straight-line.
        """

        return .success(text: output)
    }
}

// MARK: - Debt Covenant Check

public struct DebtCovenantCheckTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "check_debt_covenant",
        description: """
        Automated checking of debt covenant compliance.

        Debt covenants are restrictions lenders place on borrowers to limit risk.
        Common covenants include maximum leverage ratios, minimum coverage ratios,
        and minimum liquidity requirements.

        Covenant Types:
        • Leverage Covenant (Debt/EBITDA < X)
        • Coverage Covenant (EBITDA/Interest > X)
        • Current Ratio (Current Assets/Liabilities > X)
        • Tangible Net Worth > X

        Use Cases:
        • Loan compliance monitoring
        • Financial reporting
        • Early warning system for violations
        • Lending agreement management

        Example: Check if Debt/EBITDA < 3.5x covenant is met
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "covenantType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of covenant",
                    enum: ["leverage", "coverage", "current_ratio", "tangible_net_worth"]
                ),
                "actualValue": MCPSchemaProperty(
                    type: "number",
                    description: "Actual measured value"
                ),
                "covenantThreshold": MCPSchemaProperty(
                    type: "number",
                    description: "Covenant threshold/limit"
                ),
                "comparisonType": MCPSchemaProperty(
                    type: "string",
                    description: "Comparison type",
                    enum: ["less_than", "greater_than"]
                )
            ],
            required: ["covenantType", "actualValue", "covenantThreshold", "comparisonType"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let covenantType = try args.getString("covenantType")
        let actualValue = try args.getDouble("actualValue")
        let threshold = try args.getDouble("covenantThreshold")
        let comparisonType = try args.getString("comparisonType")

        // Determine compliance
        let isCompliant: Bool
        let comparisonSymbol: String

        switch comparisonType {
        case "less_than":
            isCompliant = actualValue < threshold
            comparisonSymbol = "<"
        case "greater_than":
            isCompliant = actualValue > threshold
            comparisonSymbol = ">"
        default:
            throw ToolError.invalidArguments("Invalid comparison type")
        }

        // Calculate cushion/headroom
        let cushion = comparisonType == "less_than"
            ? threshold - actualValue
            : actualValue - threshold

        let cushionPercent = threshold != 0 ? (cushion / threshold) * 100 : 0

        // Risk assessment
        let riskLevel: String
        let recommendation: String

        if !isCompliant {
            riskLevel = "VIOLATION"
            recommendation = "Covenant violation detected. Immediate action required. Contact lender."
        } else if cushionPercent < 10 {
            riskLevel = "HIGH RISK"
            recommendation = "Very close to violation. Urgent attention needed to improve metrics."
        } else if cushionPercent < 20 {
            riskLevel = "MODERATE RISK"
            recommendation = "Limited headroom. Monitor closely and take preventive action."
        } else {
            riskLevel = "LOW RISK"
            recommendation = "Comfortable compliance cushion. Continue monitoring."
        }

        let covenantDescription: String
        switch covenantType {
        case "leverage":
            covenantDescription = "Leverage Ratio (Debt/EBITDA)"
        case "coverage":
            covenantDescription = "Interest Coverage Ratio (EBITDA/Interest)"
        case "current_ratio":
            covenantDescription = "Current Ratio (Current Assets/Liabilities)"
        case "tangible_net_worth":
            covenantDescription = "Tangible Net Worth"
        default:
            covenantDescription = covenantType
        }

        let complianceStatus = isCompliant ? "✓ COMPLIANT" : "✗ VIOLATION"

        let output = """
        Debt Covenant Compliance Check:

        Covenant: \(covenantDescription)
        Requirement: Must be \(comparisonSymbol) \(formatNumber(threshold, decimals: 2))

        Current Status:
        • Actual Value: \(formatNumber(actualValue, decimals: 2))
        • Threshold: \(formatNumber(threshold, decimals: 2))
        • Status: \(complianceStatus)

        Analysis:
        • Risk Level: \(riskLevel)
        • Cushion/Headroom: \(formatNumber(cushion, decimals: 2)) (\(formatNumber(cushionPercent, decimals: 1))%)
        • Recommendation: \(recommendation)

        Note: Covenant violations can trigger:
        • Higher interest rates
        • Accelerated repayment
        • Additional restrictions
        • Technical default

        Regular monitoring and proactive management are essential.
        """

        return .success(text: output)
    }
}

// MARK: - Custom Payment Schedule

public struct CustomPaymentScheduleTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_custom_payment_schedule",
        description: """
        Generate amortization schedule for custom debt instruments (e.g., bullet loans).

        Bullet loans have interest-only payments with principal due at maturity.
        Other custom structures include graduated payments, balloon payments, etc.

        Payment Types:
        • Bullet: Interest-only, principal at end
        • Balloon: Regular payments with large final payment
        • Interest-Only Period: IO then amortizing
        • Custom: User-defined payment structure

        Use Cases:
        • Commercial real estate financing
        • Bridge loans
        • Construction loans
        • Customized debt structures

        Example: $1M bullet loan, 5% interest, 5 years
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "principal": MCPSchemaProperty(
                    type: "number",
                    description: "Loan principal amount"
                ),
                "annualRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual interest rate as decimal"
                ),
                "term": MCPSchemaProperty(
                    type: "number",
                    description: "Loan term in years"
                ),
                "paymentType": MCPSchemaProperty(
                    type: "string",
                    description: "Payment structure type",
                    enum: ["bullet", "balloon", "interest_only"]
                ),
                "balloonPayment": MCPSchemaProperty(
                    type: "number",
                    description: "Balloon payment amount (for balloon loans)"
                )
            ],
            required: ["principal", "annualRate", "term", "paymentType"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let principal = try args.getDouble("principal")
        let annualRate = try args.getDouble("annualRate")
        let years = try args.getInt("term")
        let paymentType = try args.getString("paymentType")
        let balloonPayment = args.getDoubleOptional("balloonPayment")

        let periods = years * 12
        let monthlyRate = annualRate / 12.0
        let monthlyInterest = principal * monthlyRate

        var scheduleDescription: String
        var monthlyPayment: Double
        var finalPayment: Double
        var totalInterest: Double

        switch paymentType {
        case "bullet":
            monthlyPayment = monthlyInterest
            finalPayment = principal + monthlyInterest
            totalInterest = monthlyInterest * Double(periods)
            scheduleDescription = "Interest-only payments with principal due at maturity"

        case "balloon":
            let balloon = balloonPayment ?? principal * 0.3 // Default 30% balloon
            let amortPrincipal = principal - balloon
            let regularPayment = payment(presentValue: amortPrincipal, rate: monthlyRate, periods: periods, futureValue: 0, type: .ordinary)
            monthlyPayment = regularPayment
            finalPayment = regularPayment + balloon
            totalInterest = (regularPayment * Double(periods) + balloon) - principal
            scheduleDescription = "Regular amortizing payments with balloon of $\(formatNumber(balloon, decimals: 0)) at maturity"

        case "interest_only":
            monthlyPayment = monthlyInterest
            finalPayment = principal + monthlyInterest
            totalInterest = monthlyInterest * Double(periods)
            scheduleDescription = "Interest-only period with principal due at maturity"

        default:
            throw ToolError.invalidArguments("Invalid payment type")
        }

        let totalPayments = monthlyPayment * Double(periods - 1) + finalPayment

        let output = """
        Custom Payment Schedule:

        Loan Terms:
        • Principal: $\(formatNumber(principal, decimals: 0))
        • Annual Interest Rate: \(annualRate.percent())
        • Term: \(years) years (\(periods) months)
        • Payment Structure: \(paymentType.capitalized)

        Payment Schedule:
        • Structure: \(scheduleDescription)
        • Monthly Payment (periods 1-\(periods-1)): $\(formatNumber(monthlyPayment, decimals: 0))
        • Final Payment (period \(periods)): $\(formatNumber(finalPayment, decimals: 0))

        Summary:
        • Total Payments: $\(formatNumber(totalPayments, decimals: 0))
        • Total Interest: $\(formatNumber(totalInterest, decimals: 0))
        • Effective Interest Cost: \((totalInterest / principal).percent())

        Cash Flow Impact:
        Lower monthly payments preserve cash flow but result in
        larger final payment and potentially higher total interest.
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns all lease and covenant tools
public func getLeaseAndCovenantTools() -> [any MCPToolHandler] {
    return [
        LeaseLiabilityTool(),
        DebtCovenantCheckTool(),
        CustomPaymentScheduleTool()
    ]
}
