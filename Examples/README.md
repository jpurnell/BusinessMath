# BusinessMath Library - Examples

This directory contains comprehensive examples demonstrating the BusinessMath library's capabilities.

## Quick Start

The fastest way to get started with BusinessMath:

```swift
import BusinessMath

// Create a financial model
let model = FinancialModel {
    Revenue {
        Product("SaaS Subscriptions")
            .price(99)
            .customers(1000)
    }

    Costs {
        Fixed("Salaries", 50_000)
        Variable("Cloud Costs", 0.15)
    }
}

// Calculate metrics
let profit = model.calculateProfit()
print("Profit: $\(profit)")
```

## Core Features

### 1. Financial Modeling

Build declarative financial models using a SwiftUI-style DSL:

```swift
let model = FinancialModel {
    Revenue {
        Product("Enterprise").price(999).quantity(100)
        Product("Pro").price(299).quantity(500)
        Product("Basic").price(99).quantity(2000)
    }

    Costs {
        Fixed("Engineering", 200_000)
        Fixed("Marketing", 150_000)
        Variable("Payment Processing", 0.029)
        Variable("Support", 0.05)
    }
}

let revenue = model.calculateRevenue()  // Total revenue
let costs = model.calculateCosts(revenue: revenue)  // Total costs
let profit = model.calculateProfit()  // Net profit
```

### 2. Model Inspection

Analyze and validate financial models:

```swift
let inspector = ModelInspector(model: model)

// List all components
let revenues = inspector.listRevenueSources()
let costs = inspector.listCostDrivers()

// Validate structure
let validation = inspector.validateStructure()
if !validation.isValid {
    for issue in validation.issues {
        print("Issue: \(issue)")
    }
}

// Generate comprehensive summary
print(inspector.generateSummary())
```

### 3. Calculation Tracing

Track calculation steps for debugging and documentation:

```swift
let trace = CalculationTrace(model: model)
let profit = trace.calculateProfit()

// View all calculation steps
for step in trace.steps {
    print(step.description)
}

// Or get formatted output
print(trace.formatTrace())
```

### 4. Data Export

Export models and results to CSV and JSON:

```swift
let exporter = DataExporter(model: model)

// Export to CSV
let csv = exporter.exportToCSV()
print(csv)

// Export to JSON (with optional metadata)
let json = exporter.exportToJSON(includeMetadata: true)
print(json)
```

### 5. Time Series Analysis

Work with time series data:

```swift
let sales = TimeSeries<Double>(
    periods: [.year(2021), .year(2022), .year(2023)],
    values: [100_000, 125_000, 150_000]
)

// Validate data quality
let validation = sales.validate(detectOutliers: true)
if validation.isValid {
    print("Data is clean")
}

// Export time series
let exporter = TimeSeriesExporter(series: sales)
let csv = exporter.exportToCSV()
```

### 6. Investment Analysis

Evaluate investment opportunities:

```swift
let investment = Investment {
    InitialCost(50_000)
    CashFlows {
        [
            CashFlow(period: 1, amount: 20_000),
            CashFlow(period: 2, amount: 25_000),
            CashFlow(period: 3, amount: 30_000)
        ]
    }
    DiscountRate(0.10)
}

print("NPV: $\(investment.npv)")
print("IRR: \(investment.irr! * 100)%")
print("Payback: \(investment.paybackPeriod!) periods")
```

## Complete Workflow Example

Here's a complete workflow showing how to build, validate, analyze, and export a financial model:

```swift
// 1. Build the model
let model = FinancialModel {
    Revenue {
        Product("Product A").price(100).quantity(500)
        Product("Product B").price(200).quantity(200)
    }

    Costs {
        Fixed("Salaries", 50_000)
        Fixed("Rent", 10_000)
        Variable("COGS", 0.35)
    }
}

// 2. Validate before use
let inspector = ModelInspector(model: model)
let validation = inspector.validateStructure()

guard validation.isValid else {
    print("Model validation failed:")
    for issue in validation.issues {
        print("  • \(issue)")
    }
    return
}

// 3. Calculate metrics
let profit = model.calculateProfit()
print("Profit: $\(profit)")

// 4. Trace calculations for documentation
let trace = CalculationTrace(model: model)
_ = trace.calculateProfit()
print(trace.formatTrace())

// 5. Export for reporting
let exporter = DataExporter(model: model)
let csv = exporter.exportToCSV()
let json = exporter.exportToJSON()

// Save to files
try? csv.write(toFile: "model.csv", atomically: true, encoding: .utf8)
try? json.write(toFile: "model.json", atomically: true, encoding: .utf8)
```

## Best Practices

### Always Validate Models

```swift
let inspector = ModelInspector(model: model)
let validation = inspector.validateStructure()

if validation.isValid {
    // Safe to use model
    let profit = model.calculateProfit()
} else {
    // Handle validation errors
    for issue in validation.issues {
        print("Error: \(issue)")
    }
}
```

### Use Tracing for Debugging

When calculations don't match expectations, use tracing to understand what's happening:

```swift
let trace = CalculationTrace(model: model)
let profit = trace.calculateProfit()

if profit < expectedProfit {
    print("Calculation steps:")
    for step in trace.steps {
        print("  \(step.description)")
    }
}
```

### Validate Time Series Data

Always validate time series data before analysis:

```swift
let validation = timeSeries.validate(detectOutliers: true)

if !validation.isValid {
    print("Data quality issues detected:")
    for error in validation.errors {
        print("  • \(error.message)")
    }
}
```

## Running the Examples

To run the examples in this directory:

```swift
// In your Swift file
import BusinessMath

// Run all examples
runAllExamples()

// Or run individual examples
example1_BasicFinancialModel()
example2_ModelInspection()
example3_CalculationTracing()
// etc.
```

## Performance Considerations

The library is optimized for performance:

- Models with 100+ components calculate in <1ms
- Time series with 1000+ data points validate instantly
- Export operations are memory efficient
- Thread-safe for concurrent operations

Example with large dataset:

```swift
// Build model with 100 components
var model = FinancialModel()
for i in 1...100 {
    model.revenueComponents.append(
        RevenueComponent(name: "Product \(i)", amount: Double(i * 1000))
    )
}

// Efficient calculation
let profit = model.calculateProfit()  // Completes in <1ms
```

## Error Handling

The library provides comprehensive error handling:

```swift
// Time series validation
let validation = timeSeries.validate()
if !validation.isValid {
    for error in validation.errors {
        print("\(error.severity): \(error.message)")
        print("Suggestions:")
        for suggestion in error.suggestions {
            print("  - \(suggestion)")
        }
    }
}

// Model validation
let modelValidation = inspector.validateStructure()
if !modelValidation.isValid {
    for issue in modelValidation.issues {
        print("Issue: \(issue)")
    }
}
```

## Integration with Other Tools

### Export for Excel Analysis

```swift
let exporter = DataExporter(model: model)
let csv = exporter.exportToCSV()
try csv.write(toFile: "model.csv", atomically: true, encoding: .utf8)
// Open in Excel/Numbers
```

### Export for Web Applications

```swift
let exporter = DataExporter(model: model)
let json = exporter.exportToJSON()
// Send JSON to web API or frontend
```

### Integration with Reporting Tools

```swift
let trace = CalculationTrace(model: model)
_ = trace.calculateProfit()
let report = trace.formatTrace()
// Include in PDF/HTML reports
```

## Additional Resources

- See `QuickStart.swift` for runnable examples
- All examples are tested in `DocumentationExamplesTests.swift`
- Full API documentation available in source files

## Support

For issues, questions, or feature requests, please refer to the main repository documentation.

---

© 2025 BusinessMath Library
