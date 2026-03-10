//
//  DCFModel.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - DCF Model Components

/// Integrates an existing `CashFlowModel` into DCF valuation.
///
/// Wraps a cash flow model with a forecast period for enterprise value calculation.
public struct FromCashFlowModel {
    /// The underlying cash flow model providing revenue, expense, and tax projections.
    public let model: CashFlowModel
    /// The number of years to forecast.
    public let years: Int

    /// Creates a DCF integration from an existing cash flow model.
    ///
    /// - Parameters:
    ///   - model: The cash flow model to use for free cash flow projections.
    ///   - years: The number of forecast years (must be positive).
    public init(_ model: CashFlowModel, years: Int) {
        guard years > 0 else {
            fatalError("Forecast years must be positive: \(years)")
        }
        self.model = model
        self.years = years
    }
}

// MARK: - Valuation Result

/// Result of DCF valuation with detailed metrics.
///
/// Contains enterprise value, present value components, and supporting data.
public struct ValuationResult {
    /// Total enterprise value (PV of FCF + PV of terminal value).
    public let enterpriseValue: Double
    /// Present value of forecasted free cash flows.
    public let presentValueOfFCF: Double
    /// Present value of the terminal value.
    public let presentValueOfTerminalValue: Double
    /// Undiscounted terminal value at the end of the forecast period.
    public let terminalValue: Double
    /// Number of years in the forecast period.
    public let forecastYears: Int
    /// Weighted average cost of capital used for discounting.
    public let wacc: Double
    /// Exit multiple applied (for exit multiple method), or 0 for perpetual growth.
    public let terminalValueMultiple: Double
    /// Array of free cash flows for each forecast year.
    public let freeCashFlows: [Double]

    /// Creates a valuation result with all DCF metrics.
    ///
    /// - Parameters:
    ///   - enterpriseValue: Total enterprise value.
    ///   - presentValueOfFCF: Present value of free cash flows.
    ///   - presentValueOfTerminalValue: Present value of terminal value.
    ///   - terminalValue: Undiscounted terminal value.
    ///   - forecastYears: Number of forecast years.
    ///   - wacc: Discount rate used.
    ///   - terminalValueMultiple: Exit multiple (if applicable).
    ///   - freeCashFlows: Array of projected free cash flows.
    public init(
        enterpriseValue: Double,
        presentValueOfFCF: Double,
        presentValueOfTerminalValue: Double,
        terminalValue: Double,
        forecastYears: Int,
        wacc: Double,
        terminalValueMultiple: Double = 0,
        freeCashFlows: [Double] = []
    ) {
        self.enterpriseValue = enterpriseValue
        self.presentValueOfFCF = presentValueOfFCF
        self.presentValueOfTerminalValue = presentValueOfTerminalValue
        self.terminalValue = terminalValue
        self.forecastYears = forecastYears
        self.wacc = wacc
        self.terminalValueMultiple = terminalValueMultiple
        self.freeCashFlows = freeCashFlows
    }
}

// MARK: - DCF Model

/// Discounted Cash Flow valuation model.
///
/// Combines forecast assumptions, terminal value, and WACC to calculate enterprise value.
public struct DCFModel {
    /// The revenue and cost forecast for the projection period.
    public let forecast: Forecast?
    /// The terminal value configuration (perpetual growth or exit multiple).
    public let terminalValue: TerminalValue?
    /// The weighted average cost of capital for discounting.
    public let wacc: WACC?
    /// An existing cash flow model to integrate (alternative to Forecast).
    public let cashFlowModel: FromCashFlowModel?

    internal init(
        forecast: Forecast? = nil,
        terminalValue: TerminalValue? = nil,
        wacc: WACC? = nil,
        cashFlowModel: FromCashFlowModel? = nil
    ) {
        self.forecast = forecast
        self.terminalValue = terminalValue
        self.wacc = wacc
        self.cashFlowModel = cashFlowModel
    }

    /// Create DCF model using result builder
    public init(@DCFModelBuilder content: () -> DCFModel) {
        self = content()
    }

    /// Calculate enterprise value using DCF methodology
    /// - Returns: Detailed valuation result
    public func calculateEnterpriseValue() -> ValuationResult {
        guard let terminalValue = terminalValue,
              let wacc = wacc else {
            fatalError("DCF model requires terminal value and WACC")
        }

        let waccRate = wacc.rate

        // Get free cash flows
        let fcfs: [Double]
        let years: Int
        let finalEBITDA: Double

        if let forecast = forecast {
            fcfs = forecast.freeCashFlows
            years = forecast.years
            finalEBITDA = forecast.finalEBITDA
        } else if let cfModel = cashFlowModel {
            // Extract FCFs from CashFlowModel
            fcfs = (1...cfModel.years).map { year in
                cfModel.model.freeCashFlow(year: year)
            }
            years = cfModel.years
            // Estimate final EBITDA from net income
            let finalResult = cfModel.model.calculate(year: years)
            finalEBITDA = finalResult.ebitda
        } else {
            fatalError("DCF model requires either Forecast or CashFlowModel")
        }

        // Calculate present value of forecasted cash flows
        var pvOfFCF: Double = 0
        for (index, fcf) in fcfs.enumerated() {
            let year = index + 1
            let discountFactor = pow(1.0 + waccRate, Double(year))
            pvOfFCF += fcf / discountFactor
        }

        // Calculate terminal value
        let tv: Double
        let tvMultiple: Double

        switch terminalValue.method {
        case .perpetualGrowth(_):
            let finalFCF = fcfs.last ?? 0
            tv = terminalValue.calculate(finalFCF: finalFCF, wacc: waccRate)
            tvMultiple = 0  // Not applicable for perpetual growth

        case .exitMultiple(let multiple):
            tv = terminalValue.calculate(finalEBITDA: finalEBITDA)
            tvMultiple = multiple.evEbitda
        }

        // Discount terminal value to present
        let terminalYearDiscountFactor = pow(1.0 + waccRate, Double(years))
        let pvOfTerminalValue = tv / terminalYearDiscountFactor

        // Enterprise Value = PV(FCF) + PV(TV)
        let enterpriseValue = pvOfFCF + pvOfTerminalValue

        return ValuationResult(
            enterpriseValue: enterpriseValue,
            presentValueOfFCF: pvOfFCF,
            presentValueOfTerminalValue: pvOfTerminalValue,
            terminalValue: tv,
            forecastYears: years,
            wacc: waccRate,
            terminalValueMultiple: tvMultiple,
            freeCashFlows: fcfs
        )
    }
}

// MARK: - DCF Model Result Builder

/// Result builder for constructing `DCFModel` instances declaratively.
///
/// Allows composing forecast, terminal value, and WACC components using Swift's result builder syntax.
@resultBuilder
public struct DCFModelBuilder {
    /// Builds a DCF model from the provided components.
    ///
    /// - Parameter components: The forecast, terminal value, WACC, and cash flow model components.
    /// - Returns: A configured `DCFModel`.
    public static func buildBlock(_ components: DCFModelComponent...) -> DCFModel {
        var forecast: Forecast? = nil
        var terminalValue: TerminalValue? = nil
        var wacc: WACC? = nil
        var cashFlowModel: FromCashFlowModel? = nil

        for component in components {
            switch component {
            case .forecast(let f):
                forecast = f
            case .terminalValue(let tv):
                terminalValue = tv
            case .wacc(let w):
                wacc = w
            case .cashFlowModel(let cfm):
                cashFlowModel = cfm
            }
        }

        return DCFModel(
            forecast: forecast,
            terminalValue: terminalValue,
            wacc: wacc,
            cashFlowModel: cashFlowModel
        )
    }

    /// Converts a `Forecast` to a DCF model component.
    public static func buildExpression(_ expression: Forecast) -> DCFModelComponent {
        .forecast(expression)
    }

    /// Converts a `TerminalValue` to a DCF model component.
    public static func buildExpression(_ expression: TerminalValue) -> DCFModelComponent {
        .terminalValue(expression)
    }

    /// Converts a `WACC` to a DCF model component.
    public static func buildExpression(_ expression: WACC) -> DCFModelComponent {
        .wacc(expression)
    }

    /// Converts a `FromCashFlowModel` to a DCF model component.
    public static func buildExpression(_ expression: FromCashFlowModel) -> DCFModelComponent {
        .cashFlowModel(expression)
    }
}

// MARK: - DCF Model Component Protocol

/// Represents a component that can be used in a DCF model builder.
///
/// Cases correspond to forecast, terminal value, WACC, and cash flow model integration.
public enum DCFModelComponent {
    case forecast(Forecast)
    case terminalValue(TerminalValue)
    case wacc(WACC)
    case cashFlowModel(FromCashFlowModel)
}
