//
//  DiffusionError.swift
//  BusinessMath
//

import Foundation

/// Why a diffusion simulation, estimate or seed selection was refused.
///
/// Each case is a caller mistake that would otherwise produce a plausible-looking number:
/// zero trials would divide by zero, and a probability of 1.5 would quietly behave like 1.
///
/// ```swift
/// import BusinessMath
///
/// do {
///     _ = try IndependentCascade(probability: 1.5)
/// } catch let error as DiffusionError {
///     print(error)   // invalidProbability(1.5)
/// }
/// ```
public enum DiffusionError: Error, Equatable, Sendable {
	/// An activation probability outside `[0, 1]`, or not a finite number.
	case invalidProbability(Double)
	/// A trial count below one.
	case invalidTrialCount(Int)
	/// A negative seed budget.
	case invalidBudget(Int)
	/// A sensitivity sweep over no probabilities at all.
	case emptySweep
}
