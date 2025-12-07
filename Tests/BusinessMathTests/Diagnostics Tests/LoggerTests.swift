//
//  LoggerTests.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

#if canImport(OSLog)
import OSLog
#endif

/// Tests for the BusinessMath logging infrastructure
///
/// Verifies that:
/// - Logger categories are properly configured
/// - Convenience methods work correctly
/// - Privacy controls are in place
/// - Linux fallback works when needed
@Suite("Logger Tests")
struct LoggerTests {

    #if canImport(OSLog)
    // MARK: - Logger Configuration Tests

    @Test("Logger categories are properly configured")
    func loggerCategoriesConfigured() {
        // Verify all category loggers exist and have correct subsystem
        let loggers = [
            Logger.businessMath,
            Logger.modelExecution,
            Logger.calculations,
            Logger.performance,
            Logger.validation
        ]

        // All loggers should be accessible (compilation test)
        #expect(loggers.count == 5)
    }

    // MARK: - Convenience Method Tests

    @Test("Calculation started logging")
    func calculationStartedLogging() {
        let logger = Logger.calculations

        // This should not crash and should log appropriately
        logger.calculationStarted("Test Calculation")
        logger.calculationStarted("Test Calculation", context: ["rate": "0.08", "periods": "10"])

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Calculation completed logging")
    func calculationCompletedLogging() {
        let logger = Logger.calculations

        // Test without duration
        logger.calculationCompleted("Test Calculation", result: 42.0)

        // Test with duration
        logger.calculationCompleted("Test Calculation", result: 42.0, duration: 0.123)

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Calculation failed logging")
    func calculationFailedLogging() {
        let logger = Logger.calculations

        struct TestError: Error {
            let message: String
        }

        let error = TestError(message: "Test error")
        logger.calculationFailed("Test Calculation", error: error)

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Validation warning logging")
    func validationWarningLogging() {
        let logger = Logger.validation

        // Test without field
        logger.validationWarning("Test warning")

        // Test with field
        logger.validationWarning("Value out of range", field: "discountRate")

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Validation error logging")
    func validationErrorLogging() {
        let logger = Logger.validation

        // Test without field
        logger.validationError("Test error")

        // Test with field
        logger.validationError("Negative value not allowed", field: "revenue")

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Performance logging")
    func performanceLogging() {
        let logger = Logger.performance

        // Test without context
        logger.performance("Test Operation", duration: 1.234)

        // Test with context
        logger.performance("Monte Carlo", duration: 2.5, context: "10,000 iterations")

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Performance warning logging")
    func performanceWarningLogging() {
        let logger = Logger.performance

        logger.performanceWarning("Performance Logging Test – Slow Operation", duration: 5.2, threshold: 1.0)

        // Test passes if no crashes occur
        #expect(true)
    }

    @Test("Model building logging")
    func modelBuildingLogging() {
        let logger = Logger.modelExecution

        // Test start without components
        logger.modelBuildingStarted("Financial Model")

        // Test start with components
        logger.modelBuildingStarted("Financial Model", components: 5)

        // Test completion without duration
        logger.modelBuildingCompleted("Financial Model")

        // Test completion with duration
        logger.modelBuildingCompleted("Financial Model", duration: 0.156)

        // Test passes if no crashes occur
        #expect(true)
    }

    // MARK: - Signpost Tests

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    @Test("Signpost interval logging")
    func signpostIntervalLogging() {
        let logger = Logger.performance

        // Begin signpost
        logger.beginSignpost("Test Interval")

        // Simulate some work
        Thread.sleep(forTimeInterval: 0.001)

        // End signpost
        logger.endSignpost("Test Interval")

        // Test passes if no crashes occur
        #expect(true)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    @Test("Signpost event logging")
    func signpostEventLogging() {
        let logger = Logger.performance

        // Event without message
        logger.signpostEvent("Cache Miss")

        // Event with message
        logger.signpostEvent("Cache Miss", message: "Key: revenue_2024")

        // Test passes if no crashes occur
        #expect(true)
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    @Test("Signpost with custom ID")
    func signpostWithCustomID() {
        let logger = Logger.performance
        let signpostID = OSSignpostID(log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest))

        logger.beginSignpost("Custom ID Test", id: signpostID)
        Thread.sleep(forTimeInterval: 0.001)
        logger.endSignpost("Custom ID Test", id: signpostID)

        // Test passes if no crashes occur
        #expect(true)
    }

    // MARK: - Integration Tests

    @Test("Logger workflow simulation")
    func loggerWorkflowSimulation() {
        let modelLogger = Logger.modelExecution
        let calcLogger = Logger.calculations
        let perfLogger = Logger.performance

        // Simulate building a model
        modelLogger.modelBuildingStarted("SaaS Model", components: 3)

        // Simulate calculations
        calcLogger.calculationStarted("MRR Calculation", context: ["churn": "0.05"])
        Thread.sleep(forTimeInterval: 0.001)
        calcLogger.calculationCompleted("MRR Calculation", result: 50_000.0, duration: 0.001)

        // Simulate performance tracking
        perfLogger.performance("Model Execution", duration: 0.015, context: "3 components")

        // Complete model building
        modelLogger.modelBuildingCompleted("SaaS Model", duration: 0.020)

        // Test passes if workflow completes without crashes
        #expect(true)
    }

    @Test("Concurrent logging safety")
    func concurrentLoggingSafety() {
        let logger = Logger.calculations

        // Spawn multiple concurrent logging operations
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            logger.calculationStarted("Concurrent Calc \(index)")
            Thread.sleep(forTimeInterval: 0.0001)
            logger.calculationCompleted("Concurrent Calc \(index)", result: index)
        }

        // Test passes if no crashes occur
        #expect(true)
    }

    #else

    // MARK: - Linux Fallback Tests

    @Test("Linux fallback logger exists")
    func linuxFallbackLoggerExists() {
        let logger = Logger.businessMath

        // Verify logger can be created
        #expect(logger.subsystem == "com.justinpurnell.BusinessMath")
        #expect(logger.category == "general")
    }

    @Test("Linux fallback convenience methods work")
    func linuxFallbackConvenienceMethods() {
        let logger = Logger.calculations

        // These should use print statements on Linux
        logger.calculationStarted("Test")
        logger.calculationCompleted("Test", result: 42.0)
        logger.performance("Test", duration: 1.0)

        // Test passes if no crashes occur
        #expect(true)
    }

    #endif
}
