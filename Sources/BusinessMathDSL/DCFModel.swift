//
//  DCFModel.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - DCF Model Components

/// Integrate existing CashFlowModel into DCF valuation
public struct FromCashFlowModel {
    public let model: CashFlowModel
    public let years: Int

    public init(_ model: CashFlowModel, years: Int) {
        guard years > 0 else {
            fatalError("Forecast years must be positive: \(years)")
        }
        self.model = model
        self.years = years
    }
}

// MARK: - Valuation Result

/// Result of DCF valuation with detailed metrics
public struct ValuationResult {
    public let enterpriseValue: Double
    public let presentValueOfFCF: Double
    public let presentValueOfTerminalValue: Double
    public let terminalValue: Double
    public let forecastYears: Int
    public let wacc: Double
    public let terminalValueMultiple: Double
    public let freeCashFlows: [Double]

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

/// Discounted Cash Flow valuation model
public struct DCFModel {
    public let forecast: Forecast?
    public let terminalValue: TerminalValue?
    public let wacc: WACC?
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

@resultBuilder
public struct DCFModelBuilder {
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

    public static func buildExpression(_ expression: Forecast) -> DCFModelComponent {
        .forecast(expression)
    }

    public static func buildExpression(_ expression: TerminalValue) -> DCFModelComponent {
        .terminalValue(expression)
    }

    public static func buildExpression(_ expression: WACC) -> DCFModelComponent {
        .wacc(expression)
    }

    public static func buildExpression(_ expression: FromCashFlowModel) -> DCFModelComponent {
        .cashFlowModel(expression)
    }
}

// MARK: - DCF Model Component Protocol

public enum DCFModelComponent {
    case forecast(Forecast)
    case terminalValue(TerminalValue)
    case wacc(WACC)
    case cashFlowModel(FromCashFlowModel)
}
