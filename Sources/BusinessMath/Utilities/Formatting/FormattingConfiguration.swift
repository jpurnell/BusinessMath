//
//  FormattingConfiguration.swift
//  BusinessMath
//
//  Created for Phase 8: Floating-Point Formatting
//

import Foundation

/// Global configuration for floating-point formatting behavior.
///
/// Use this to control default formatting strategies and toggle formatted output globally.
///
/// ## Example
/// ```swift
/// // Use formatted output everywhere (default)
/// await FormattingConfiguration.setUseFormattedOutput(true)
///
/// // Disable formatting globally (show raw values)
/// await FormattingConfiguration.setUseFormattedOutput(false)
///
/// // Customize tolerance
/// await FormattingConfiguration.setDefaultTolerance(1e-10)
/// ```
@MainActor
public final class FormattingConfiguration {

    // MARK: - Global Settings

    /// Whether to use formatted output by default in print/description
    ///
    /// When `true`, `print(result)` shows formatted values.
    /// When `false`, raw floating-point values are shown.
    ///
    /// Default: `true`
    public static var useFormattedOutput: Bool = true

    /// Default tolerance for "close to integer" detection
    ///
    /// Values within this tolerance of an integer are displayed as integers.
    ///
    /// Default: `1e-8`
    public static var defaultTolerance: Double = 1e-8

    /// Default maximum decimal places to show
    ///
    /// Default: `6`
    public static var defaultMaxDecimals: Int = 6

    // MARK: - Setters (for concurrency-safe updates)

    public static func setUseFormattedOutput(_ value: Bool) {
        useFormattedOutput = value
    }

    public static func setDefaultTolerance(_ value: Double) {
        defaultTolerance = value
    }

    public static func setDefaultMaxDecimals(_ value: Int) {
        defaultMaxDecimals = value
    }

    // MARK: - Strategy Presets

    /// Default strategy for optimization results
    ///
    /// Uses context-aware formatting that adapts precision to magnitude.
    public static var optimizationStrategy: FloatingPointFormatter.Strategy {
        .contextAware(tolerance: defaultTolerance, maxDecimals: defaultMaxDecimals)
    }

    /// Default strategy for financial values
    ///
    /// Uses 4 significant figures for consistent precision.
    public static var financialStrategy: FloatingPointFormatter.Strategy {
        .significantFigures(count: 4)
    }

    /// Default strategy for probabilities
    ///
    /// Uses 3 significant figures.
    public static var probabilityStrategy: FloatingPointFormatter.Strategy {
        .significantFigures(count: 3)
    }

    /// Raw strategy (no formatting)
    ///
    /// Returns string representation of raw floating-point value.
    public static var rawStrategy: FloatingPointFormatter.Strategy {
        .custom { String(describing: $0) }
    }
}
