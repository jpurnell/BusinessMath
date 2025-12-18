import Cocoa
import Foundation
import BusinessMath

	// Define investment options
	let investments = [
		buildInvestment {
			Name("Project A - Equipment Upgrade")
			Category("Capital Expenditure")
			InitialInvestment(75_000)

			CashFlows {
				CashFlow(year: 1, amount: 25_000)
				CashFlow(year: 2, amount: 30_000)
				CashFlow(year: 3, amount: 35_000)
			}

			DiscountRate(0.10)
		},
		buildInvestment {
			Name("Project B - Market Expansion")
			Category("Growth")
			InitialInvestment(150_000)

			CashFlows {
				CashFlow(year: 1, amount: 30_000)
				CashFlow(year: 2, amount: 50_000)
				CashFlow(year: 3, amount: 70_000)
				CashFlow(year: 4, amount: 90_000)
			}

			DiscountRate(0.10)
		},
		buildInvestment {
			Name("Project C - Cost Reduction")
			Category("Efficiency")
			InitialInvestment(50_000)

			CashFlows {
				CashFlow(year: 1, amount: 20_000)
				CashFlow(year: 2, amount: 20_000)
				CashFlow(year: 3, amount: 20_000)
			}

			DiscountRate(0.10)
		}
	]

	// Rank by NPV
	let ranked = investments.sorted { $0.npv > $1.npv }

	print("Investment Rankings by NPV:")
	for (index, investment) in ranked.enumerated() {
		print("\(index + 1). \(investment.name ?? "")")
		print("   NPV: \(investment.npv.currency())")
		print("   IRR: \(((investment.irr ?? 0) * 100).formatted())%")
		print("   Payback: \((investment.paybackPeriod ?? .infinity).formatted()) years")
		print()
	}


