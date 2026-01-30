//
//  MonteCarloDistributions.metal
//  BusinessMath
//
//  GPU Distribution Samplers for Monte Carlo Simulation
//
//  Implements:
//  - Distribution parameter structure
//  - Normal distribution sampler (Box-Muller transform)
//  - Uniform distribution sampler
//  - Triangular distribution sampler (inverse transform)
//  - Distribution type dispatcher
//

#include <metal_stdlib>
#include "MonteCarloCommon.h"
using namespace metal;

// Note: Distribution sampling functions (sampleNormal, sampleUniform, etc.) are
// implemented in MonteCarloCommon.h and available to all Metal files.

// MARK: - Test/Debug Kernel

/// Sample from distributions (for testing/validation)
///
/// This kernel is primarily used for distribution sampler validation.
/// Production simulations use the integrated monteCarloIteration kernel instead.
kernel void sampleDistributions(
    device RNGState* states [[buffer(0)]],
    constant DistributionParams* params [[buffer(1)]],
    constant int& distType [[buffer(2)]],
    device float* outputs [[buffer(3)]],
    uint tid [[thread_position_in_grid]]
) {
    outputs[tid] = sampleDistribution(&states[tid], params, distType);
}
