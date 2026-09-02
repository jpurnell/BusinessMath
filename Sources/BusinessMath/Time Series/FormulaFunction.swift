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

		/// The argument counts this function accepts.
		///
		/// Checked before evaluation, so a miscall is reported as a miscall rather
		/// than as whatever the arguments happened to produce.
		public var arity: ClosedRange<Int> {
			switch self {
			case .min, .max, .sum:
				// Excel caps these at 255. The cap is Excel's own limit rather than
				// a property of the operation, and refusing a 256th argument would
				// reject a formula that means something perfectly clear.
				return 1...Int.max
			case .abs:
				return 1...1
			}
		}

		/// The accepted argument count, phrased for an error message.
		public var arityDescription: String {
			switch self {
			case .min, .max, .sum: return "1 or more"
			case .abs: return "exactly 1"
			}
		}
	}
}
