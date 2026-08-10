//
//  MonteCarloCommon.h
//  BusinessMath
//
//  Common definitions for Monte Carlo GPU shaders
//
//  This header ensures consistent type definitions across all Monte Carlo
//  Metal shader files, preventing compilation issues from mismatched structs.
//
//  AHEAD-OF-TIME COPY — KEEP IN STEP WITH MetalShaderSource.swift
//
//  Nothing in this package compiles this file. The three .metal files that
//  #include it are all listed in Package.swift's exclude:, so SPM skips them and
//  no Metal toolchain is required to build. Every kernel that actually runs is
//  compiled at launch from the Swift string in MetalShaderSource.swift.
//
//  That is exactly how the two came to disagree: this header's nextNormal had no
//  pole guard at all while the string clamped with max(u1, 1e-10f), and nobody
//  comparing them would have noticed, because building the package never touches
//  this text. A header and a Swift string literal cannot share source without a
//  build step that embeds one in the other, which would reintroduce the toolchain
//  dependency the exclude: exists to avoid. So this is a hand-maintained mirror,
//  and the guard below is the one from MetalShaderSource.swift — read the reasoning
//  there, not here.
//

#ifndef MONTE_CARLO_COMMON_H
#define MONTE_CARLO_COMMON_H

#include <metal_stdlib>
using namespace metal;

// MARK: - RNG State

/// RNG state for Xorshift128+ algorithm
///
/// Each GPU thread maintains its own independent RNG state
/// to ensure parallel execution without race conditions.
struct RNGState {
    ulong s0;  ///< First state component
    ulong s1;  ///< Second state component
};

// MARK: - Distribution Parameters

/// Distribution parameter structure
///
/// Flexible parameter storage for various distribution types.
/// Different distributions use different parameter slots:
///
/// **Normal**: param1=mean, param2=stdDev, param3=unused
/// **Uniform**: param1=min, param2=max, param3=unused
/// **Triangular**: param1=min, param2=max, param3=mode
/// **Exponential**: param1=rate, param2=unused, param3=unused
/// **Lognormal**: param1=logMean, param2=logStdDev, param3=unused
struct DistributionParams {
    float param1;  ///< First parameter (distribution-specific)
    float param2;  ///< Second parameter (distribution-specific)
    float param3;  ///< Third parameter (distribution-specific)
};

// MARK: - Distribution Types

/// Distribution type enumeration
///
/// Maps to integer values for efficient switch dispatch.
/// Must match Swift-side enum values for correct marshalling.
enum DistributionType : int {
    DIST_NORMAL = 0,      ///< Normal (Gaussian) distribution
    DIST_UNIFORM = 1,     ///< Uniform distribution
    DIST_TRIANGULAR = 2,  ///< Triangular distribution
    DIST_EXPONENTIAL = 3, ///< Exponential distribution
    DIST_LOGNORMAL = 4    ///< Lognormal distribution
};

// MARK: - Bytecode Operation

/// Bytecode operation for model evaluation
struct ModelOp {
    int opcode;    ///< Operation type (ADD=0, SUB=1, MUL=2, DIV=3, INPUT=4, CONST=5)
    int arg1;      ///< Input index or stack position
    float arg2;    ///< Constant value (for CONST opcode)
};

// MARK: - Constants

constant int MAX_INPUTS = 32;     ///< Maximum number of input distributions
constant int MAX_STACK = 32;      ///< Maximum stack depth for bytecode evaluator
constant int MAX_OPS = 128;       ///< Maximum number of bytecode operations

// Bytecode opcodes
// Arithmetic operations
constant int OP_ADD = 0;
constant int OP_SUB = 1;
constant int OP_MUL = 2;
constant int OP_DIV = 3;
constant int OP_INPUT = 4;
constant int OP_CONST = 5;
constant int OP_POW = 6;
constant int OP_MIN = 7;
constant int OP_MAX = 8;

// Unary operations
constant int OP_NEG = 9;
constant int OP_ABS = 10;
constant int OP_SQRT = 11;
constant int OP_LOG = 12;
constant int OP_EXP = 13;
constant int OP_SIN = 14;
constant int OP_COS = 15;
constant int OP_TAN = 16;

// Comparison operations (return 1.0 for true, 0.0 for false)
constant int OP_LT = 17;    // Less than
constant int OP_GT = 18;    // Greater than
constant int OP_LE = 19;    // Less or equal
constant int OP_GE = 20;    // Greater or equal
constant int OP_EQ = 21;    // Equal (within epsilon)
constant int OP_NE = 22;    // Not equal

// Conditional operations
constant int OP_SELECT = 23;  // Ternary: condition ? true : false

// Floating-point epsilon for equality comparisons
constant float EPSILON = 1e-10f;

// MARK: - RNG Function Implementations

/// Generate uniform random float in [0, 1) using Xorshift128+
inline float nextUniform(device RNGState* state) {
    ulong s1 = state->s0;
    ulong s0 = state->s1;
    state->s0 = s0;
    s1 ^= s1 << 23;
    state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
    return float(state->s0 + state->s1) * 5.421010862427522e-20f;
}

/// SplitMix64's mixing function — a bijection with avalanche good enough that
/// consecutive counter values give unrelated outputs.
inline ulong splitmix64(thread ulong* x) {
    ulong z = (*x += 0x9E3779B97F4A7C15UL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
    return z ^ (z >> 31);
}

/// Give thread `tid` its own xorshift128+ stream, derived from `baseSeed`.
///
/// This was `s0 = baseSeed ^ tid`, `s1 = (baseSeed >> 32) ^ (tid << 32)` with ten
/// warm-up draws. Xorshift128+ is GF(2)-linear in its state, so the difference
/// between two threads seeded that way is itself a xorshift trajectory from a
/// one-bit delta and does not diffuse — measured cross-thread lag-1 correlation was
/// +0.26, and warm-up wandered rather than decayed. Base seed 0 also gave thread 0
/// the all-zero state, which is absorbing. Read the reasoning in MetalShaderSource.
inline void seedRNGState(device RNGState* state, ulong baseSeed, uint tid) {
    ulong x = baseSeed + ulong(tid) * 0x9E3779B97F4A7C15UL;
    state->s0 = splitmix64(&x);
    state->s1 = splitmix64(&x);
    if (state->s0 == 0 && state->s1 == 0) { state->s1 = 1; }
}

/// Move a uniform onto (0, 1], the interval Box-Muller requires.
///
/// `nextUniform` scales a ulong by 2^-64 through a float, and the conversion keeps
/// only 24 bits, so states near ULONG_MAX round up to exactly 1.0f: the interval is
/// closed. `1 - u` is therefore not safe here the way it is in Double. Moving only
/// the degenerate point is: u = 1 has radius 0, one point of measure zero mapped
/// onto another, where `max(u, eps)` would collapse an interval and leave an atom.
inline float boxMullerUniform(float u) {
    return u > 0.0f ? u : 1.0f;
}

/// Generate normal pair using Box-Muller transform
inline float2 nextNormal(device RNGState* state, float mean, float stdDev) {
    float u1 = boxMullerUniform(nextUniform(state));
    float u2 = nextUniform(state);
    float r = sqrt(-2.0f * log(u1));
    float theta = 2.0f * M_PI_F * u2;
    return float2(
        mean + stdDev * r * cos(theta),
        mean + stdDev * r * sin(theta)
    );
}

/// Generate single normal sample
inline float nextNormalSingle(device RNGState* state, float mean, float stdDev) {
    return nextNormal(state, mean, stdDev).x;
}

// MARK: - Distribution Sampler Implementations

/// Sample from Normal distribution
inline float sampleNormal(device RNGState* state, constant DistributionParams* params) {
    return nextNormal(state, params->param1, params->param2).x;
}

/// Sample from Uniform distribution
inline float sampleUniform(device RNGState* state, constant DistributionParams* params) {
    float min = params->param1;
    float max = params->param2;
    return min + nextUniform(state) * (max - min);
}

/// Sample from Triangular distribution
inline float sampleTriangular(device RNGState* state, constant DistributionParams* params) {
    float min = params->param1;
    float max = params->param2;
    float mode = params->param3;

    float u = nextUniform(state);
    float fc = (mode - min) / (max - min);

    if (u < fc) {
        return min + sqrt(u * (max - min) * (mode - min));
    } else {
        return max - sqrt((1.0f - u) * (max - min) * (max - mode));
    }
}

/// Sample from Exponential distribution
inline float sampleExponential(device RNGState* state, constant DistributionParams* params) {
    float rate = params->param1;
    return -log(1.0f - nextUniform(state)) / rate;
}

/// Sample from Lognormal distribution
inline float sampleLognormal(device RNGState* state, constant DistributionParams* params) {
    float logMean = params->param1;
    float logStdDev = params->param2;
    return exp(nextNormal(state, logMean, logStdDev).x);
}

/// Sample from any distribution type
inline float sampleDistribution(device RNGState* state, constant DistributionParams* params, int distType) {
    switch (distType) {
        case DIST_NORMAL: return sampleNormal(state, params);
        case DIST_UNIFORM: return sampleUniform(state, params);
        case DIST_TRIANGULAR: return sampleTriangular(state, params);
        case DIST_EXPONENTIAL: return sampleExponential(state, params);
        case DIST_LOGNORMAL: return sampleLognormal(state, params);
        default: return 0.0f;
    }
}

#endif // MONTE_CARLO_COMMON_H
