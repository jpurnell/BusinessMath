import Foundation
import BusinessMath
import MCP

// MARK: - Present Value Tool

public struct PresentValueTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_present_value",
        description: "Calculate the present value of a future amount given an interest rate and number of periods. PV = FV / (1 + r)^n",
        inputSchema: MCPToolInputSchema(
            properties: [
                "futureValue": MCPSchemaProperty(
                    type: "number",
                    description: "The future value amount"
                ),
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The interest rate per period (e.g., 0.05 for 5%)"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods"
                )
            ],
            required: ["futureValue", "rate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let futureValue = try args.getDouble("futureValue")
        let rate = try args.getDouble("rate")
        let periods = try args.getInt("periods")

        let pv = presentValue(futureValue: futureValue, rate: rate, periods: periods)

        let result = """
        Present Value Calculation:
        • Future Value: \(futureValue.formatCurrency())
        • Interest Rate: \(rate.formatPercentage())
        • Periods: \(periods)
        • Present Value: \(pv.formatCurrency())
        """

        return .success(text: result)
    }
}

// MARK: - Future Value Tool

public struct FutureValueTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_future_value",
        description: "Calculate the future value of a present amount given an interest rate and number of periods. FV = PV × (1 + r)^n",
        inputSchema: MCPToolInputSchema(
            properties: [
                "presentValue": MCPSchemaProperty(
                    type: "number",
                    description: "The present value amount"
                ),
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The interest rate per period (e.g., 0.05 for 5%)"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods"
                )
            ],
            required: ["presentValue", "rate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let presentValue = try args.getDouble("presentValue")
        let rate = try args.getDouble("rate")
        let periods = try args.getInt("periods")

        let fv = futureValue(presentValue: presentValue, rate: rate, periods: periods)

        let result = """
        Future Value Calculation:
        • Present Value: \(presentValue.formatCurrency())
        • Interest Rate: \(rate.formatPercentage())
        • Periods: \(periods)
        • Future Value: \(fv.formatCurrency())
        """

        return .success(text: result)
    }
}

// MARK: - NPV Tool

public struct NPVTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_npv",
        description: "Calculate Net Present Value for a series of cash flows. NPV = Σ(CF_t / (1 + r)^t) - Initial Investment",
        inputSchema: MCPToolInputSchema(
            properties: [
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The discount rate per period (e.g., 0.10 for 10%)"
                ),
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows (first is typically the initial investment as a negative number)",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["rate", "cashFlows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("rate")
        let cashFlows = try args.getDoubleArray("cashFlows")

        guard !cashFlows.isEmpty else {
            throw ToolError.invalidArguments("Cash flows array cannot be empty")
        }

        let npvValue = npv(discountRate: rate, cashFlows: cashFlows)

        var cashFlowDetails = ""
        for (index, cf) in cashFlows.enumerated() {
            cashFlowDetails += "\n  Period \(index): \(cf.formatCurrency())"
        }

        let decision = npvValue > 0 ? "✓ Accept (positive NPV)" : "✗ Reject (negative NPV)"

        let result = """
        Net Present Value (NPV) Analysis:
        • Discount Rate: \(rate.formatPercentage())
        • Number of Periods: \(cashFlows.count)
        • Cash Flows:\(cashFlowDetails)

        • Net Present Value: \(npvValue.formatCurrency())
        • Decision: \(decision)
        """

        return .success(text: result)
    }
}

// MARK: - IRR Tool

public struct IRRTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_irr",
        description: "Calculate Internal Rate of Return for a series of cash flows. IRR is the discount rate that makes NPV = 0",
        inputSchema: MCPToolInputSchema(
            properties: [
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of cash flows (first is typically the initial investment as a negative number)",
                    items: MCPSchemaItems(type: "number")
                ),
                "guess": MCPSchemaProperty(
                    type: "number",
                    description: "Initial guess for IRR (default: 0.1 for 10%)"
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
        let guess = args.getDoubleOptional("guess") ?? 0.1

        guard !cashFlows.isEmpty else {
            throw ToolError.invalidArguments("Cash flows array cannot be empty")
        }

        do {
            let irrValue = try irr(cashFlows: cashFlows, guess: guess)

            var cashFlowDetails = ""
            for (index, cf) in cashFlows.enumerated() {
                cashFlowDetails += "\n  Period \(index): \(cf.formatCurrency())"
            }

            let result = """
            Internal Rate of Return (IRR) Analysis:
            • Number of Periods: \(cashFlows.count)
            • Cash Flows:\(cashFlowDetails)

            • Internal Rate of Return: \(irrValue.formatPercentage())
            • Annual Return: \((irrValue * 100).formatDecimal())%
            """

            return .success(text: result)
        } catch {
            return .error(message: "Failed to calculate IRR: \(error.localizedDescription). The cash flows may not have a valid IRR.")
        }
    }
}

// MARK: - Payment Tool

public struct PaymentTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_payment",
        description: "Calculate the periodic payment for a loan or annuity given present value, interest rate, and number of periods",
        inputSchema: MCPToolInputSchema(
            properties: [
                "presentValue": MCPSchemaProperty(
                    type: "number",
                    description: "The loan amount or present value"
                ),
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The interest rate per period (e.g., 0.004167 for 5% annual rate with monthly payments)"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The total number of payment periods"
                ),
                "futureValue": MCPSchemaProperty(
                    type: "number",
                    description: "The future value (default: 0)"
                ),
                "type": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (end of period) or 'due' (beginning of period)",
                    enum: ["ordinary", "due"]
                )
            ],
            required: ["presentValue", "rate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let pv = try args.getDouble("presentValue")
        let rate = try args.getDouble("rate")
        let periods = try args.getInt("periods")
        let fv = args.getDoubleOptional("futureValue") ?? 0.0
        let typeString = args.getStringOptional("type") ?? "ordinary"

        let annuityType: AnnuityType = (typeString == "due") ? .due : .ordinary

        let pmt = payment(
            presentValue: pv,
            rate: rate,
            periods: periods,
            futureValue: fv,
            type: annuityType
        )

        let totalPayments = pmt * Double(periods)
        let totalInterest = totalPayments - pv

        let result = """
        Loan/Annuity Payment Calculation:
        • Loan Amount: \(pv.formatCurrency())
        • Interest Rate: \(rate.formatPercentage()) per period
        • Number of Periods: \(periods)
        • Payment Type: \(typeString.capitalized)

        • Periodic Payment: \(pmt.formatCurrency())
        • Total Payments: \(totalPayments.formatCurrency())
        • Total Interest: \(totalInterest.formatCurrency())
        """

        return .success(text: result)
    }
}

// MARK: - Annuity Present Value Tool

public struct AnnuityPresentValueTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_annuity_pv",
        description: "Calculate the present value of an annuity (series of equal payments)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "payment": MCPSchemaProperty(
                    type: "number",
                    description: "The payment amount per period"
                ),
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The interest rate per period"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods"
                ),
                "type": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (end of period) or 'due' (beginning of period)",
                    enum: ["ordinary", "due"]
                )
            ],
            required: ["payment", "rate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let payment = try args.getDouble("payment")
        let rate = try args.getDouble("rate")
        let periods = try args.getInt("periods")
        let typeString = args.getStringOptional("type") ?? "ordinary"

        let annuityType: AnnuityType = (typeString == "due") ? .due : .ordinary

        let pv = presentValueAnnuity(
            payment: payment,
            rate: rate,
            periods: periods,
            type: annuityType
        )

        let totalPayments = payment * Double(periods)

        let result = """
        Annuity Present Value:
        • Payment per Period: \(payment.formatCurrency())
        • Interest Rate: \(rate.formatPercentage()) per period
        • Number of Periods: \(periods)
        • Payment Type: \(typeString.capitalized)

        • Present Value: \(pv.formatCurrency())
        • Total Payments: \(totalPayments.formatCurrency())
        """

        return .success(text: result)
    }
}

// MARK: - Annuity Future Value Tool

public struct AnnuityFutureValueTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_annuity_fv",
        description: "Calculate the future value of an annuity (series of equal payments)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "payment": MCPSchemaProperty(
                    type: "number",
                    description: "The payment amount per period"
                ),
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The interest rate per period"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods"
                ),
                "type": MCPSchemaProperty(
                    type: "string",
                    description: "Payment timing: 'ordinary' (end of period) or 'due' (beginning of period)",
                    enum: ["ordinary", "due"]
                )
            ],
            required: ["payment", "rate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let payment = try args.getDouble("payment")
        let rate = try args.getDouble("rate")
        let periods = try args.getInt("periods")
        let typeString = args.getStringOptional("type") ?? "ordinary"

        let annuityType: AnnuityType = (typeString == "due") ? .due : .ordinary

        let fv = futureValueAnnuity(
            payment: payment,
            rate: rate,
            periods: periods,
            type: annuityType
        )

        let totalPayments = payment * Double(periods)
        let totalInterest = fv - totalPayments

        let result = """
        Annuity Future Value:
        • Payment per Period: \(payment.formatCurrency())
        • Interest Rate: \(rate.formatPercentage()) per period
        • Number of Periods: \(periods)
        • Payment Type: \(typeString.capitalized)

        • Future Value: \(fv.formatCurrency())
        • Total Payments: \(totalPayments.formatCurrency())
        • Total Interest Earned: \(totalInterest.formatCurrency())
        """

        return .success(text: result)
    }
}

// MARK: - XNPV Tool

public struct XNPVTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_xnpv",
        description: "Calculate Net Present Value for irregular cash flows with specific dates",
        inputSchema: MCPToolInputSchema(
            properties: [
                "rate": MCPSchemaProperty(
                    type: "number",
                    description: "The annual discount rate (e.g., 0.10 for 10%)"
                ),
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of objects with 'date' (ISO 8601 string) and 'amount' (number) properties",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["rate", "cashFlows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let rate = try args.getDouble("rate")

        // Parse cash flows array
        guard let cfArray = args["cashFlows"], let cfData = cfArray.value as? [[String: Any]] else {
            throw ToolError.invalidArguments("cashFlows must be an array of objects")
        }

        let dateFormatter = ISO8601DateFormatter()
        var dates: [Date] = []
        var amounts: [Double] = []

        for (index, cf) in cfData.enumerated() {
            guard let dateString = cf["date"] as? String,
                  let date = dateFormatter.date(from: dateString) else {
                throw ToolError.invalidArguments("cashFlows[\(index)] must have valid 'date' (ISO 8601 string)")
            }

            let amount: Double
            if let amountDouble = cf["amount"] as? Double {
                amount = amountDouble
            } else if let amountInt = cf["amount"] as? Int {
                amount = Double(amountInt)
            } else {
                throw ToolError.invalidArguments("cashFlows[\(index)] must have valid 'amount' (number)")
            }

            dates.append(date)
            amounts.append(amount)
        }

        guard !dates.isEmpty else {
            throw ToolError.invalidArguments("Cash flows array cannot be empty")
        }

        do {
            let xnpvValue = try xnpv(rate: rate, dates: dates, cashFlows: amounts)

            var cashFlowDetails = ""
            for (index, (date, amount)) in zip(dates, amounts).enumerated() {
                let dateStr = dateFormatter.string(from: date)
                cashFlowDetails += "\n  \(index): \(dateStr) - \(amount.formatCurrency())"
            }

            let decision = xnpvValue > 0 ? "✓ Accept (positive NPV)" : "✗ Reject (negative NPV)"

            let result = """
            XNPV (Irregular Cash Flows) Analysis:
            • Annual Discount Rate: \(rate.formatPercentage())
            • Number of Cash Flows: \(dates.count)
            • Cash Flows:\(cashFlowDetails)

            • Net Present Value: \(xnpvValue.formatCurrency())
            • Decision: \(decision)
            """

            return .success(text: result)
        } catch {
            return .error(message: "Failed to calculate XNPV: \(error.localizedDescription)")
        }
    }
}

// MARK: - XIRR Tool

public struct XIRRTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_xirr",
        description: "Calculate Internal Rate of Return for irregular cash flows with specific dates",
        inputSchema: MCPToolInputSchema(
            properties: [
                "cashFlows": MCPSchemaProperty(
                    type: "array",
                    description: "Array of objects with 'date' (ISO 8601 string) and 'amount' (number) properties",
                    items: MCPSchemaItems(type: "object")
                ),
                "guess": MCPSchemaProperty(
                    type: "number",
                    description: "Initial guess for XIRR (default: 0.1 for 10%)"
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

        let guess = args.getDoubleOptional("guess") ?? 0.1

        // Parse cash flows array
        guard let cfArray = args["cashFlows"], let cfData = cfArray.value as? [[String: Any]] else {
            throw ToolError.invalidArguments("cashFlows must be an array of objects")
        }

        let dateFormatter = ISO8601DateFormatter()
        var dates: [Date] = []
        var amounts: [Double] = []

        for (index, cf) in cfData.enumerated() {
            guard let dateString = cf["date"] as? String,
                  let date = dateFormatter.date(from: dateString) else {
                throw ToolError.invalidArguments("cashFlows[\(index)] must have valid 'date' (ISO 8601 string)")
            }

            let amount: Double
            if let amountDouble = cf["amount"] as? Double {
                amount = amountDouble
            } else if let amountInt = cf["amount"] as? Int {
                amount = Double(amountInt)
            } else {
                throw ToolError.invalidArguments("cashFlows[\(index)] must have valid 'amount' (number)")
            }

            dates.append(date)
            amounts.append(amount)
        }

        guard !dates.isEmpty else {
            throw ToolError.invalidArguments("Cash flows array cannot be empty")
        }

        do {
            let xirrValue = try xirr(dates: dates, cashFlows: amounts, guess: guess)

            var cashFlowDetails = ""
            for (index, (date, amount)) in zip(dates, amounts).enumerated() {
                let dateStr = dateFormatter.string(from: date)
                cashFlowDetails += "\n  \(index): \(dateStr) - \(amount.formatCurrency())"
            }

            let result = """
            XIRR (Irregular Cash Flows) Analysis:
            • Number of Cash Flows: \(dates.count)
            • Cash Flows:\(cashFlowDetails)

            • Internal Rate of Return (Annual): \(xirrValue.formatPercentage())
            • Annual Return: \((xirrValue * 100).formatDecimal())%
            """

            return .success(text: result)
        } catch {
            return .error(message: "Failed to calculate XIRR: \(error.localizedDescription). The cash flows may not have a valid XIRR.")
        }
    }
}

/// Get all TVM tools
public func getTVMTools() -> [any MCPToolHandler] {
    return [
        PresentValueTool(),
        FutureValueTool(),
        NPVTool(),
        IRRTool(),
        PaymentTool(),
        AnnuityPresentValueTool(),
        AnnuityFutureValueTool(),
        XNPVTool(),
        XIRRTool()
    ]
}
