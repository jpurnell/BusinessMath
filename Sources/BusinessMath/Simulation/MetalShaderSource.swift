//
//  MetalShaderSource.swift
//  BusinessMath
//
//  The one Metal Shading Language definition of the GPU random source.
//

import Foundation

/// Metal Shading Language source shared by the package's GPU kernels.
///
/// It sits beside ``boxMullerSeed(using:)`` and ``DeterministicRNG`` deliberately: this
/// is the same subject in a second language, and keeping it in the same directory is
/// the cheapest way for anyone changing one to notice the other.
///
/// ## Why this is a Swift string and not a `.metal` file
///
/// The kernels cannot call ``boxMullerSeed(using:)``. They are MSL compiled for the GPU,
/// so the arithmetic has to exist a second time, in Float32, on the other side of the
/// language boundary. That much is unavoidable. What is avoidable is having it exist a
/// fourth and a fifth time.
///
/// Every `.metal` file in this package is listed in `Package.swift`'s `exclude:`, so SPM
/// never compiles them and a Metal toolchain is never required to build. Every kernel
/// that actually runs is compiled at launch by `MTLDevice.makeLibrary(source:)` from a
/// Swift string. A `.metal` file and a Swift string literal cannot share text without a
/// build step that embeds one in the other, which would reintroduce the toolchain
/// dependency the `exclude:` exists to avoid.
///
/// So the consolidation that is actually achievable is this: one Swift constant,
/// interpolated into every kernel source that needs it. The ahead-of-time copy in
/// `MonteCarloCommon.h` is a hand-maintained mirror and says so at the top.
///
/// ## The pole guard, and why it is not `1 - u`
///
/// The Swift transform draws `u₁` as `1 - Double.random(in: 0..<1)`, which is exact,
/// measure-preserving, and never reaches zero. That reasoning does not survive the
/// crossing into Float32.
///
/// `nextUniform` returns `float(s0 + s1) * 2⁻⁶⁴`. Converting a `ulong` to `float` keeps
/// 24 bits, so every state within 2048 of `ULONG_MAX` rounds *up* to exactly 2⁶⁴ and the
/// uniform comes out as exactly `1.0f` — the interval is closed, not half-open. And
/// `1.0f - 1.0f` is zero, which is the pole the guard was meant to avoid. The same
/// applies to `random_float` in `MetalDevice.swift`: `float(uint) / 2³²` rounds to
/// `1.0f` for the top 128 hashes, about 3e-8 of draws.
///
/// What holds in both precisions is to move only the degenerate point. `u₁ = 1` has
/// radius 0, which is the correct value for that draw — one point of measure zero
/// mapped onto another, so no interval is collapsed and no value carries an atom.
/// `max(u1, 1e-10f)` would put one at radius 6.79.
///
/// None of this was hurting anyone. At Float32 resolution the affected draws are a few
/// parts in 10⁸, and each of the previous clamps kept every result finite. The guards
/// are made the same because four different answers to one question is how the header
/// and the string came to disagree in the first place.
internal enum MetalShaderSource {

	/// Moves a uniform onto `(0, 1]`, the interval Box-Muller requires.
	///
	/// Emitted on its own because the two kernel families do not share a generator —
	/// the Monte Carlo kernels carry an `RNGState` and the genetic-algorithm kernels
	/// hash a per-thread seed — but they must share this.
	static let boxMullerUniform = """
	// Box-Muller needs u1 in (0, 1]; log(0) is -infinity. Both of this package's GPU
	// uniforms are *closed* [0, 1] once rounded to Float32, so `1 - u` is not safe
	// here the way it is in Double. Move only the degenerate point, to 1, whose
	// radius is 0. A clamp such as max(u1, 1e-10f) would instead collapse an interval
	// of draws onto one radius and leave a point mass there.
	inline float boxMullerUniform(float u) {
	    return u > 0.0f ? u : 1.0f;
	}
	"""

	/// `RNGState`, `seedRNGState`, `nextUniform`, and `nextNormal`, in both the `thread`
	/// and `device` address spaces, with ``boxMullerUniform`` included.
	///
	/// Interpolate into a kernel source string after `#include <metal_stdlib>` and
	/// `using namespace metal;`. Both address-space overloads are always emitted; MSL
	/// discards the unused `inline` definitions.
	///
	/// ## Why the seeding is here and not at the call site
	///
	/// The generator and the way its state is initialised are one subject, and splitting
	/// them is what allowed the package to ship a sound xorshift128+ seeded in a way that
	/// made adjacent threads dependent. `seedRNGState` is emitted alongside the generator
	/// so a kernel cannot obtain one without the other, and so the three test kernels
	/// that measure this cannot measure a seeding production does not use.
	static let randomNumberGeneration = """
	struct RNGState {
	    ulong s0;
	    ulong s1;
	};

	// SplitMix64's mixing function, from Steele, Lea and Flood (2014). A bijection on
	// the 64-bit words with avalanche good enough that consecutive counter values give
	// unrelated outputs — which is the property the seeding below is buying.
	inline ulong splitmix64(thread ulong* x) {
	    ulong z = (*x += 0x9E3779B97F4A7C15UL);
	    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
	    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
	    return z ^ (z >> 31);
	}

	// One xorshift128+ stream per thread, from one base seed.
	//
	// Every GPU thread here is one Monte Carlo iteration, so "thread t's stream" and
	// "iteration t" are the same thing and a dependence between neighbouring threads is
	// a dependence between neighbouring iterations of the simulation.
	//
	// This used to be `s0 = baseSeed ^ tid`, `s1 = (baseSeed >> 32) ^ (tid << 32)`, with
	// ten warm-up draws. Xorshift128+ is GF(2)-linear in its state, so the difference
	// between two threads seeded that way is itself a xorshift trajectory starting from
	// a one- or two-bit delta, and it does not diffuse: measured cross-thread lag-1
	// correlation was +0.26, and warm-up moved it around (+0.10 at 20 rounds, +0.17 at
	// 50, -0.10 at 100) rather than decaying it. Base seed 0 was worse still — thread 0
	// got s0 = s1 = 0, xorshift128+'s absorbing state, and emitted 0.0f forever.
	//
	// SplitMix64 seed-splitting is the standard remedy and is what xoshiro's authors
	// specify. Each thread's counter starts a full golden-ratio step from its
	// neighbour's and the two 64-bit words come from separate mixes, so the states are
	// unrelated before the first draw. Measured on the same statistic: median |rho|
	// 0.002 at every lag from 1 to 5.
	//
	// There is no warm-up loop, and that is deliberate rather than an omission. Warm-up
	// bought nothing here even before the fix, and after it there is nothing left to
	// warm up: over twelve base seeds the median cross-thread |rho| is 0.0021 with zero
	// rounds against 0.0035 with ten, and the per-statistic RMSE of a 10,000-iteration
	// N(0, 1) dispatch matches its theoretical sampling error either way. Keeping the
	// loop would have kept a mitigation that never worked, over a defect that is gone.
	//
	// The zero-state guard is unreachable and kept anyway. splitmix64 is a bijection
	// with mix(0) == 0, so s0 == 0 requires the counter to be zero after its first
	// increment, and the second mix then returns mix(0x9E3779B97F4A7C15), which is not
	// zero. The guard costs one comparison and stops a future change to the mixing from
	// silently reintroducing an absorbing state.
	inline void seedRNGState(thread RNGState* state, ulong baseSeed, uint tid) {
	    ulong x = baseSeed + ulong(tid) * 0x9E3779B97F4A7C15UL;
	    state->s0 = splitmix64(&x);
	    state->s1 = splitmix64(&x);
	    if (state->s0 == 0 && state->s1 == 0) { state->s1 = 1; }
	}

	inline void seedRNGState(device RNGState* state, ulong baseSeed, uint tid) {
	    ulong x = baseSeed + ulong(tid) * 0x9E3779B97F4A7C15UL;
	    state->s0 = splitmix64(&x);
	    state->s1 = splitmix64(&x);
	    if (state->s0 == 0 && state->s1 == 0) { state->s1 = 1; }
	}

	// Xorshift128+. The scale is 2^-64; note that converting a ulong to float keeps
	// only 24 bits, so the result is a *closed* [0, 1] — 1.0f is attainable.
	inline float nextUniform(thread RNGState* state) {
	    ulong s1 = state->s0;
	    ulong s0 = state->s1;
	    state->s0 = s0;
	    s1 ^= s1 << 23;
	    state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
	    return float(state->s0 + state->s1) * 5.421010862427522e-20f;
	}

	inline float nextUniform(device RNGState* state) {
	    ulong s1 = state->s0;
	    ulong s0 = state->s1;
	    state->s0 = s0;
	    s1 ^= s1 << 23;
	    state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
	    return float(state->s0 + state->s1) * 5.421010862427522e-20f;
	}

	\(boxMullerUniform)

	// The pair shares a radius and differs only in the angle. Keep .x the cosine
	// branch: it is the variate every call site here already took.
	inline float2 nextNormal(thread RNGState* state, float mean, float stdDev) {
	    float u1 = boxMullerUniform(nextUniform(state));
	    float u2 = nextUniform(state);
	    float r = sqrt(-2.0f * log(u1));
	    float theta = 2.0f * M_PI_F * u2;
	    return float2(mean + stdDev * r * cos(theta), mean + stdDev * r * sin(theta));
	}

	inline float2 nextNormal(device RNGState* state, float mean, float stdDev) {
	    float u1 = boxMullerUniform(nextUniform(state));
	    float u2 = nextUniform(state);
	    float r = sqrt(-2.0f * log(u1));
	    float theta = 2.0f * M_PI_F * u2;
	    return float2(mean + stdDev * r * cos(theta), mean + stdDev * r * sin(theta));
	}
	"""
}
