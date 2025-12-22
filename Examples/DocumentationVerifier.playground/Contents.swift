import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport


	// Quarterly lease payments for office space
	let q1 = Period.quarter(year: 2025, quarter: 1)
	let periods = [q1, q1 + 1, q1 + 2, q1 + 3]  // 4 quarters = 1 year

	let payments = TimeSeries(
		periods: periods,
		values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
	)

	// Create lease with 6% annual discount rate
	let lease = Lease(
		payments: payments,
		discountRate: 0.06  // Incremental borrowing rate
	)

	// Calculate present value (lease liability)
	let liability = lease.presentValue()
print("Initial lease liability: \(liability.currency())")  // ~$96,454

	// Calculate right-of-use asset
	let rouAsset = lease.rightOfUseAsset()
print("ROU asset: \(rouAsset.currency())")  // Same as liability initially

let schedule = lease.liabilitySchedule()

// Display schedule
for (period, balance) in schedule.sorted(by: { $0.key < $1.key }) {
	print("\(period.label): Balance \(balance.currency(0))")
}

// First period shows initial liability
// Subsequent periods show ending balance after payment


// Interest expense for first quarter
let interest1 = lease.interestExpense(period: q1)
print("Q1 Interest: \(interest1.currency())")  // Liability × (6% / 4)

// Principal reduction
let principal1 = lease.principalReduction(period: q1)
print("Q1 Principal: \(principal1.currency())")  // Payment - Interest

// Payment breakdown
let payment = 25_000.0
let totalExpense = interest1 + principal1
print("Total payment: \(payment.currency())")

	// Depreciation per period (straight-line)
	let depreciation = lease.depreciation(period: q1)
print("Q1 Depreciation: \(depreciation.currency())")  // ROU asset ÷ lease term

	// Carrying value after each period
	let carryingValue1 = lease.carryingValue(period: q1)
	let carryingValue2 = lease.carryingValue(period: q1 + 1)
print("Q1 carrying value: \(carryingValue1.currency())")
print("Q2 carrying value: \(carryingValue2.currency())")  // Lower

	// Interest expense (financing cost)
	let interest = lease.interestExpense(period: q1)

	// Depreciation expense (operating expense)
//	let depreciation = lease.depreciation(period: q1)

	// Total P&L impact
	let interestAndDepreciation = interest + depreciation
print("Q1 Total Expense: \(interestAndDepreciation.currency(0))")

	// Note: Expense is front-loaded (higher interest early)
	// Compare to straight-line rent expense under old standard

	// Calculate IBR
	let ibr = calculateIncrementalBorrowingRate(
		riskFreeRate: 0.03,        // Treasury rate
		creditSpread: 0.02,        // Company's credit spread
		assetRiskPremium: 0.005    // Asset-specific risk
	)
print("IBR: \(ibr.percent())")  // 5.5%

	let lease2 = Lease(
		payments: payments,
		discountRate: ibr,
		discountRateType: .incrementalBorrowingRate
	)

let lowRate = Lease(payments: payments, discountRate: 0.04)
let highRate = Lease(payments: payments, discountRate: 0.10)

print("PV at \(lowRate.discountRate.percent()): \(lowRate.presentValue().currency())")   // Higher PV
print("PV at \(highRate.discountRate.percent()): \(highRate.presentValue().currency())")  // Lower PV

let shortTermLease = Lease(
	payments: payments,
	discountRate: 0.06,
	leaseTerm: .months(12)  // Explicitly specify term
)

if shortTermLease.isShortTerm {
	print("Qualifies for short-term exemption")
	// Can expense payments as incurred
	// No ROU asset or liability
}

// When exemption applied:
let rouAssetExemption = shortTermLease.rightOfUseAsset()  // Returns 0
let scheduleExemption = shortTermLease.liabilitySchedule()  // Returns zeros


let lowValueLease = Lease(
	payments: payments,
	discountRate: 0.06,
	underlyingAssetValue: 4_500.0  // Below $5K threshold
)

if lowValueLease.isLowValue {
	print("Qualifies for low-value exemption")
	// Can expense payments as incurred
}


	// Fixed minimum payments
	let fixedPayments = TimeSeries(
		periods: periods,
		values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
	)

	// Variable payments (e.g., based on sales)
	let variablePayments = TimeSeries(
		periods: periods,
		values: [3_000.0, 5_000.0, 4_500.0, 6_000.0]
	)

	let leaseFixedPayments = Lease(
		payments: fixedPayments,
		discountRate: 0.07,
		variablePayments: variablePayments
	)

	// Only fixed payments in liability
	let liabilityFixedPayments = leaseFixedPayments.presentValue()  // PV of fixed portion only

	// Total cash payment includes variable component
	let totalCash = leaseFixedPayments.totalCashPayment(period: periods[0])
print("Total Q1 payment: \(totalCash.currency())")  // Fixed + variable


let originalLease = Lease(
	payments: payments,
	discountRate: 0.06
)

// Extend by 2 more quarters
let extensionPayments = TimeSeries(
	periods: [q1 + 4, q1 + 5],
	values: [26_000.0, 26_000.0]
)

let extendedLease = originalLease.extend(
	additionalPayments: extensionPayments
)

let originalROU = originalLease.rightOfUseAsset()
let newROU = extendedLease.rightOfUseAsset()
print("ROU increase: \((newROU - originalROU).currency())")


	// Lease option
	let leasePV = leasePaymentsPV(
		periodicPayment: 5_000.0,
		periods: 60,  // 5 years monthly
		discountRate: 0.006  // Monthly rate
	)

	// Buy option
	let buyPV = buyAssetPV(
		purchasePrice: 250_000.0,
		salvageValue: 50_000.0,
		holdingPeriod: 5,
		discountRate: 0.075,
		maintenanceCost: 2_000.0  // Annual
	)

	let analysis = LeaseVsBuyAnalysis(leasePV: leasePV, buyPV: buyPV)

	if analysis.shouldLease {
		print("Recommendation: \(analysis.recommendation)")
		print("Savings: \(analysis.savingsPercentage.percent())")
	} else {
		print("Buying is more economical")
	}

let assetCarryingValue = 500_000.0
let salePrice = 600_000.0

let leasebackPayments = TimeSeries(
	periods: periods,
	values: [40_000.0, 40_000.0, 40_000.0, 40_000.0]
)

let transaction = SaleAndLeaseback(
	carryingValue: assetCarryingValue,
	salePrice: salePrice,
	leasebackPayments: leasebackPayments,
	discountRate: 0.06,
	startDate: q1.startDate
)

// Gain recognition
let gainRecognized = transaction.recognizedGain()
let deferredGain = transaction.deferredGain()

print("Recognized gain: \(gainRecognized.currency())")
print("Deferred gain: \(deferredGain.currency())")

// Cash benefit
let cashBenefit = transaction.netCashBenefit
print("Net cash from transaction: \(cashBenefit.currency())")

// Economic analysis
if transaction.isEconomicallyBeneficial {
	print("Transaction creates value")
}


let classification = classifyLease(
	leaseTerm: 48,           // months
	assetUsefulLife: 60,     // months
	presentValue: 90_000.0,
	assetFairValue: 100_000.0,
	ownershipTransfer: false,
	purchaseOption: false
)

switch classification {
case .finance:
	print("Finance lease")
	// Depreciation + interest expense
case .operating:
	print("Operating lease")
	// Single lease expense (straight-line)
}


	// Office lease: 5 years, quarterly payments
	let startDate = Period.quarter(year: 2025, quarter: 1)
	let periodsOffice = (0..<20).map { startDate + $0 }  // 20 quarters

	// Fixed rent with 3% annual escalation
	var paymentsOffice: [Double] = []
	let baseRent = 30_000.0
	for i in 0..<20 {
		let yearIndex = i / 4
		let escalatedRent = baseRent * pow(1.03, Double(yearIndex))
		paymentsOffice.append(escalatedRent)
	}

	let paymentSeries = TimeSeries(periods: periodsOffice, values: paymentsOffice)

	// Create lease with costs
	let leaseOffice = Lease(
		payments: paymentSeries,
		discountRate: 0.068,  // 6.8% IBR
		initialDirectCosts: 15_000.0,  // Broker commission
		prepaidAmount: 30_000.0,       // First quarter rent
		depreciationMethod: .straightLine,
		leaseTerm: .years(5),
		underlyingAssetValue: 2_000_000.0  // Office space value
	)

	// Initial recognition
	let liabilityOffice = leaseOffice.presentValue()
	let rouAssetOffice = leaseOffice.rightOfUseAsset()

	print("=== Initial Recognition ===")
	print("Lease liability: \(liabilityOffice.currency(2))")
	print("ROU asset: \(rouAssetOffice.currency(2))")

	// First year expense breakdown
	print("\n=== Year 1 Expenses ===")
	for i in 0..<4 {
		let period = periodsOffice[i]
		let interest = leaseOffice.interestExpense(period: period)
		let depreciation = leaseOffice.depreciation(period: period)
		let total = interest + depreciation

		print("\(period.label): Interest \(interest.currency()), " +
			  "Depreciation \(depreciation.currency()), " +
			 "Total \(total.currency())")
	}

	// Maturity analysis for disclosure
	print("\n=== Payment Maturity Analysis ===")
	let maturityOffice = leaseOffice.maturityAnalysis()
	for (year, amount) in maturityOffice.sorted(by: { $0.key < $1.key }) {
		print("\(year): \(amount.currency())")
	}

	// Total commitment disclosure
	let totalPayments = lease.totalFuturePayments()
	print("\nTotal future lease payments: $\(String(format: "%.0f", totalPayments))")
	print("Present value: $\(String(format: "%.0f", liability))")
	print("Implicit interest: $\(String(format: "%.0f", totalPayments - liability))")


	// Total commitments
	let totalCommitments = lease.totalFuturePayments()

	// Weighted average discount rate
	let effectiveRate = lease.effectiveRate

	// Weighted average remaining term
	// (calculate from payment schedule)

	// Maturity analysis
	let maturity = lease.maturityAnalysis()

	// Expense breakdown
	let currentPeriod = Period.quarter(year: 2025, quarter: 1)
	let interestDisclosure = lease.interestExpense(period: currentPeriod)
	let depreciationDisclosure = lease.depreciation(period: currentPeriod)
print("\(currentPeriod.label): \(interestDisclosure.currency()) Interest; \(depreciationDisclosure.currency()) Depreciation")


	// Annual payments but monthly periods for reporting
	let year2025 = Period.year(2025)
	let annualPayment = 120_000.0

	// Convert to monthly equivalent
	let months = year2025.months()
	let monthlyPayment = annualPayment / 12.0

	let monthlyPayments = TimeSeries(
		periods: months,
		values: Array(repeating: monthlyPayment, count: 12)
	)

	let leasePitfall = Lease(
		payments: monthlyPayments,
		discountRate: 0.06  // Will be converted to monthly rate automatically
	)

let leaseResidualValue = Lease(
	payments: payments,
	discountRate: 0.07,
	residualValue: 20_000.0  // Guaranteed residual at end
)

// Residual value increases lease liability
let liabilityWithResidual = leaseResidualValue.presentValue()
print(leaseResidualValue.presentValue().currency())

	// ROU asset + leasehold improvements
	let rouAssetLeasehold = lease.rightOfUseAsset()
	let improvements = 50_000.0
	let totalAsset = rouAsset + improvements

	// Depreciate over shorter of lease term or improvement life
