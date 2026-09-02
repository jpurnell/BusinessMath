import Foundation

extension FormulaEvaluator {

	/// A function callable from formula text.
	///
	/// A dispatch table, not a second library. The arithmetic primitives here are
	/// thin wrappers over `Swift.min`, `Swift.max`, `+`, and `Numerics`' magnitude,
	/// applied through `TimeSeries.zip`. Everything financial that follows will
	/// delegate to the canonical implementation in core rather than being written
	/// again — a second `NPV` that could disagree with the first is exactly the
	/// failure this work exists to prevent.
	///
	/// ## Excel's semantics, not merely similar ones
	///
	/// Each function acts **period by period**, which is what `MIN(A2, B2)` filled
	/// across a row does in a sheet. Aggregating down a column is a different
	/// operation and is deliberately not expressible: this grammar is period-local,
	/// so a formula can never reach into another period. That boundary is what lets
	/// a rollforward be the caller's loop rather than a hidden effect inside a
	/// formula.
	public enum Function: String, Sendable, CaseIterable {

		/// The smallest value in each period.
		case min = "MIN"

		/// The largest value in each period.
		case max = "MAX"

		/// The magnitude in each period.
		case abs = "ABS"

		/// The total of the arguments in each period.
		case sum = "SUM"

		/// Selects between two values in each period.
		case ifThenElse = "IF"

		/// The mean of the arguments in each period.
		case average = "AVERAGE"

		/// Rounds to a number of decimal places, half away from zero.
		case round = "ROUND"

		/// One when every argument is non-zero.
		case and = "AND"

		/// One when any argument is non-zero.
		case or = "OR"

		/// One when the argument is zero.
		case not = "NOT"

		// MARK: Time value of money
		//
		// Delegated, never reimplemented. Each case names the canonical function it
		// binds to, so the binding is readable here rather than inferred from the
		// dispatch below.

		/// Net present value, Excel's definition. Binds to `npvExcel(rate:cashFlows:)`.
		case npv = "NPV"

		/// Internal rate of return. Binds to `irr(cashFlows:guess:tolerance:maxIterations:)`.
		case irr = "IRR"

		/// Loan payment. Binds to `payment(presentValue:rate:periods:)`.
		case pmt = "PMT"

		/// The interest part of one payment. Binds to `interestPayment(...)`.
		case ipmt = "IPMT"

		// MARK: Statistics
		//
		// Each pair differs only in its denominator, and both answers look
		// reasonable. The binding is named here so the choice is readable rather
		// than buried in dispatch.

		/// Sample standard deviation, dividing by n − 1. Binds to `stdDevS(_:)`.
		case stdev = "STDEV"

		/// Population standard deviation, dividing by n. Binds to `stdDevP(_:)`.
		case stdevp = "STDEVP"

		/// Sample variance. Binds to `variance(_:_:)` with `.sample`.
		case variance = "VAR"

		/// Population variance. Binds to `variance(_:_:)` with `.population`.
		case variancep = "VARP"

		/// The middle value. Binds to `median(_:)`.
		case median = "MEDIAN"

		/// How many periods the series holds.
		case count = "COUNT"

		/// The principal part of one payment. Binds to `principalPayment(...)`.
		case ppmt = "PPMT"

		// `FV` is deliberately absent. Excel's is `FV(rate, nper, pmt, [pv], [type])`
		// — an annuity's future value — while this library's
		// `futureValue(presentValue:rate:periods:)` is simple growth of a lump sum.
		// Same name, different function. Registering it would give a formula copied
		// out of a sheet a different meaning here, silently, which is the failure
		// this whole tranche exists to prevent. It goes in when the Excel signature
		// does.

		/// The argument counts this function accepts.
		///
		/// Checked before evaluation, so a miscall is reported as a miscall rather
		/// than as whatever the arguments happened to produce.
		public var arity: ClosedRange<Int> {
			switch self {
			case .min, .max, .sum, .average, .and, .or:
				// Excel caps these at 255. The cap is Excel's own limit rather than
				// a property of the operation, and refusing a 256th argument would
				// reject a formula that means something perfectly clear.
				return 1...Int.max
			case .abs, .not:
				return 1...1
			case .round, .npv:
				return 2...2
			case .irr, .stdev, .stdevp, .variance, .variancep, .median, .count:
				return 1...1
			case .pmt:
				return 3...3
			case .ipmt, .ppmt:
				return 4...4
			case .ifThenElse:
				return 3...3
			}
		}

		/// Whether this function consumes an entire series rather than acting period
		/// by period.
		///
		/// `NPV` and `IRR` are pointed at a range in a sheet and give back one
		/// number. Everything else takes scalars and gives a scalar, so it computes
		/// independently in each period — a formula filled across a row.
		public var aggregates: Bool {
			switch self {
			case .npv, .irr, .stdev, .stdevp, .variance, .variancep, .median, .count:
				return true
			default: return false
			}
		}

		/// The accepted argument count, phrased for an error message.
		public var arityDescription: String {
			switch self {
			case .min, .max, .sum, .average, .and, .or: return "1 or more"
			case .abs, .not, .irr, .stdev, .stdevp, .variance, .variancep, .median, .count:
				return "exactly 1"
			case .round, .npv: return "exactly 2"
			case .pmt: return "exactly 3"
			case .ipmt, .ppmt: return "exactly 4"
			case .ifThenElse: return "exactly 3"
			}
		}
	}
}
