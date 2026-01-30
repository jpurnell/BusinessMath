import Testing
import Foundation
@testable import BusinessMath

@Suite("Floating Point Formatter Tests")
struct FloatingPointFormatterTests {

    // MARK: - Smart Rounding Strategy Tests

    @Test("Smart rounding snaps to integer within tolerance")
    func testSmartRoundingInteger() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding(tolerance: 1e-8))

        // Should snap to nearest integer
        let result1 = formatter.format(2.9999999999999964)
        #expect(result1.formatted == "3")
        #expect(result1.rawValue == 2.9999999999999964)

        let result2 = formatter.format(3.0000000000000004)
        #expect(result2.formatted == "3")

        let result3 = formatter.format(99.99999999999999)
        #expect(result3.formatted == "100")
    }

    @Test("Smart rounding preserves real decimals")
    func testSmartRoundingDecimals() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding(tolerance: 1e-8))

        // Should keep actual decimal values
        let result1 = formatter.format(0.7500000000000002)
        #expect(result1.formatted == "0.75")

        let result2 = formatter.format(3.14159265)
        #expect(result2.formatted.hasPrefix("3.14159"))

        let result3 = formatter.format(2.5)
        #expect(result3.formatted == "2.5")
    }

    @Test("Smart rounding treats tiny values as zero")
    func testSmartRoundingZero() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding(tolerance: 1e-8))

        let result1 = formatter.format(1.2345678901234567e-15)
        #expect(result1.formatted == "0")

        let result2 = formatter.format(0.0)
        #expect(result2.formatted == "0")

        let result3 = formatter.format(-1e-10)
        #expect(result3.formatted == "0")
    }

    @Test("Smart rounding removes trailing zeros")
    func testSmartRoundingTrailingZeros() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding(tolerance: 1e-8))

        let result1 = formatter.format(1.5000)
        #expect(result1.formatted == "1.5")

        let result2 = formatter.format(2.1000000)
        #expect(result2.formatted == "2.1")
    }

    // MARK: - Significant Figures Strategy Tests

    @Test("Significant figures with 3 digits")
    func testSignificantFigures3() throws {
        let formatter = FloatingPointFormatter(strategy: .significantFigures(count: 3))

        #expect(formatter.format(123456.789).formatted == "123000")
        #expect(formatter.format(1.23456789).formatted == "1.23")
        #expect(formatter.format(0.00123456789).formatted == "0.00123")
    }

    @Test("Significant figures with 4 digits")
    func testSignificantFigures4() throws {
        let formatter = FloatingPointFormatter(strategy: .significantFigures(count: 4))

        #expect(formatter.format(123456.789).formatted == "123500")
        #expect(formatter.format(1.23456789).formatted == "1.235")
        #expect(formatter.format(0.00123456789).formatted == "0.001235")
    }

    @Test("Significant figures handles zero")
    func testSignificantFiguresZero() throws {
        let formatter = FloatingPointFormatter(strategy: .significantFigures(count: 3))
        #expect(formatter.format(0.0).formatted == "0")
    }

    // MARK: - Context-Aware Strategy Tests

    @Test("Context-aware adapts to magnitude")
    func testContextAwareAdaptation() throws {
        let formatter = FloatingPointFormatter(strategy: .contextAware())

        // Large values - fewer decimals
        let large = formatter.format(12345.6789)
        #expect(large.formatted.contains("12345"))

        // Medium values - moderate decimals
        let medium = formatter.format(123.456)
        #expect(medium.formatted.contains("123."))

        // Small values - more decimals
        let small = formatter.format(0.00123)
        #expect(small.formatted.contains("0.0012"))
    }

    @Test("Context-aware snaps to integers")
    func testContextAwareIntegers() throws {
        let formatter = FloatingPointFormatter(strategy: .contextAware())

        let result = formatter.format(2.9999999999999964)
        #expect(result.formatted == "3")
    }

    // MARK: - Edge Cases

    @Test("Handles infinity")
    func testInfinity() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        let posInf = formatter.format(Double.infinity)
        #expect(posInf.formatted.lowercased().contains("inf"))

        let negInf = formatter.format(-Double.infinity)
        #expect(negInf.formatted.lowercased().contains("inf"))
    }

    @Test("Handles NaN")
    func testNaN() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        let result = formatter.format(Double.nan)
        #expect(result.formatted.lowercased().contains("nan"))
    }

    @Test("Handles negative numbers")
    func testNegativeNumbers() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        #expect(formatter.format(-2.9999999999999964).formatted == "-3")
        #expect(formatter.format(-0.75).formatted == "-0.75")
        #expect(formatter.format(-1e-15).formatted == "0")  // Tiny negative rounds to 0
    }

    @Test("Handles very large numbers")
    func testVeryLargeNumbers() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        let result = formatter.format(1.23e15)
        #expect(result.formatted.contains("e") || result.formatted.count > 10)
    }

    @Test("Handles very small numbers")
    func testVerySmallNumbers() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        // Very small should become zero or use scientific notation
        let result = formatter.format(1.23e-15)
        #expect(result.formatted == "0" || result.formatted.contains("e"))
    }

    // MARK: - Array Formatting

    @Test("Format array of values")
    func testArrayFormatting() throws {
        let formatter = FloatingPointFormatter(strategy: .smartRounding())

        let values = [2.9999999999999964, 3.0000000000000004, 0.75, 1e-15]
        let results = formatter.format(values)

        #expect(results.count == 4)
        #expect(results[0].formatted == "3")
        #expect(results[1].formatted == "3")  // Also within tolerance
        #expect(results[2].formatted == "0.75")
        #expect(results[3].formatted == "0")
    }

    // MARK: - Custom Strategy

    @Test("Custom formatting strategy")
    func testCustomStrategy() throws {
        let customFormat: @Sendable (Double) -> String = { value in
			"CUSTOM: \(value.number(2))"
        }

        let formatter = FloatingPointFormatter(strategy: .custom(customFormat))
        let result = formatter.format(3.14159)
        #expect(result.formatted == "CUSTOM: 3.14")
    }
}
