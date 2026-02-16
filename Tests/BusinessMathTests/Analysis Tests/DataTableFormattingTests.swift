//
//  DataTableFormattingTests.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("DataTable Formatting")
struct DataTableFormattingTests {

    @Test("Two-variable table with custom formatting")
    func twoVariableTableCustomFormatting() {
        let rowInputs = [500.0, 1_000.0]
        let columnInputs = [250.0, 500.0]

        let table = DataTable<Double, Double>.twoVariable(
            rowInputs: rowInputs,
            columnInputs: columnInputs,
            calculate: { input, output in
                // Simple cost calculation
                input * 0.000003 + output * 0.000015
            }
        )

        // Format with 4 decimal places using .number(4)
        let formatted = DataTable<Double, Double>.formatTwoVariable(
            table,
            rowInputs: rowInputs,
            columnInputs: columnInputs,
            formatOutput: { $0.number(4) }
        )

        // Check that output contains properly formatted numbers
        #expect(formatted.contains("0.0053"))  // 500 * 0.000003 + 250 * 0.000015
        #expect(formatted.contains("0.0090"))  // 500 * 0.000003 + 500 * 0.000015
        #expect(formatted.contains("0.0068"))  // 1000 * 0.000003 + 250 * 0.000015
        #expect(formatted.contains("0.0105"))  // 1000 * 0.000003 + 500 * 0.000015

        // Check that it doesn't contain raw double representation
        #expect(!formatted.contains("9999999"))  // No long decimal strings
    }

    @Test("Two-variable table with currency formatting")
    func twoVariableTableCurrencyFormatting() {
        let prices = [10.0, 20.0]
        let quantities = [100.0, 200.0]

        let table = DataTable<Double, Double>.twoVariable(
            rowInputs: prices,
            columnInputs: quantities,
            calculate: { price, quantity in
                price * quantity
            }
        )

        // Format as currency
        let formatted = DataTable<Double, Double>.formatTwoVariable(
            table,
            rowInputs: prices,
            columnInputs: quantities,
            formatOutput: { $0.currency(2) }
        )

        // Check that output contains currency symbols
        #expect(formatted.contains("$1,000.00"))  // 10 * 100
        #expect(formatted.contains("$2,000.00"))  // 10 * 200
        #expect(formatted.contains("$4,000.00"))  // 20 * 200
    }

    @Test("Two-variable table default formatting still works")
    func twoVariableTableDefaultFormatting() {
        let rowInputs = ["A", "B"]
        let columnInputs = ["X", "Y"]

        let table = DataTable<String, String>.twoVariable(
            rowInputs: rowInputs,
            columnInputs: columnInputs,
            calculate: { r, c in
                "\(r)\(c)"
            }
        )

        // Use default formatting (no formatOutput parameter)
        let formatted = DataTable<String, String>.formatTwoVariable(
            table,
            rowInputs: rowInputs,
            columnInputs: columnInputs
        )

        // Check that output contains expected strings
        #expect(formatted.contains("AX"))
        #expect(formatted.contains("AY"))
        #expect(formatted.contains("BX"))
        #expect(formatted.contains("BY"))
    }

    @Test("Two-variable table with percentage formatting")
    func twoVariableTablePercentageFormatting() {
        let rowInputs = [0.05, 0.10]
        let columnInputs = [0.02, 0.03]

        let table = DataTable<Double, Double>.twoVariable(
            rowInputs: rowInputs,
            columnInputs: columnInputs,
            calculate: { r, c in
                r + c  // Sum of percentages
            }
        )

        // Format as percentage
        let formatted = DataTable<Double, Double>.formatTwoVariable(
            table,
            rowInputs: rowInputs,
            columnInputs: columnInputs,
            formatOutput: { $0.percent(1) }
        )

        // Check that output contains percentage symbols
        #expect(formatted.contains("%"))
        #expect(formatted.contains("7.0%"))   // (0.05 + 0.02) * 100
        #expect(formatted.contains("8.0%"))   // (0.05 + 0.03) * 100
        #expect(formatted.contains("12.0%"))  // (0.10 + 0.02) * 100
        #expect(formatted.contains("13.0%"))  // (0.10 + 0.03) * 100
    }
}
