//
//  MetalShaderSourceTests.swift
//  BusinessMath
//
//  The shared MSL text has to compile, and its pole guard has to work on the GPU.
//

import Foundation
import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// ``MetalShaderSource`` is interpolated into two kernel sources that are compiled at
/// launch. Both call sites treat a compilation failure as "GPU unavailable" and fall
/// back to the CPU — `MonteCarloGPUDevice.init?` returns nil, `MetalDevice.shared`
/// returns nil, and every GPU test in this package then `guard`s itself out.
///
/// So a syntax error in the shared text would not fail anything. It would silently
/// turn the GPU path off across the whole package and leave a green test run behind.
/// These tests are the thing that notices.
@Suite("Metal Shader Source")
struct MetalShaderSourceTests {

	#if canImport(Metal)

	/// Whether this machine can compile MSL at runtime at all.
	///
	/// Having an `MTLDevice` is not the same as having a shader compiler — a bare
	/// device with no toolchain would make every assertion below fail for a reason
	/// that has nothing to do with the text under test. Compiling a trivial kernel
	/// first separates the two, so a skip means "no compiler" and a failure means
	/// "our source is broken".
	private func compiler() -> MTLDevice? {
		guard let device = MTLCreateSystemDefaultDevice() else { return nil }
		let trivial = """
		#include <metal_stdlib>
		using namespace metal;
		kernel void trivial(device float* out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
		    out[tid] = 1.0f;
		}
		"""
		guard (try? device.makeLibrary(source: trivial, options: nil)) != nil else { return nil }
		return device
	}

	@Test("The shared RNG source compiles")
	func sharedSourceCompiles() throws {
		guard let device = compiler() else { return }

		let source = """
		#include <metal_stdlib>
		using namespace metal;

		\(MetalShaderSource.randomNumberGeneration)

		kernel void drawNormals(
		    device RNGState* states [[buffer(0)]],
		    device float2* outputs [[buffer(1)]],
		    uint tid [[thread_position_in_grid]]
		) {
		    outputs[tid] = nextNormal(&states[tid], 0.0f, 1.0f);
		}
		"""

		let library = try device.makeLibrary(source: source, options: nil)
		#expect(library.makeFunction(name: "drawNormals") != nil)
	}

	/// The guard, executed on the GPU rather than reasoned about.
	///
	/// An all-zero `RNGState` is a fixed point of xorshift128+: `s0 + s1` stays zero,
	/// so `nextUniform` returns exactly `0.0f` on every call. Unguarded that is
	/// `log(0) = -inf` and a non-finite variate. Guarded, `u₁` moves to 1 and the
	/// radius is 0, so both variates are exactly the mean.
	@Test("The pole guard holds on the GPU")
	func poleGuardHoldsOnDevice() throws {
		guard let device = compiler() else { return }

		let source = """
		#include <metal_stdlib>
		using namespace metal;

		\(MetalShaderSource.randomNumberGeneration)

		kernel void drawFromZeroState(
		    device float2* outputs [[buffer(0)]],
		    uint tid [[thread_position_in_grid]]
		) {
		    RNGState state;
		    state.s0 = 0;
		    state.s1 = 0;
		    outputs[tid] = nextNormal(&state, 7.0f, 3.0f);
		}
		"""

		let library = try device.makeLibrary(source: source, options: nil)
		let function = try #require(library.makeFunction(name: "drawFromZeroState"))
		let pipeline = try device.makeComputePipelineState(function: function)
		let queue = try #require(device.makeCommandQueue())

		let count = 8
		let buffer = try #require(device.makeBuffer(length: count * MemoryLayout<SIMD2<Float>>.stride,
													options: .storageModeShared))

		let commands = try #require(queue.makeCommandBuffer())
		let encoder = try #require(commands.makeComputeCommandEncoder())
		encoder.setComputePipelineState(pipeline)
		encoder.setBuffer(buffer, offset: 0, index: 0)
		encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
									 threadsPerThreadgroup: MTLSize(width: count, height: 1, depth: 1))
		encoder.endEncoding()
		commands.commit()
		commands.waitUntilCompleted()

		let values = buffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: count)
		for i in 0..<count {
			let pair = values[i]
			#expect(pair.x.isFinite && pair.y.isFinite, "draw \(i) was \(pair)")
			// Exact by construction, so compared bit-for-bit: the radius is 0, and
			// `7.0f + 3.0f * 0` is 7.0f with no rounding. A tolerance here would accept
			// a radius that was merely small — which is the unguarded pole's other
			// failure mode, and the one this test exists to exclude.
			#expect(identical(pair.x, 7.0),
					"u₁ = 1 has radius 0, so z₁ is the mean; got \(pair)")
			#expect(identical(pair.y, 7.0),
					"u₁ = 1 has radius 0, so z₂ is the mean; got \(pair)")
		}
	}

	/// The two production kernel sources, compiled the way production compiles them.
	///
	/// This is the assertion that would have caught a broken interpolation: both of
	/// these return `nil` rather than throwing, and every other GPU test in the
	/// package reads that `nil` as "no GPU here" and passes.
	@Test("Both production kernel libraries still build")
	func productionKernelsCompile() {
		guard compiler() != nil else { return }
		#expect(MonteCarloGPUDevice() != nil,
				"the Monte Carlo kernel source failed to compile — the GPU path is silently off")
		#expect(MetalDevice.shared != nil,
				"the heuristic kernel source failed to compile — the GPU path is silently off")
	}

	#endif
}
