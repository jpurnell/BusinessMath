#!/usr/bin/env swift
import Foundation

// Example showing how to inspect fitted model parameters
// Run with: swift run

/*
 This example demonstrates how to:
 1. Fit linear and exponential trend models
 2. Inspect their fitted parameters
 3. Compare forecasts and error metrics
 4. Debug why models might produce identical results
*/

print("📊 Model Inspection Example")
print("=" * 60)
print()

// Example usage once BusinessMath is built:
/*
import BusinessMath

let periods = (1...10).map { Period.month(year: 2024, month: $0) }
let values: [Double] = [100, 105, 112, 118, 125, 133, 140, 148, 156, 165]
let historical = TimeSeries(periods: periods, values: values)

// Split into train/test
let trainData = historical.range(from: periods[0], to: periods[7])
let testData = historical.range(from: periods[8], to: periods[9])

// Fit linear model
var linearModel = LinearTrend<Double>()
try linearModel.fit(to: trainData)

// Fit exponential model
var exponentialModel = ExponentialTrend<Double>()
try exponentialModel.fit(to: trainData)

print("Linear Model Parameters:")
print("  Slope: \(linearModel.slopeValue ?? 0)")
print("  Intercept: \(linearModel.interceptValue ?? 0)")
print("  \(linearModel.summary)")
print()

print("Exponential Model Parameters:")
print("  Log Slope: \(exponentialModel.logSlope ?? 0)")
print("  Log Intercept: \(exponentialModel.logIntercept ?? 0)")
print("  Growth Rate: \((exponentialModel.growthRate ?? 0) * 100)% per period")
print("  \(exponentialModel.summary)")
print()

// Generate forecasts
let linearForecast = try linearModel.project(periods: 2)
let exponentialForecast = try exponentialModel.project(periods: 2)

print("Forecasts:")
print("  Linear: \(linearForecast.valuesArray)")
print("  Exponential: \(exponentialForecast.valuesArray)")
print()

// Calculate error metrics
let linearMetrics = testData.forecastError(against: linearForecast)
let expMetrics = testData.forecastError(against: exponentialForecast)

print("Error Metrics:")
print("  Linear Model:")
print("    RMSE: \(linearMetrics.rmse)")
print("    MAE:  \(linearMetrics.mae)")
print("    MAPE: \(linearMetrics.mape)%")
print()
print("  Exponential Model:")
print("    RMSE: \(expMetrics.rmse)")
print("    MAE:  \(expMetrics.mae)")
print("    MAPE: \(expMetrics.mape)%")
print()

// Debug: Compare if forecasts are identical
if linearForecast.valuesArray == exponentialForecast.valuesArray {
    print("⚠️  WARNING: Forecasts are identical!")
    print("    This suggests the models fitted the same parameters.")
    print("    Check:")
    print("    - Is your data actually linear? (constant differences)")
    print("    - Does exponential model degrade to linear for small growth rates?")
    print("    - Are there numerical precision issues?")
} else {
    print("✓ Forecasts are different (as expected)")
}

// If metrics are identical despite different forecasts, it means:
if linearMetrics.rmse == expMetrics.rmse &&
   linearMetrics.mae == expMetrics.mae &&
   linearMetrics.mape == expMetrics.mape {
    print()
    print("⚠️  WARNING: Error metrics are identical!")
    print("    Despite different forecasts, both models have same error.")
    print("    This is rare but can happen if:")
    print("    - Errors perfectly cancel out (unlikely)")
    print("    - Test data is too small")
    print("    - Numerical precision limits")
}
*/

print("To run this example:")
print("1. Build the package: swift build")
print("2. Uncomment the code above")
print("3. Run: swift run inspect_models_example")
print()
print("Quick debugging checklist:")
print("✓ Check model parameters are different")
print("✓ Verify forecasts are different")
print("✓ Ensure test data overlaps forecast periods")
print("✓ Look at actual vs forecast values visually")
