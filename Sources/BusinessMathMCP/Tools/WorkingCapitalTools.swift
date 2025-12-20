//
//  WorkingCapitalTools.swift
//  BusinessMath MCP Server
//
//  Working capital and cash cycle analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}


// MARK: - Days Inventory Outstanding (DIO)

public struct DaysInventoryOutstandingTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_days_inventory_outstanding",
        description: """
        Calculate Days Inventory Outstanding (DIO).

        DIO measures the average number of days inventory is held before being sold.
        Lower values indicate faster inventory turnover and better efficiency.

        Formula: DIO = (Average Inventory / Cost of Goods Sold) × 365

        Interpretation (varies by industry):
        • < 30 days : Very fast (perishables, fast food)
        • 30-60 days : Fast (retail, fashion)
        • 60-90 days : Moderate (general merchandise)
        • > 90 days : Slow (luxury goods, machinery)

        Use Cases:
        • Inventory management
        • Working capital optimization
        • Supply chain efficiency
        • Cash conversion cycle analysis

        Example: $200K avg inventory with $2M COGS = 36.5 days
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "averageInventory": MCPSchemaProperty(
                    type: "number",
                    description: "Average inventory during the period"
                ),
                "costOfGoodsSold": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of goods sold for the period"
                )
            ],
            required: ["averageInventory", "costOfGoodsSold"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let avgInventory = try args.getDouble("averageInventory")
        let cogs = try args.getDouble("costOfGoodsSold")

        guard cogs > 0 else {
            throw ToolError.invalidArguments("Cost of goods sold must be positive")
        }

        let dio = (avgInventory / cogs) * 365.0

        let interpretation: String
        if dio < 30 {
            interpretation = "Very Fast - Excellent inventory turnover"
        } else if dio < 60 {
            interpretation = "Fast - Good inventory management"
        } else if dio < 90 {
            interpretation = "Moderate - Standard for many industries"
        } else {
            interpretation = "Slow - Consider inventory optimization strategies"
        }

        let output = """
        Days Inventory Outstanding (DIO) Analysis:

        Inputs:
        • Average Inventory: $\(formatNumber(avgInventory, decimals: 0))
        • Cost of Goods Sold: $\(formatNumber(cogs, decimals: 0))

        Result:
        • Days Inventory Outstanding: \(formatNumber(dio, decimals: 1)) days
        • Annual Turnover: \(formatNumber(365.0 / dio, decimals: 1))x
        • Interpretation: \(interpretation)

        The company holds inventory for an average of \(formatNumber(dio, decimals: 0)) days before sale.
        """

        return .success(text: output)
    }
}

// MARK: - Days Sales Outstanding (DSO)

public struct DaysSalesOutstandingTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_days_sales_outstanding",
        description: """
        Calculate Days Sales Outstanding (DSO).

        DSO measures the average number of days it takes to collect payment after a sale.
        Lower values indicate faster collections and better cash flow.

        Formula: DSO = (Average Accounts Receivable / Net Sales) × 365

        Interpretation:
        • < 30 days : Excellent - Very fast collections
        • 30-45 days : Good - Standard net 30 terms
        • 45-60 days : Moderate - Net 45-60 terms
        • > 60 days : Slow - Collection issues or extended terms

        Use Cases:
        • Collection efficiency tracking
        • Credit policy evaluation
        • Cash flow forecasting
        • Working capital management

        Example: $150K avg receivables with $1.8M sales = 30.4 days
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "averageAccountsReceivable": MCPSchemaProperty(
                    type: "number",
                    description: "Average accounts receivable during the period"
                ),
                "netSales": MCPSchemaProperty(
                    type: "number",
                    description: "Net sales for the period"
                )
            ],
            required: ["averageAccountsReceivable", "netSales"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let avgReceivables = try args.getDouble("averageAccountsReceivable")
        let sales = try args.getDouble("netSales")

        guard sales > 0 else {
            throw ToolError.invalidArguments("Net sales must be positive")
        }

        let dso = (avgReceivables / sales) * 365.0

        let interpretation: String
        if dso < 30 {
            interpretation = "Excellent - Very fast collections, strong credit management"
        } else if dso < 45 {
            interpretation = "Good - Healthy collection period, typical net 30 terms"
        } else if dso < 60 {
            interpretation = "Moderate - Extended payment terms or some delays"
        } else {
            interpretation = "Slow - Review collection practices and customer creditworthiness"
        }

        let output = """
        Days Sales Outstanding (DSO) Analysis:

        Inputs:
        • Average Accounts Receivable: $\(formatNumber(avgReceivables, decimals: 0))
        • Net Sales: $\(formatNumber(sales, decimals: 0))

        Result:
        • Days Sales Outstanding: \(formatNumber(dso, decimals: 1)) days
        • Collection Rate: \(formatNumber(365.0 / dso, decimals: 1))x per year
        • Interpretation: \(interpretation)

        The company takes an average of \(formatNumber(dso, decimals: 0)) days to collect payment after a sale.
        """

        return .success(text: output)
    }
}

// MARK: - Days Payable Outstanding (DPO)

public struct DaysPayableOutstandingTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_days_payable_outstanding",
        description: """
        Calculate Days Payable Outstanding (DPO).

        DPO measures the average number of days a company takes to pay its suppliers.
        Higher values can indicate better cash management but may strain supplier relationships.

        Formula: DPO = (Average Accounts Payable / Cost of Goods Sold) × 365

        Interpretation:
        • > 60 days : Extended - Good cash preservation, monitor supplier relations
        • 45-60 days : Moderate - Standard payment terms
        • 30-45 days : Standard - Typical net 30-45 terms
        • < 30 days : Fast - May miss cash management opportunities

        Use Cases:
        • Cash flow optimization
        • Supplier relationship management
        • Working capital efficiency
        • Cash conversion cycle analysis

        Example: $100K avg payables with $1.2M COGS = 30.4 days
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "averageAccountsPayable": MCPSchemaProperty(
                    type: "number",
                    description: "Average accounts payable during the period"
                ),
                "costOfGoodsSold": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of goods sold for the period"
                )
            ],
            required: ["averageAccountsPayable", "costOfGoodsSold"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let avgPayables = try args.getDouble("averageAccountsPayable")
        let cogs = try args.getDouble("costOfGoodsSold")

        guard cogs > 0 else {
            throw ToolError.invalidArguments("Cost of goods sold must be positive")
        }

        let dpo = (avgPayables / cogs) * 365.0

        let interpretation: String
        if dpo > 60 {
            interpretation = "Extended - Good cash preservation, but monitor supplier relationships"
        } else if dpo > 45 {
            interpretation = "Moderate - Standard payment terms, balanced approach"
        } else if dpo > 30 {
            interpretation = "Standard - Typical net 30-45 terms"
        } else {
            interpretation = "Fast - Paying quickly, may miss cash management opportunities"
        }

        let output = """
        Days Payable Outstanding (DPO) Analysis:

        Inputs:
        • Average Accounts Payable: $\(formatNumber(avgPayables, decimals: 0))
        • Cost of Goods Sold: $\(formatNumber(cogs, decimals: 0))

        Result:
        • Days Payable Outstanding: \(formatNumber(dpo, decimals: 1)) days
        • Payment Frequency: \(formatNumber(365.0 / dpo, decimals: 1))x per year
        • Interpretation: \(interpretation)

        The company takes an average of \(formatNumber(dpo, decimals: 0)) days to pay suppliers.

        Note: Balance between preserving cash (higher DPO) and maintaining supplier relationships.
        """

        return .success(text: output)
    }
}

// MARK: - Cash Conversion Cycle

public struct CashConversionCycleTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cash_conversion_cycle",
        description: """
        Calculate the Cash Conversion Cycle (CCC).

        CCC measures how long cash is tied up in operations before being collected.
        Lower values indicate better working capital efficiency.

        Formula: CCC = DIO + DSO - DPO
        Where:
        • DIO = Days Inventory Outstanding
        • DSO = Days Sales Outstanding
        • DPO = Days Payable Outstanding

        Interpretation:
        • < 0 days : Exceptional - Negative cycle (collected before paying)
        • 0-30 days : Excellent - Very efficient
        • 30-60 days : Good - Healthy working capital
        • 60-90 days : Moderate - Room for improvement
        • > 90 days : Slow - Working capital constraints

        Use Cases:
        • Working capital optimization
        • Operational efficiency tracking
        • Cash flow forecasting
        • Industry benchmarking

        Example: 40 DIO + 35 DSO - 30 DPO = 45 day cash cycle
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "daysInventoryOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Days Inventory Outstanding (DIO)"
                ),
                "daysSalesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Days Sales Outstanding (DSO)"
                ),
                "daysPayableOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Days Payable Outstanding (DPO)"
                )
            ],
            required: ["daysInventoryOutstanding", "daysSalesOutstanding", "daysPayableOutstanding"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dio = try args.getDouble("daysInventoryOutstanding")
        let dso = try args.getDouble("daysSalesOutstanding")
        let dpo = try args.getDouble("daysPayableOutstanding")

        let ccc = dio + dso - dpo

        let interpretation: String
        if ccc < 0 {
            interpretation = "Exceptional - Negative cycle means collecting cash before paying suppliers"
        } else if ccc < 30 {
            interpretation = "Excellent - Very efficient working capital management"
        } else if ccc < 60 {
            interpretation = "Good - Healthy working capital cycle"
        } else if ccc < 90 {
            interpretation = "Moderate - Consider optimization opportunities"
        } else {
            interpretation = "Slow - Significant working capital tied up, review all components"
        }

        let output = """
        Cash Conversion Cycle (CCC) Analysis:

        Components:
        • Days Inventory Outstanding (DIO): \(formatNumber(dio, decimals: 1)) days
        • Days Sales Outstanding (DSO): \(formatNumber(dso, decimals: 1)) days
        • Days Payable Outstanding (DPO): \(formatNumber(dpo, decimals: 1)) days

        Result:
        • Cash Conversion Cycle: \(formatNumber(ccc, decimals: 1)) days
        • Interpretation: \(interpretation)

        Analysis:
        • Operating Cycle (DIO + DSO): \(formatNumber(dio + dso, decimals: 1)) days
        • Cash is tied up for \(formatNumber(ccc, decimals: 0)) days on average

        Improvement Strategies:
        • Reduce inventory levels (lower DIO)
        • Improve collections (lower DSO)
        • Negotiate better payment terms with suppliers (higher DPO)

        Formula: CCC = DIO + DSO - DPO
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns all working capital tools
public func getWorkingCapitalTools() -> [any MCPToolHandler] {
    return [
        DaysInventoryOutstandingTool(),
        DaysSalesOutstandingTool(),
        DaysPayableOutstandingTool(),
        CashConversionCycleTool()
    ]
}
