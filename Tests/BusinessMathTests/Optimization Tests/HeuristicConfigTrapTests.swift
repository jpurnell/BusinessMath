//
//  HeuristicConfigTrapTests.swift
//  BusinessMathTests
//
//  Phase 1 of the contaminated-input sweep: the trap class.
//
//  Every heuristic quantises a `Double` through `Int` to get a generic `V.Scalar`:
//
//      let toleranceInt = Int(config.tolerance * 1_000_000)
//      let toleranceScalar = V.Scalar(toleranceInt) / V.Scalar(1_000_000)
//
//  18 sites repeat that idiom, and `Int(x)` **traps** — it does not return a wrong answer —
//  for a non-finite `x`, and equally for any finite `|x| > 9.22e12` once multiplied by a
//  million. Every one of those values arrives from a public config initialiser that stores it
//  without validation.
//
//  This is not hypothetical here. `SimulatedAnnealing.swift` carries a comment recording that
//  this exact conversion already took the process down once:
//
//      "The resulting NaN reached `Int(scaledGaussian * 1_000_000)` below, and converting NaN
//       to Int in Swift traps rather than returning a wrong answer: one draw in 2^32 took the
//       process down."
//
//  That was root-caused to the upstream Box-Muller divisor and fixed there. The trapping
//  conversion was left in place at all 18 sites, and every config parameter feeding them was
//  left unscreened.
//
//  The fix is the pattern each of these initialisers ALREADY uses for one parameter —
//  `constraintPenaltyWeight` is screened `> 0 && .isFinite` with a documented fallback — applied
//  to the rest of them.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Heuristic configs reject parameters that would trap")
struct HeuristicConfigTrapTests {

    /// A NaN tolerance reaches `Int(tolerance * 1_000_000)` on the convergence check.
    @Test("NelderMead_NonFiniteConfig_DoesNotTrap")
    func nelderMeadNonFiniteConfigDoesNotTrap() {
        let config = NelderMeadConfig(reflectionCoefficient: .nan,
                                      initialSimplexSize: .nan,
                                      tolerance: .nan)
        #expect(config.tolerance.isFinite, "got \(config.tolerance)")
        #expect(config.initialSimplexSize.isFinite)
        #expect(config.reflectionCoefficient.isFinite)
    }

    /// The magnitude half: finite, but `x * 1_000_000` overflows `Int`.
    @Test("NelderMead_EnormousConfig_DoesNotTrap")
    func nelderMeadEnormousConfigDoesNotTrap() {
        let config = NelderMeadConfig(tolerance: 1e13)
        let quantised = config.tolerance * 1_000_000
        #expect(quantised < Double(Int.max), "tolerance \(config.tolerance) would overflow Int")
    }

    @Test("ParticleSwarm_NonFiniteConfig_DoesNotTrap")
    func particleSwarmNonFiniteConfigDoesNotTrap() {
        let config = ParticleSwarmConfig(inertiaWeight: .nan,
                                         cognitiveCoefficient: .nan,
                                         socialCoefficient: .nan,
                                         velocityClamp: .nan, seed: 20_260_928)
        #expect(config.inertiaWeight.isFinite, "got \(config.inertiaWeight)")
        #expect(config.cognitiveCoefficient.isFinite)
        #expect(config.socialCoefficient.isFinite)
        #expect(config.velocityClamp == nil,
                "an unusable clamp becomes nil — no clamping — rather than a fabricated width")
    }

    @Test("DifferentialEvolution_NonFiniteConfig_DoesNotTrap")
    func differentialEvolutionNonFiniteConfigDoesNotTrap() {
        let config = DifferentialEvolutionConfig(mutationFactor: .nan, seed: 20_260_928)
        #expect(config.mutationFactor.isFinite, "got \(config.mutationFactor)")
    }

    @Test("GeneticAlgorithm_NonFiniteConfig_DoesNotTrap")
    func geneticAlgorithmNonFiniteConfigDoesNotTrap() {
        let config = GeneticAlgorithmConfig(mutationStrength: .nan, seed: 20_260_928)
        #expect(config.mutationStrength.isFinite, "got \(config.mutationStrength)")
    }

    @Test("SimulatedAnnealing_NonFiniteConfig_DoesNotTrap")
    func simulatedAnnealingNonFiniteConfigDoesNotTrap() {
        let config = SimulatedAnnealingConfig(perturbationScale: .nan, seed: 20_260_928)
        #expect(config.perturbationScale.isFinite, "got \(config.perturbationScale)")
    }

    // MARK: - Controls

    /// Ordinary configs keep every value they were given, unchanged.
    @Test("OrdinaryConfigs_Unchanged")
    func ordinaryConfigsUnchanged() {
        let nm = NelderMeadConfig(reflectionCoefficient: 1.0, expansionCoefficient: 2.0,
                                  contractionCoefficient: 0.5, shrinkCoefficient: 0.5,
                                  initialSimplexSize: 1.0, tolerance: 1e-6)
        #expect(nm.tolerance.isEqual(to: 1e-6))
        #expect(nm.reflectionCoefficient.isEqual(to: 1.0))
        #expect(nm.expansionCoefficient.isEqual(to: 2.0))
        #expect(nm.initialSimplexSize.isEqual(to: 1.0))

        let pso = ParticleSwarmConfig(inertiaWeight: 0.7, cognitiveCoefficient: 1.5,
                                      socialCoefficient: 1.5, velocityClamp: 0.2, seed: 20_260_928)
        #expect(pso.inertiaWeight.isEqual(to: 0.7))
        #expect(pso.velocityClamp?.isEqual(to: 0.2) == true)

        #expect(DifferentialEvolutionConfig(mutationFactor: 0.8, seed: 20_260_928).mutationFactor.isEqual(to: 0.8))
        #expect(GeneticAlgorithmConfig(mutationStrength: 0.1, seed: 20_260_928).mutationStrength.isEqual(to: 0.1))
        #expect(SimulatedAnnealingConfig(perturbationScale: 0.1, seed: 20_260_928).perturbationScale.isEqual(to: 0.1))
    }

    /// And an optimiser built from an unusable config still runs to a finite answer.
    @Test("NelderMead_RunsWithAnUnusableConfig")
    func nelderMeadRunsWithAnUnusableConfig() throws {
        let optimizer = NelderMead<Vector2D<Double>>(config: NelderMeadConfig(tolerance: .nan))
        let result = try optimizer.minimize({ point in point.x * point.x + point.y * point.y },
                                            from: Vector2D(x: 3.0, y: 4.0))
        #expect(result.solution.x.isFinite, "got \(result.solution)")
        #expect(result.solution.y.isFinite)
    }
}
