import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Step 1: Use driver optimizer to find optimal pricing and churn
	let drivers = [
		OptimizableDriver(name: "price", currentValue: 50, range: 40...70),
		OptimizableDriver(name: "churn", currentValue: 0.05, range: 0.02...0.08)
	]

	let targets = [
		FinancialTarget(metric: "mrr", target: .exact(100_000), weight: 1.0)
	]

	let optimizer = DriverOptimizer()
	let result = try optimizer.optimize(
		drivers: drivers,
		targets: targets,
		model: { values in
			let price = values["price"]!
			let churn = values["churn"]!
			let newCustomers = 150.0  // Fixed acquisition rate

			let steadyStateCustomers = newCustomers / churn
			let mrr = steadyStateCustomers * price

			return ["mrr": mrr]
		}
	)

	// Step 2: Build a financial model using the optimized parameters
	if result.feasible {
		let optimizedPrice = result.optimizedDrivers["price"]!
		let optimizedChurn = result.optimizedDrivers["churn"]!
		let customers = 150.0 / optimizedChurn  // Steady-state customers

		let model = FinancialModel {
			Revenue {
				Product("SaaS Subscriptions")
					.price(optimizedPrice)
					.customers(customers)
			}

			Costs {
				Fixed("Salaries", 50_000)
				Fixed("Infrastructure", 10_000)
				Variable("Customer Support", 0.15)  // 15% of revenue
			}
		}

		print("Optimized Model:")
		print("  Revenue: \(model.calculateRevenue().currency())")
		print("    Costs:  \(model.calculateCosts(revenue: model.calculateRevenue()).currency())")
		print("   Profit:  \(model.calculateProfit().currency())")
	}
