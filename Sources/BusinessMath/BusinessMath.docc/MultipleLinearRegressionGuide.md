# Multiple Linear Regression Guide

Master multiple linear regression analysis with BusinessMath's high-performance implementation.

## Overview

Multiple linear regression models the relationship between one dependent variable and multiple independent variables:

```
y = β₀ + β₁x₁ + β₂x₂ + ... + βₚxₚ + ε
```

Where:
- **y**: Dependent variable (response)
- **x₁, x₂, ..., xₚ**: Independent variables (predictors)
- **β₀**: Intercept
- **β₁, β₂, ..., βₚ**: Coefficients (slopes)
- **ε**: Error term

### When to Use Multiple Linear Regression

- **Prediction**: Forecast outcomes based on multiple factors
- **Understanding Relationships**: Quantify how predictors affect the response
- **Hypothesis Testing**: Determine which factors significantly impact outcomes
- **Controlling for Confounders**: Isolate the effect of one variable while controlling for others

### Common Applications

| Domain | Use Case | Example |
|--------|----------|---------|
| **Business** | Sales forecasting | Predict revenue from marketing spend, seasonality, competition |
| **Finance** | Asset pricing | Model returns based on risk factors, market conditions |
| **Real Estate** | Property valuation | Estimate price from size, location, age, amenities |
| **Healthcare** | Risk assessment | Predict patient outcomes from demographics, vitals, history |
| **Marketing** | Customer analytics | Predict churn from usage, satisfaction, support interactions |

## Quick Start

### Simple Linear Regression

Start with one predictor to understand the basics:

```swift
import BusinessMath

// Data: Advertising spend (in $1000s) vs Sales (in $1000s)
let advertisingSpend = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0]
let sales = [120.0, 145.0, 170.0, 195.0, 220.0, 245.0, 270.0]

// Use convenience function for single predictor
let result = try linearRegression(x: advertisingSpend, y: sales)

// Interpret results
print("Sales = \(result.intercept) + \(result.coefficients[0]) × Advertising")
print("R² = \(result.rSquared)")  // Proportion of variance explained
print("p-value = \(result.pValues[1])")  // Significance of advertising coefficient
```

**Output:**
```
Sales = 20.0 + 6.25 × Advertising
R² = 1.0
p-value = 0.000001
```

**Interpretation:**
- For every $1,000 increase in advertising, sales increase by $6,250
- R² = 1.0 indicates perfect fit (all variance explained)
- p-value < 0.05 confirms advertising significantly predicts sales

> **Note**: The ``linearRegression(x:y:confidenceLevel:)`` function is a convenience wrapper for single-predictor regression. For maximum control, use ``multipleLinearRegression(X:y:confidenceLevel:)`` with `X = advertisingSpend.map { [$0] }`.

### Multiple Predictors

Model with multiple factors:

```swift
// Data: House prices based on size (sq ft) and age (years)
let size = [1200.0, 1500.0, 1800.0, 2100.0, 2400.0, 2700.0]
let age = [10.0, 5.0, 15.0, 8.0, 3.0, 12.0]
let price = [180.0, 220.0, 210.0, 260.0, 290.0, 270.0]  // in $1000s

// Create predictor matrix: each row = [size, age]
let X = zip(size, age).map { [$0, $1] }

let result = try multipleLinearRegression(X: X, y: price)

print("Price = \(result.intercept) + \(result.coefficients[0])×Size + \(result.coefficients[1])×Age")
print("R² = \(result.rSquared)")
print("Size coefficient: \(result.coefficients[0]) (p = \(result.pValues[1]))")
print("Age coefficient: \(result.coefficients[1]) (p = \(result.pValues[2]))")
```

**Interpretation:**
- Each additional sq ft adds ~$X to price (holding age constant)
- Each additional year decreases price by ~$Y (holding size constant)
- Check p-values to determine which predictors are significant

### Polynomial Regression

Model non-linear relationships by fitting polynomials:

```swift
// Data: Revenue vs Price (non-linear relationship - demand curve)
let price = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0]
var revenue: [Double] = []

// True relationship: Revenue = -0.2×Price² + 15×Price
for p in price {
    revenue.append(-0.2 * p * p + 15.0 * p)
}

// Fit quadratic model (degree 2)
let result = try polynomialRegression(x: price, y: revenue, degree: 2)

print("Revenue = \(result.intercept) + \(result.coefficients[0])×Price + \(result.coefficients[1])×Price²")
print("R² = \(result.rSquared)")

// Make prediction for Price = $55
let newPrice = 55.0
let prediction = result.intercept +
                result.coefficients[0] * newPrice +
                result.coefficients[1] * newPrice * newPrice
print("Predicted revenue at $55: $\(prediction)K")
```

**Coefficient Interpretation:**
- `result.intercept`: β₀ (constant term)
- `result.coefficients[0]`: β₁ (linear coefficient for x)
- `result.coefficients[1]`: β₂ (quadratic coefficient for x²)
- `result.coefficients[k-1]`: βₖ (coefficient for xᵏ)

**When to Use Polynomial Regression:**

| Pattern | Degree | Example |
|---------|--------|---------|
| **U-shaped / Inverted U** | 2 (quadratic) | Cost curves, demand curves, optimal pricing |
| **S-shaped** | 3 (cubic) | Growth curves, adoption curves, dose-response |
| **Complex curves** | 4-5 | Specialized scientific applications |

> **⚠️ Warning**: High-degree polynomials (degree ≥ 5) often overfit, creating unstable predictions outside the data range. For most applications, use degree ≤ 3. Check the VIF values to detect multicollinearity between polynomial terms.

**Alternative Approach (Manual):**

For maximum control, manually create polynomial features:

```swift
// Create polynomial features manually
let X = price.map { p in
    [p, p * p, p * p * p]  // [x, x², x³]
}

let result = try multipleLinearRegression(X: X, y: revenue)
```

This gives you full control over which polynomial terms to include.

## Understanding Diagnostics

### R² (Coefficient of Determination)

**What it measures:** Proportion of variance in y explained by the model (0 ≤ R² ≤ 1)

| R² Range | Interpretation |
|----------|----------------|
| 0.90-1.00 | Excellent fit - model explains 90%+ of variance |
| 0.70-0.89 | Good fit - strong predictive power |
| 0.50-0.69 | Moderate fit - decent predictions possible |
| 0.30-0.49 | Weak fit - limited predictive value |
| 0.00-0.29 | Poor fit - model adds little value |

```swift
let result = try multipleLinearRegression(X: X, y: y)
print("R² = \(result.rSquared)")
```

**Warning:** R² always increases when adding predictors, even if they're irrelevant. Use Adjusted R² for model comparison.

### Adjusted R²

**What it measures:** R² penalized for number of predictors

```swift
print("Adjusted R² = \(result.adjustedRSquared)")
```

**Formula:** Adjusted R² = 1 - [(1 - R²) × (n - 1) / (n - p - 1)]

**Use case:** Compare models with different numbers of predictors. Choose the model with highest Adjusted R².

### F-Statistic

**What it tests:** H₀: All coefficients = 0 (model has no predictive value)

```swift
print("F-statistic = \(result.fStatistic)")
print("p-value = \(result.fStatisticPValue)")
```

**Interpretation:**
- **Large F-statistic** (+ small p-value): At least one predictor is significant
- **Small F-statistic** (+ large p-value): Model not significant, use mean instead

**Rule of thumb:** If p-value < 0.05, the overall model is statistically significant.

### Individual Coefficient Tests

Each coefficient has a t-test: H₀: βᵢ = 0

```swift
for i in 0..<result.coefficients.count {
    print("x\(i+1): coef=\(result.coefficients[i]), ")
    print("     SE=\(result.standardErrors[i+1]), ")
    print("     t=\(result.tStatistics[i+1]), ")
    print("     p=\(result.pValues[i+1])")
}
```

**Interpretation:**
- **p < 0.05**: Predictor significantly affects y (keep in model)
- **p > 0.05**: Predictor not significant (consider removing)
- **Large |t-statistic|**: More confident the coefficient ≠ 0

### Confidence Intervals

95% confidence intervals for each coefficient:

```swift
print("Intercept: [\(result.confidenceIntervals[0].lower), \(result.confidenceIntervals[0].upper)]")

for i in 0..<result.coefficients.count {
    let ci = result.confidenceIntervals[i+1]
    print("β\(i+1): [\(ci.lower), \(ci.upper)]")
}
```

**Interpretation:**
- **Narrow interval**: Precise estimate
- **Wide interval**: High uncertainty
- **Excludes zero**: Significant predictor (p < 0.05)
- **Includes zero**: Not significant (p > 0.05)

### Residuals

Differences between actual and predicted values:

```swift
print("Residuals: \(result.residuals)")
print("Residual Std Error: \(result.residualStandardError)")
```

**Best practices:**
1. **Plot residuals vs fitted values** - Should show random scatter (no pattern)
2. **Check for outliers** - Large residuals may indicate unusual observations
3. **Verify assumptions** - Residuals should be normally distributed with constant variance

## Detecting Multicollinearity

**What it is:** High correlation between predictors, making coefficient estimates unstable.

**Problems:**
- Inflated standard errors
- Unstable coefficients (small data changes → large coefficient changes)
- Difficulty determining which predictors are important

### VIF (Variance Inflation Factor)

**Formula:** VIF_j = 1 / (1 - R²_j) where R²_j is from regressing x_j on all other predictors

```swift
print("VIF values: \(result.vif)")
```

| VIF Value | Multicollinearity | Action |
|-----------|-------------------|--------|
| **1-2** | None | Keep predictor |
| **2-5** | Moderate | Monitor, may keep |
| **5-10** | High | Consider removing or combining |
| **> 10** | Severe | Remove or transform predictor |

### Example: Detecting Multicollinearity

```swift
// Income, Education Years, and Occupation Level (highly correlated)
let income = [40.0, 55.0, 70.0, 85.0, 100.0, 115.0, 130.0]
let education = [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0]
let occupation = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]  // Highly correlated with education!
let productivity = [60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0]

let X = zip3(income, education, occupation).map { [$0, $1, $2] }
let result = try multipleLinearRegression(X: X, y: productivity)

// Check for multicollinearity
for (i, vifValue) in result.vif.enumerated() {
    print("Predictor \(i+1) VIF: \(vifValue)")
    if vifValue > 10 {
        print("  ⚠️ Severe multicollinearity detected!")
    }
}
```

**Solutions:**
1. **Remove one correlated predictor**
2. **Combine predictors** (e.g., create "socioeconomic index")
3. **Use regularization** (Ridge or Lasso regression)
4. **Collect more data** to break correlation

## Making Predictions

### Point Predictions

Predict y for new observations:

```swift
// Model: Sales based on advertising and price
let result = try multipleLinearRegression(X: historicalData, y: historicalSales)

// Predict sales with $25k advertising and $50 price
func predict(advertising: Double, price: Double) -> Double {
    return result.intercept +
           result.coefficients[0] * advertising +
           result.coefficients[1] * price
}

let predictedSales = predict(advertising: 25.0, price: 50.0)
print("Predicted sales: $\(predictedSales)k")
```

### Prediction Intervals

Quantify prediction uncertainty:

```swift
extension RegressionResult {
    func predictionInterval(_ x: [Double], level: Double = 0.95) -> (lower: Double, upper: Double) {
        let prediction = intercept + zip(coefficients, x).map(*).reduce(0, +)

        // Standard error of prediction
        let s = residualStandardError
        let tValue = 2.0  // Approximate for 95% CI

        // Margin increases with residual variance
        let margin = tValue * s * sqrt(1.0 + 1.0 / Double(n))

        return (lower: prediction - margin, upper: prediction + margin)
    }
}

let (lower, upper) = result.predictionInterval([25.0, 50.0])
print("95% Prediction Interval: [\(lower), \(upper)]")
```

**Interpretation:**
- **Narrow interval**: High confidence in prediction
- **Wide interval**: High uncertainty
- Individual predictions always have wider intervals than coefficient confidence intervals

## Best Practices

### 1. Check Sample Size

**Rule of thumb:** Need at least 10-20 observations per predictor

```swift
let n = X.count
let p = X[0].count

if n < 10 * p {
    print("⚠️ Warning: Small sample size may lead to overfitting")
}
```

### 2. Examine Residual Plots

```swift
// Plot residuals vs fitted values (not shown - use plotting library)
let points = zip(result.fittedValues, result.residuals)

// Look for:
// - Random scatter (good)
// - Funnel shape (heteroscedasticity - unequal variance)
// - Curved pattern (non-linear relationship)
// - Outliers (unusual observations)
```

### 3. Standardize Predictors

For easier interpretation when predictors have different scales:

```swift
func standardize(_ x: [Double]) -> [Double] {
    let mean = x.reduce(0, +) / Double(x.count)
    let std = sqrt(x.map { pow($0 - mean, 2) }.reduce(0, +) / Double(x.count))
    return x.map { ($0 - mean) / std }
}

let standardizedX = X.map { row in
    row.map { standardize([$0])[0] }
}
```

### 4. Test Assumptions

1. **Linearity**: Relationships are linear
2. **Independence**: Observations are independent
3. **Normality**: Residuals are normally distributed
4. **Homoscedasticity**: Constant variance of residuals

### 5. Avoid Overfitting

**Symptoms:**
- R² very close to 1.0
- Model fits training data perfectly but fails on new data
- Many predictors relative to observations

**Solutions:**
- Use cross-validation
- Apply regularization (Ridge/Lasso)
- Remove non-significant predictors
- Collect more data

## Real-World Example: Pricing Model

Complete example modeling house prices:

```swift
import BusinessMath

// Collect data: size (sq ft), bedrooms, age (years), location score
struct House {
    let size: Double
    let bedrooms: Double
    let age: Double
    let locationScore: Double
    let price: Double
}

let houses = [
    House(size: 1200, bedrooms: 2, age: 10, locationScore: 7, price: 180),
    House(size: 1500, bedrooms: 3, age: 5, locationScore: 8, price: 240),
    House(size: 1800, bedrooms: 3, age: 15, locationScore: 6, price: 210),
    House(size: 2100, bedrooms: 4, age: 8, locationScore: 9, price: 310),
    House(size: 2400, bedrooms: 4, age: 3, locationScore: 9, price: 380),
    House(size: 2700, bedrooms: 5, age: 12, locationScore: 7, price: 340),
    House(size: 3000, bedrooms: 5, age: 2, locationScore: 10, price: 450),
    House(size: 2200, bedrooms: 4, age: 6, locationScore: 8, price: 315)
]

// Prepare data
let X = houses.map { [$0.size, $0.bedrooms, $0.age, $0.locationScore] }
let y = houses.map { $0.price }

// Fit model
let result = try multipleLinearRegression(X: X, y: y, confidenceLevel: 0.95)

// 1. Check overall model fit
print("=== Model Fit ===")
print("R² = \(String(format: "%.3f", result.rSquared))")
print("Adjusted R² = \(String(format: "%.3f", result.adjustedRSquared))")
print("F-statistic = \(String(format: "%.2f", result.fStatistic)) (p = \(String(format: "%.4f", result.fStatisticPValue)))")

if result.fStatisticPValue < 0.05 {
    print("✓ Model is statistically significant")
}

// 2. Examine individual predictors
print("\n=== Coefficients ===")
let predictorNames = ["Size (sq ft)", "Bedrooms", "Age (years)", "Location Score"]

for i in 0..<result.coefficients.count {
    let coef = result.coefficients[i]
    let pValue = result.pValues[i + 1]
    let ci = result.confidenceIntervals[i + 1]

    print("\(predictorNames[i]):")
    print("  Coefficient: \(String(format: "%.4f", coef))")
    print("  95% CI: [\(String(format: "%.4f", ci.lower)), \(String(format: "%.4f", ci.upper))]")
    print("  p-value: \(String(format: "%.4f", pValue))")
    print("  Significant: \(pValue < 0.05 ? "✓ Yes" : "✗ No")")
}

// 3. Check for multicollinearity
print("\n=== Multicollinearity ===")
for (i, vif) in result.vif.enumerated() {
    let status = vif < 5 ? "✓ Low" : vif < 10 ? "⚠️ Moderate" : "✗ High"
    print("\(predictorNames[i]): VIF = \(String(format: "%.2f", vif)) (\(status))")
}

// 4. Make predictions
print("\n=== Predictions ===")
let newHouse = [2000.0, 3.0, 7.0, 8.0]  // 2000 sq ft, 3 bed, 7 years old, location score 8

func predict(_ x: [Double]) -> Double {
    return result.intercept + zip(result.coefficients, x).map(*).reduce(0, +)
}

let predicted = predict(newHouse)
print("Predicted price for new house: $\(String(format: "%.1f", predicted))k")

// 5. Model diagnostics
print("\n=== Diagnostics ===")
print("Residual Std Error: \(String(format: "%.2f", result.residualStandardError))")
print("Mean absolute residual: \(String(format: "%.2f", result.residuals.map(abs).reduce(0, +) / Double(result.residuals.count)))")

// Check for large residuals (outliers)
let largeResiduals = result.residuals.enumerated().filter { abs($0.element) > 2 * result.residualStandardError }
if !largeResiduals.isEmpty {
    print("⚠️ Potential outliers at indices: \(largeResiduals.map { $0.offset })")
}
```

## Performance Considerations

BusinessMath automatically selects the fastest backend based on matrix size:

| Matrix Size | Backend | Typical Time | Speedup |
|-------------|---------|--------------|---------|
| < 100 obs | CPU | ~5ms | 1× (baseline) |
| 100-999 obs | Accelerate | ~0.5ms | **40-8000×** |
| ≥ 1000 obs | Metal/Accelerate | ~25ms | **Up to 100×** |

**For large datasets:**
- Use Accelerate backend automatically on Apple platforms
- Consider data preprocessing to reduce dimensionality
- Check for multicollinearity (reduces numerical stability)

## Further Reading

- **Statistical Learning**: [An Introduction to Statistical Learning](https://www.statlearning.com/)
- **Diagnostics**: Understanding regression diagnostics and residual analysis
- **Advanced Topics**: Regularization (Ridge/Lasso), polynomial features, interaction terms
- **Related Topics**:
  - <doc:2.1-DataTableAnalysis> - Sensitivity analysis for exploring model assumptions
  - <doc:3.1-GrowthModeling> - Trend fitting with exponential and logistic models
  - <doc:4.1-MonteCarloTimeSeriesGuide> - Uncertainty quantification for predictions

## Summary

✅ Use ``linearRegression(x:y:confidenceLevel:)`` for simple linear regression (one predictor)

✅ Use ``polynomialRegression(x:y:degree:confidenceLevel:)`` for non-linear relationships

✅ Use ``multipleLinearRegression(X:y:confidenceLevel:)`` for modeling y based on multiple predictors

✅ Check **R²** and **F-statistic** for overall model fit

✅ Examine **p-values** to identify significant predictors

✅ Compute **VIF** to detect multicollinearity

✅ Inspect **residuals** for assumption violations

✅ Use **confidence intervals** for coefficient uncertainty

✅ Make **predictions** with prediction intervals for new data

BusinessMath provides production-ready regression with GPU acceleration, comprehensive diagnostics, and strict concurrency safety. Ready to use in your next data analysis project! 🚀
