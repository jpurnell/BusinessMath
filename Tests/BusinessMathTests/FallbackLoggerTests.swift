import Foundation
import Testing
@testable import BusinessMath

/// The logger used where OSLog is absent — exercised on macOS, which is the point.
///
/// This type spent ten months behind `#else` of `canImport(OSLog)`: complete, documented,
/// and never once compiled, because no macOS build reached it. Its primitives took a
/// `String` while every call site in this package writes `\(value, privacy: .public)`, so
/// Linux builds failed against the very file written to keep them working.
///
/// It is compiled on every platform now, so these tests run here.
@Suite("Fallback logger")
struct FallbackLoggerTests {

    @Test("A privacy-annotated interpolation renders its value")
    func privacyInterpolationRenders() {
        let name = "npv"
        let message: BusinessMathLogMessage = "Starting calculation: \(name, privacy: .public)"
        #expect(message.rendered == "Starting calculation: npv")
    }

    @Test("A private annotation is accepted and does not redact")
    func privateAnnotationAccepted() {
        let secret = "1234"
        #expect(BusinessMathLogMessage("acct \(secret, privacy: .private)").rendered == "acct 1234")
    }

    @Test("format: .fixed(precision:) rounds to the requested fraction digits")
    func fixedPrecisionFormatting() {
        let duration = 0.0421999
        let message: BusinessMathLogMessage = "in \(duration, format: .fixed(precision: 3), privacy: .public)s"
        #expect(message.rendered == "in 0.042s")
    }

    @Test("A non-numeric value with a format is rendered, not dropped")
    func formatOnNonNumberFallsBack() {
        let label = "n/a"
        #expect(BusinessMathLogMessage("\(label, format: .fixed(precision: 2))").rendered == "n/a")
    }

    @Test("Every severity the package calls exists on the fallback")
    func allSeveritiesExist() {
        let logger = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "test")
        let value = 1
        logger.debug("d \(value, privacy: .public)")
        logger.info("i \(value, privacy: .public)")
        logger.notice("n \(value, privacy: .public)")
        logger.warning("w \(value, privacy: .public)")
        logger.error("e \(value, privacy: .public)")
        logger.trace("t \(value, privacy: .public)")
        #expect(logger.category == "test")
    }

    @Test("The category loggers exist and carry their categories")
    func categoryLoggersExist() {
        #expect(BusinessMathFallbackLogger.shared.category == "general")
        #expect(BusinessMathFallbackLogger.calculations.category == "calculations")
        #expect(BusinessMathFallbackLogger.performance.category == "performance")
        #expect(BusinessMathFallbackLogger.validation.category == "validation")
        #expect(BusinessMathFallbackLogger.modelExecution.category == "model-execution")
    }

    @Test("A String-taking convenience method still accepts a runtime String")
    func convenienceMethodsTakeStrings() {
        let logger = BusinessMathFallbackLogger.validation
        logger.validationWarning("value out of range", field: "rate")
        logger.validationWarning("value out of range")
        #expect(logger.category == "validation")
    }
}
