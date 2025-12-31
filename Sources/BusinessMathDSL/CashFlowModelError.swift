//
//  CashFlowModelError.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation

/// Errors that can occur during cash flow model construction and calculation
public enum CashFlowModelError: Error, Equatable {
    /// Parameter value is invalid for the context
    case invalidParameter(String)

    /// Seasonality factors don't sum to expected value
    case invalidSeasonality(String)

    /// Required component is missing
    case missingComponent(String)

    /// Calculation resulted in invalid state
    case calculationError(String)
}

extension CashFlowModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .invalidSeasonality(let message):
            return "Invalid seasonality: \(message)"
        case .missingComponent(let message):
            return "Missing component: \(message)"
        case .calculationError(let message):
            return "Calculation error: \(message)"
        }
    }
}
