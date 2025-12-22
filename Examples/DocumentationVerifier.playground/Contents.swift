import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

struct LoanAnalysis {
	let principal: Double
	let monthlyPayment: Double
	let totalPayments: Int
	let totalPaid: Double
	let totalInterest: Double

	func printSummary() {
		print("Loan Analysis Summary")
		print("=====================")
		print("Principal: \(principal.currency(2))")
		print("Monthly Payment: \(monthlyPayment.currency(2))")
		print("Total Payments: \(totalPayments)")
		print("Total Paid: \(totalPaid.currency(2))")
		print("Total Interest: \(totalInterest.currency(2))")
		print("Interest / Principal: \((totalInterest / principal).percent(1))")
	}
}

func analyzeLoan(principal: Double, annualRate: Double, years: Int) -> LoanAnalysis {
	let monthlyRate = annualRate / 12
	let totalPayments = years * 12

	let monthlyPayment = payment(
		presentValue: principal,
		rate: monthlyRate,
		periods: totalPayments,
		futureValue: 0,
		type: .ordinary
	)

	let totalPaid = monthlyPayment * Double(totalPayments)
	let totalInterest = totalPaid - principal

	return LoanAnalysis(
		principal: principal,
		monthlyPayment: monthlyPayment,
		totalPayments: totalPayments,
		totalPaid: totalPaid,
		totalInterest: totalInterest
	)
}

// Use it
let myLoan = analyzeLoan(principal: 300_000, annualRate: 0.06, years: 30)
myLoan.printSummary()

// Compare different scenarios
print("\nComparing scenarios:")
analyzeLoan(principal: 300_000, annualRate: 0.06, years: 30).printSummary()
print()
analyzeLoan(principal: 300_000, annualRate: 0.06, years: 15).printSummary()
