//
//  UsableParameter.swift
//  BusinessMath
//

import Foundation

/// A configuration parameter that is safe to quantise through `Int`, or the documented default.
///
/// Every heuristic in this directory converts its `Double` parameters into a generic
/// `V.Scalar` by quantising through `Int`:
///
/// ```
/// let toleranceInt = Int(config.tolerance * 1_000_000)
/// let toleranceScalar = V.Scalar(toleranceInt) / V.Scalar(1_000_000)
/// ```
///
/// `Int(x)` **traps** for a non-finite `x` — it does not return a wrong answer, it takes the
/// process down — and equally for any finite `|x|` whose product with a million exceeds
/// `Int.max`, which is roughly `9.22e12`. Eighteen sites across NelderMead, ParticleSwarm,
/// DifferentialEvolution, GeneticAlgorithm and SimulatedAnnealing repeat that idiom, and every
/// value feeding them arrived from a public config initialiser that stored it unvalidated.
///
/// That is not a hypothetical. `SimulatedAnnealing.swift` records that this exact conversion
/// already crashed this package once — "one draw in 2^32 took the process down" — when an
/// upstream Box-Muller guard produced a `nan`. The upstream cause was fixed; the trap was left.
///
/// Each of these initialisers already screens `constraintPenaltyWeight` this way, with a
/// documented fallback. This is that same treatment for the parameters that were missed, so the
/// screen sits at the boundary rather than at eighteen conversion sites — which also means a
/// config reports the value it will actually honour.
///
/// - Parameters:
///   - value: The caller-supplied parameter.
///   - fallback: The documented default to use when the value cannot be quantised.
/// - Returns: `value` when it is finite and small enough to quantise, otherwise `fallback`.
internal func usableParameter(_ value: Double, fallback: Double) -> Double {
	let ceiling = Double(Int.max) / 1_000_000
	guard value.isFinite, value.magnitude < ceiling else { return fallback }
	return value
}

/// The optional form, for a parameter whose absence is itself meaningful.
///
/// `ParticleSwarmConfig.velocityClamp` is `Double?`, where `nil` means "do not clamp". An
/// unusable clamp width therefore becomes `nil` rather than a substituted number: not clamping
/// is an honest answer, and a fabricated clamp width is not.
///
/// - Parameter value: The caller-supplied parameter, or `nil`.
/// - Returns: `value` when it is finite and small enough to quantise, otherwise `nil`.
internal func usableParameter(_ value: Double?) -> Double? {
	guard let value else { return nil }
	let ceiling = Double(Int.max) / 1_000_000
	guard value.isFinite, value.magnitude < ceiling else { return nil }
	return value
}
