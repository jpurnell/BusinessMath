import Testing
import Foundation
@testable import BusinessMath

/// Test suite for operational metrics tracking
@Suite("Operational Metrics Tests")
struct OperationalMetricsTests {

	// MARK: - Basic Operations

	@Test("Create operational metrics for e-commerce company")
	func testEcommerceMetrics() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"units_sold": 15_000,
				"average_order_value": 85.50,
				"active_customers": 12_500,
				"conversion_rate": 0.032
			]
		)

		#expect(metrics["units_sold"] == 15_000)
		#expect(metrics["average_order_value"] == 85.50)
		#expect(metrics["active_customers"] == 12_500)
		#expect(metrics["conversion_rate"] == 0.032)
	}

	@Test("Create operational metrics for SaaS company")
	func testSaaSMetrics() throws {
		let entity = Entity(id: "SAAS", primaryType: .ticker, name: "CloudCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"monthly_recurring_revenue": 2_500_000,
				"customer_count": 850,
				"net_revenue_retention": 1.15,
				"customer_acquisition_cost": 12_000,
				"churn_rate": 0.02
			]
		)

		#expect(metrics["monthly_recurring_revenue"] == 2_500_000)
		#expect(metrics["customer_count"] == 850)
		#expect(metrics["net_revenue_retention"] == 1.15)
	}

	@Test("Create operational metrics for oil & gas company")
	func testOilGasMetrics() throws {
		let entity = Entity(id: "OIL", primaryType: .ticker, name: "OilCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"production_boe_per_day": 125_000,
				"realized_price_per_boe": 68.50,
				"wells_drilled": 12,
				"lifting_cost_per_boe": 18.25,
				"proved_reserves_mboe": 1_250_000
			]
		)

		#expect(metrics["production_boe_per_day"] == 125_000)
		#expect(metrics["realized_price_per_boe"] == 68.50)
		#expect(metrics["wells_drilled"] == 12)
	}

	// MARK: - Derived Metrics

	@Test("Calculate derived metric - revenue per customer")
	func testDerivedMetricRevenuePerCustomer() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"total_revenue": 1_000_000,
				"customer_count": 5_000
			]
		)

		let revenuePerCustomer = metrics.derived(
			numerator: "total_revenue",
			denominator: "customer_count"
		)

		#expect(revenuePerCustomer == 200.0, "Revenue per customer should be $200")
	}

	@Test("Calculate derived metric - cost per unit")
	func testDerivedMetricCostPerUnit() throws {
		let entity = Entity(id: "MFG", primaryType: .ticker, name: "ManufactureCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"total_production_cost": 500_000,
				"units_produced": 25_000
			]
		)

		let costPerUnit = metrics.derived(
			numerator: "total_production_cost",
			denominator: "units_produced"
		)

		#expect(costPerUnit == 20.0, "Cost per unit should be $20")
	}

	@Test("Derived metric returns nil for division by zero")
	func testDerivedMetricDivisionByZero() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "TestCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"revenue": 1_000_000,
				"customers": 0
			]
		)

		let revenuePerCustomer = metrics.derived(
			numerator: "revenue",
			denominator: "customers"
		)

		#expect(revenuePerCustomer == nil, "Should return nil when dividing by zero")
	}

	@Test("Derived metric returns nil for missing metric")
	func testDerivedMetricMissing() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "TestCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"revenue": 1_000_000
			]
		)

		let revenuePerCustomer = metrics.derived(
			numerator: "revenue",
			denominator: "customers"
		)

		#expect(revenuePerCustomer == nil, "Should return nil when metric is missing")
	}

	// MARK: - Metadata

	@Test("Operational metrics with metadata")
	func testMetricsWithMetadata() throws {
		let entity = Entity(id: "SAAS", primaryType: .ticker, name: "CloudCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		var metadata = OperationalMetricsMetadata()
		metadata.industry = "SaaS"
		metadata.businessModel = "Subscription-based B2B software"
		metadata.metricDefinitions = [
			"monthly_recurring_revenue": "Recurring revenue normalized to monthly basis",
			"net_revenue_retention": "Revenue retention from cohort including upsells/downsells"
		]

		let metrics = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"monthly_recurring_revenue": 2_500_000,
				"net_revenue_retention": 1.15
			],
			metadata: metadata
		)

		#expect(metrics.metadata?.industry == "SaaS")
		#expect(metrics.metadata?.businessModel == "Subscription-based B2B software")
		#expect(metrics.metadata?.metricDefinitions?["monthly_recurring_revenue"] != nil)
	}

	// MARK: - Time Series

	@Test("Create time series from operational metrics")
	func testTimeSeriesCreation() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let quarters = Period.year(2025).quarters()

		let metricsList = [
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[0],
				metrics: ["units_sold": 10_000, "revenue": 850_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[1],
				metrics: ["units_sold": 11_000, "revenue": 935_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[2],
				metrics: ["units_sold": 12_100, "revenue": 1_028_500]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[3],
				metrics: ["units_sold": 13_310, "revenue": 1_131_350]
			)
		]

		let timeSeries = try OperationalMetricsTimeSeries(metrics: metricsList)

		#expect(timeSeries.metrics.count == 4)
		#expect(timeSeries[quarters[0]]?["units_sold"] == 10_000)
		#expect(timeSeries[quarters[3]]?["revenue"] == 1_131_350)
	}

	@Test("Extract time series for specific metric")
	func testExtractTimeSeriesForMetric() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let quarters = Period.year(2025).quarters()

		let metricsList = [
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[0],
				metrics: ["units_sold": 10_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[1],
				metrics: ["units_sold": 11_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[2],
				metrics: ["units_sold": 12_100]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[3],
				metrics: ["units_sold": 13_310]
			)
		]

		let timeSeries = try OperationalMetricsTimeSeries(metrics: metricsList)
		let unitsSold = timeSeries.timeSeries(for: "units_sold")

		#expect(unitsSold != nil)
		#expect(unitsSold?[quarters[0]] == 10_000)
		#expect(unitsSold?[quarters[1]] == 11_000)
		#expect(unitsSold?[quarters[2]] == 12_100)
		#expect(unitsSold?[quarters[3]] == 13_310)
	}

	@Test("Calculate growth rate for metric")
	func testGrowthRateCalculation() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let quarters = Period.year(2025).quarters()

		let metricsList = [
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[0],
				metrics: ["units_sold": 10_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[1],
				metrics: ["units_sold": 11_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[2],
				metrics: ["units_sold": 12_100]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[3],
				metrics: ["units_sold": 13_310]
			)
		]

		let timeSeries = try OperationalMetricsTimeSeries(metrics: metricsList)
		let growth = timeSeries.growthRate(metric: "units_sold")

		#expect(growth != nil)

		// Q1 to Q2: 10% growth
		let q2Growth = growth?[quarters[1]]!
		#expect(abs(q2Growth! - 0.10) < 0.01, "Q2 growth should be ~10%")

		// Q2 to Q3: 10% growth
		let q3Growth = growth?[quarters[2]]!
		#expect(abs(q3Growth! - 0.10) < 0.01, "Q3 growth should be ~10%")
	}

	@Test("Time series rejects metrics from different entities")
	func testTimeSeriesEntityMismatch() throws {
		let entity1 = Entity(id: "SHOP1", primaryType: .ticker, name: "ShopCo")
		let entity2 = Entity(id: "SHOP2", primaryType: .ticker, name: "OtherShop")
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q2 = Period.quarter(year: 2025, quarter: 2)

		let metricsList = [
			OperationalMetrics<Double>(
				entity: entity1,
				period: q1,
				metrics: ["units_sold": 10_000]
			),
			OperationalMetrics<Double>(
				entity: entity2,
				period: q2,
				metrics: ["units_sold": 11_000]
			)
		]

		#expect(throws: OperationalMetricsError.self) {
			_ = try OperationalMetricsTimeSeries(metrics: metricsList)
		}
	}

	@Test("Time series automatically sorts by period")
	func testTimeSeriesSorting() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let quarters = Period.year(2025).quarters()

		// Create metrics in random order
		let metricsList = [
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[2],
				metrics: ["units_sold": 12_100]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[0],
				metrics: ["units_sold": 10_000]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[3],
				metrics: ["units_sold": 13_310]
			),
			OperationalMetrics<Double>(
				entity: entity,
				period: quarters[1],
				metrics: ["units_sold": 11_000]
			)
		]

		let timeSeries = try OperationalMetricsTimeSeries(metrics: metricsList)

		// Verify sorted order
		#expect(timeSeries.metrics[0].period == quarters[0])
		#expect(timeSeries.metrics[1].period == quarters[1])
		#expect(timeSeries.metrics[2].period == quarters[2])
		#expect(timeSeries.metrics[3].period == quarters[3])
	}

	// MARK: - Codable

	@Test("Operational metrics are Codable")
	func testCodable() throws {
		let entity = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let original = OperationalMetrics<Double>(
			entity: entity,
			period: q1,
			metrics: [
				"units_sold": 15_000,
				"revenue": 1_275_000
			]
		)

		// Encode
		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		// Decode
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(OperationalMetrics<Double>.self, from: data)

		#expect(decoded.entity.id == original.entity.id)
		#expect(decoded.period == original.period)
		#expect(decoded["units_sold"] == original["units_sold"])
		#expect(decoded["revenue"] == original["revenue"])
	}
}
