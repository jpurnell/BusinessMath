//
//  MonteCarloRNG.metal
//  BusinessMath
//
//  GPU Random Number Generator for Monte Carlo Simulation
//
//  Implements:
//  - Xorshift128+ PRNG (stateless, thread-safe)
//  - Box-Muller transform for Normal distribution
//  - Per-thread RNG state initialization
//

#include <metal_stdlib>
#include "MonteCarloCommon.h"
using namespace metal;

// Note: RNG functions (nextUniform, nextNormal, nextNormalSingle) are implemented
// in MonteCarloCommon.h and available to all Metal files.

// MARK: - RNG Initialization Kernel

/// Initialize RNG states for all GPU threads
///
/// Each thread receives its own stream, split off the base seed with SplitMix64 by
/// `seedRNGState` in MonteCarloCommon.h. Same base seed, same streams.
///
/// This used to read `s0 = baseSeed ^ tid` with a ten-draw warm-up, and the two
/// sentences above this line used to claim that gave "independent random streams
/// across threads" and that the warm-up "eliminates correlation in early outputs".
/// Neither was true: the measured cross-thread lag-1 correlation was +0.26 with the
/// warm-up in place, and more rounds moved it around rather than down. There is no
/// warm-up now because there is nothing left for it to do.
///
/// - Parameters:
///   - states: Output buffer for RNG states (one per thread)
///   - baseSeed: Base seed for reproducibility
///   - tid: Thread ID (unique per thread)
kernel void initializeRNG(
    device RNGState* states [[buffer(0)]],
    constant ulong& baseSeed [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    seedRNGState(&states[tid], baseSeed, tid);
}

// MARK: - Test/Debug Kernels

/// Generate uniform samples (for testing/validation)
///
/// This kernel is primarily used for RNG quality testing and validation.
/// Production simulations use the integrated monteCarloIteration kernel instead.
kernel void generateUniformSamples(
    device RNGState* states [[buffer(0)]],
    device float* outputs [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    outputs[tid] = nextUniform(&states[tid]);
}

/// Generate normal samples (for testing/validation)
///
/// This kernel is primarily used for Box-Muller transform validation.
/// Production simulations use distribution samplers in MonteCarloKernel.metal.
kernel void generateNormalSamples(
    device RNGState* states [[buffer(0)]],
    device float* outputs [[buffer(1)]],
    constant float& mean [[buffer(2)]],
    constant float& stdDev [[buffer(3)]],
    uint tid [[thread_position_in_grid]]
) {
    outputs[tid] = nextNormalSingle(&states[tid], mean, stdDev);
}
