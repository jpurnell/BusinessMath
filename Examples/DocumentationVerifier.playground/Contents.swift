import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Historical monthly sales (2 years)
	let months = (1...24).map { Period.month(year: 2023 + ($0 - 1) / 12, month: (($0 - 1) % 12) + 1) }
	let sales: [Double] = [
		// Year 1
		100, 110, 95, 105, 115, 125, 140, 135, 120, 110, 130, 150,
		// Year 2
		105, 115, 100, 110, 120, 130, 145, 140, 125, 115, 135, 155
	]

	let salesTimeSeries = TimeSeries(
		periods: months,
		values: sales,
		metadata: TimeSeriesMetadata(name: "Monthly Sales", unit: "Units")
	)

	// Create Holt-Winters model
	let model = HoltWintersModel(
		alpha: 0.2,  // Level smoothing
		beta: 0.1,   // Trend smoothing
		gamma: 0.1,  // Seasonal smoothing
		seasonalPeriods: 12  // Monthly data with annual seasonality
	)

	// Generate forecast
	let forecast = model.predict(
//		timeSeries: salesTimeSeries,
		periods: 6  // Predict next 6 months
	)

	print("6-month forecast:")
	for (period, value) in zip(forecast.periods, forecast.valuesArray) {
		print("\(period.label): \(Int(value)) units")
	}
