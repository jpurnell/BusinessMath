//
//  TriangularGPUParityTests.swift
//  BusinessMathTests
//
//  The triangular defect again, on the other side of the CPU/GPU boundary.
//
//  `triangularDistribution(low:high:base:)` refuses transposed bounds and a mode outside the
//  range, returning NaN. `DistributionTriangular.pdf` guards the same three conditions and
//  returns NaN. `DistributionTriangular.init` does neither — it stores what it is given.
//
//  That was survivable while every sample went through the guarded CPU sampler. The Metal
//  kernel in `MonteCarloGPUDevice` is a second implementation and has no such check:
//
//      float u = nextUniform(state), fc = (mode - min) / (max - min);
//      return u < fc ? min + sqrt(u * (max - min) * (mode - min))
//                    : max - sqrt((1.0f - u) * (max - min) * (max - mode));
//
//  With `min = 0.30, max = 0.10` the ratio is `(-0.1) / (-0.2) = 0.5`, so half the draws take
//  the first arm and evaluate `0.30 + sqrt(0.02u)` — above the interval's upper end. With a
//  mode outside the range `fc > 1`, so that arm is taken every time. Both are the defect
//  `Distribution.triangular` was fixed for in `BusinessMathDSL`, in a shader no Swift
//  `precondition` can reach.
//
//  So the two backends disagreed, and more sharply than "NaN versus a number": the CPU
//  sampler returns NaN and the simulation then **throws** `.invalidModel(details: "NaN
//  result")`, refusing to report anything at all. The GPU returned values outside the support
//  and called them samples. The fix declines such a distribution in
//  `areInputsGPUCompatible()`, routing the model to the CPU through the fallback path that
//  already exists for unsupported distributions, so the refusal is what both backends do.
//
//  `max == min` is the one degenerate case the kernel gets right by accident — `fc` is `0/0`,
//  `u < NaN` is false, and the else arm reduces to `max - sqrt(0)`. It is a point mass on
//  both backends, so it stays GPU-eligible.
//

import Testing
import TestSupport  // .requiresMetalGPU
import Foundation
@testable import BusinessMath

@Suite("Triangular sampling agrees across CPU and GPU", .requiresMetalGPU)
struct TriangularGPUParityTests {

    /// A model that simply returns its single input, so the results are the samples.
    private func passthroughSimulation(
        _ distribution: DistributionTriangular
    ) throws -> SimulationResults {
        let model = try MonteCarloExpressionModel { builder in builder[0] }
        var simulation = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: true,
            seed: 0x52B3_52B3,
            expressionModel: model
        )
        simulation.addInput(SimulationInput(name: "X", distribution: distribution))
        return try simulation.run()
    }

    /// The control: a well-formed triangular still runs on the GPU, so the guard has not
    /// simply disabled the fast path.
    @Test("SoundTriangular_StillUsesGPU") func soundTriangularStillUsesGPU() throws {
        let results = try passthroughSimulation(
            DistributionTriangular(low: 0.10, high: 0.30, base: 0.20)
        )
        #expect(results.usedGPU == true, "a sound triangular is still GPU-eligible")
        for value in results.values {
            #expect(value >= 0.10 - 1e-6 && value <= 0.30 + 1e-6,
                    "sample \(value) outside [0.10, 0.30]")
        }
    }

    /// Transposed bounds. The CPU sampler returns NaN and the simulation throws on it; the
    /// kernel returned values above the interval's upper end and reported them as samples.
    @Test("TransposedBounds_AreRefused") func transposedBoundsAreRefused() {
        #expect(throws: (any Error).self) {
            _ = try passthroughSimulation(
                DistributionTriangular(low: 0.30, high: 0.10, base: 0.20)
            )
        }
    }

    /// A mode outside the range makes `fc > 1`, so the kernel took the first arm on every
    /// draw and every sample left the support.
    @Test("ModeOutsideRange_IsRefused") func modeOutsideRangeIsRefused() {
        #expect(throws: (any Error).self) {
            _ = try passthroughSimulation(
                DistributionTriangular(low: 0.10, high: 0.20, base: 0.90)
            )
        }
    }

    /// The degenerate point mass is *not* declined: both backends agree on it already.
    @Test("PointMass_RemainsGPUEligible") func pointMassRemainsGPUEligible() throws {
        let results = try passthroughSimulation(
            DistributionTriangular(low: 0.20, high: 0.20, base: 0.20)
        )
        #expect(results.usedGPU == true, "equal bounds are a point mass, which the kernel handles")
        for value in results.values {
            #expect(abs(value - 0.20) < 1e-6, "sample \(value) is not the point mass")
        }
    }
}
