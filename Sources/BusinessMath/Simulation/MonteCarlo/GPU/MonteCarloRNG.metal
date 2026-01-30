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
/// Each thread receives a unique seed derived from the base seed and thread ID.
/// This ensures independent random streams across threads while maintaining reproducibility.
///
/// The RNG is "warmed up" by discarding the first 10 samples, which improves
/// statistical quality by avoiding initial state correlation.
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
    // Initialize state with thread-specific seeds
    // Uses bit mixing to ensure independence between threads
    states[tid].s0 = baseSeed ^ tid;
    states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);

    // Warm up the RNG by discarding initial samples
    // This eliminates correlation in early outputs
    for (int i = 0; i < 10; i++) {
        nextUniform(&states[tid]);
    }
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
