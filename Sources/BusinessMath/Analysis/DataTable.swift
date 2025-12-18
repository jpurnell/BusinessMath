//
//  DataTable.swift
//  BusinessMath
//
//  Created on November 23, 2025.
//

import Foundation

/// A utility for generating data tables with one or two variable inputs.
///
/// Data tables are commonly used in financial analysis to show how changes in input
/// variables affect calculated outputs. This is similar to Excel's "What-If Analysis"
/// data table feature.
///
/// ## Use Cases
///
/// - **Sensitivity Analysis**: See how NPV changes with different discount rates
/// - **Scenario Planning**: Calculate profit under various price/volume combinations
/// - **Loan Analysis**: Generate payment schedules for different rates and terms
///
/// ## Example - One Variable Table
///
/// ```swift
/// // Calculate loan payments for different interest rates
/// let rates = [0.03, 0.04, 0.05, 0.06, 0.07]
/// let table = DataTable.oneVariable(
///     inputs: rates,
///     calculate: { rate in
///         loanPayment(principal: 100_000, rate: rate, periods: 360)
///     }
/// )
///
/// for (rate, payment) in table {
///     print("Rate: \(rate * 100)%, Payment: $\(payment)")
/// }
/// ```
///
/// ## Example - Two Variable Table
///
/// ```swift
/// // Calculate profit for different price/volume combinations
/// let prices = [10.0, 12.0, 14.0, 16.0]
/// let volumes = [100, 200, 300, 400, 500]
///
/// let table = DataTable.twoVariable(
///     rowInputs: prices,
///     columnInputs: volumes,
///     calculate: { price, volume in
///         revenue(price: price, volume: Double(volume)) - costs
///     }
/// )
///
/// // table[0][0] = profit at price $10, volume 100
/// // table[3][4] = profit at price $16, volume 500
/// ```
public struct DataTable<Input, Output> {

    /// Generates a one-variable data table.
    ///
    /// Creates a table showing how the output changes as a single input variable changes.
    /// Each row in the result contains an input value and its corresponding output.
    ///
    /// - Parameters:
    ///   - inputs: Array of input values to test
    ///   - calculate: Function that calculates the output for each input
    ///
    /// - Returns: Array of tuples containing (input, output) pairs
    ///
    /// - Complexity: O(n) where n is the number of inputs
    public static func oneVariable(
        inputs: [Input],
        calculate: (Input) -> Output
    ) -> [(input: Input, output: Output)] {
        return inputs.map { input in
            (input: input, output: calculate(input))
        }
    }

    /// Generates a two-variable data table.
    ///
    /// Creates a matrix showing how the output changes as two input variables change.
    /// The result is a 2D array where:
    /// - Rows correspond to `rowInputs`
    /// - Columns correspond to `columnInputs`
    /// - `result[i][j]` = output for `rowInputs[i]` and `columnInputs[j]`
    ///
    /// - Parameters:
    ///   - rowInputs: Array of values for the first variable (rows)
    ///   - columnInputs: Array of values for the second variable (columns)
    ///   - calculate: Function that calculates the output for each input combination
    ///
    /// - Returns: 2D array of outputs, indexed by [row][column]
    ///
    /// - Complexity: O(m × n) where m is row count and n is column count
    public static func twoVariable(
        rowInputs: [Input],
        columnInputs: [Input],
        calculate: (Input, Input) -> Output
    ) -> [[Output]] {
        return rowInputs.map { rowInput in
            columnInputs.map { columnInput in
                calculate(rowInput, columnInput)
            }
        }
    }

    /// Generates a two-variable data table with different input types for rows and columns.
    ///
    /// This variant allows different types for row and column inputs, useful when
    /// analyzing combinations of different variable types (e.g., interest rates and periods).
    ///
    /// - Parameters:
    ///   - rowInputs: Array of values for the first variable (rows)
    ///   - columnInputs: Array of values for the second variable (columns)
    ///   - calculate: Function that calculates the output for each input combination
    ///
    /// - Returns: 2D array of outputs, indexed by [row][column]
    public static func twoVariableMixed<RowInput, ColumnInput>(
        rowInputs: [RowInput],
        columnInputs: [ColumnInput],
        calculate: (RowInput, ColumnInput) -> Output
    ) -> [[Output]] {
        return rowInputs.map { rowInput in
            columnInputs.map { columnInput in
                calculate(rowInput, columnInput)
            }
        }
    }
}

/// Extension providing formatted output for data tables
extension DataTable where Output: CustomStringConvertible {

    /// Formats a one-variable table as a string with aligned columns.
    ///
    /// - Parameters:
    ///   - table: The one-variable table to format
    ///   - inputHeader: Header text for the input column
    ///   - outputHeader: Header text for the output column
    ///
    /// - Returns: Formatted table as a string
    public static func formatOneVariable(
        _ table: [(input: Input, output: Output)],
        inputHeader: String = "Input",
        outputHeader: String = "Output"
    ) -> String where Input: CustomStringConvertible {
        var lines: [String] = []

        // Header
        lines.append("\(inputHeader)\t\(outputHeader)")
        lines.append(String(repeating: "-", count: 40))

        // Data rows
        for (input, output) in table {
            lines.append("\(input)\t\(output)")
        }

        return lines.joined(separator: "\n")
    }

    /// Formats a two-variable table as a matrix with row and column headers.
    ///
    /// - Parameters:
    ///   - table: The two-variable table to format
    ///   - rowInputs: Row input values for labeling
    ///   - columnInputs: Column input values for labeling
    ///
    /// - Returns: Formatted table as a string
    public static func formatTwoVariable(
        _ table: [[Output]],
        rowInputs: [Input],
        columnInputs: [Input]
    ) -> String where Input: CustomStringConvertible {
        var lines: [String] = []

        // Header row with column labels
		var headerRow = " ".padding(toLength: 16, withPad: " ", startingAt: 0)
        for colInput in columnInputs {
			headerRow += "\(colInput)".paddingLeft(toLength: 12)
        }
        lines.append(headerRow)
		lines.append(String(repeating: "=", count: columnInputs.count * 12 + 16))

        // Data rows with row labels
        for (rowIndex, rowInput) in rowInputs.enumerated() {
			var row = "\(rowInput)".padding(toLength: 16, withPad: " ", startingAt: 0)
            for colIndex in 0..<columnInputs.count {
				row += "\(table[rowIndex][colIndex])".paddingLeft(toLength: 12)
            }
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }
}

/// Extension for CSV export of data tables
extension DataTable {

    /// Exports a one-variable table to CSV format.
    ///
    /// - Parameters:
    ///   - table: The one-variable table to export
    ///   - inputHeader: Header for the input column
    ///   - outputHeader: Header for the output column
    ///
    /// - Returns: CSV formatted string
    public static func toCSV(
        _ table: [(input: Input, output: Output)],
        inputHeader: String = "Input",
        outputHeader: String = "Output"
    ) -> String where Input: CustomStringConvertible, Output: CustomStringConvertible {
        var csv = "\(inputHeader),\(outputHeader)\n"

        for (input, output) in table {
            csv += "\(input),\(output)\n"
        }

        return csv
    }

    /// Exports a two-variable table to CSV format.
    ///
    /// - Parameters:
    ///   - table: The two-variable table to export
    ///   - rowInputs: Row input values for labeling
    ///   - columnInputs: Column input values for labeling
    ///
    /// - Returns: CSV formatted string
    public static func toCSV(
        _ table: [[Output]],
        rowInputs: [Input],
        columnInputs: [Input]
    ) -> String where Input: CustomStringConvertible, Output: CustomStringConvertible {
        var csv = ""

        // Header row
        csv += ","
        for colInput in columnInputs {
            csv += "\(colInput),"
        }
        csv += "\n"

        // Data rows
        for (rowIndex, rowInput) in rowInputs.enumerated() {
            csv += "\(rowInput),"
            for colIndex in 0..<columnInputs.count {
                csv += "\(table[rowIndex][colIndex]),"
            }
            csv += "\n"
        }

        return csv
    }
}
