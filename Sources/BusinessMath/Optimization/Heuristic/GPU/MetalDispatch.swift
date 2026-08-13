//
//  MetalDispatch.swift
//  BusinessMath
//
//  Dispatching exactly as many threads as there is work.
//

#if canImport(Metal)
import Metal

// MARK: - Exact dispatch

extension MTLComputeCommandEncoder {

	/// Dispatches exactly `threadCount` threads, with no surplus.
	///
	/// The idiom this replaces rounds the threadgroup count up:
	///
	/// ```swift
	/// let per    = MTLSize(width: min(count, 256), height: 1, depth: 1)
	/// let groups = MTLSize(width: (count + 255) / 256, height: 1, depth: 1)
	/// encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: per)
	/// ```
	///
	/// At `count = 1200` that dispatches 1280 threads for 1200 elements, and the 80 surplus
	/// threads run the kernel body. Every kernel then has to bound its own thread id or it
	/// reads and writes past its buffers — silently, and only at counts that are not a
	/// multiple of the threadgroup width, which is why a seeded run reproduced at 1024 and
	/// not at 1200.
	///
	/// `dispatchThreads(_:threadsPerThreadgroup:)` sizes the last threadgroup to fit, so the
	/// surplus does not exist. The in-kernel bounds guards remain — they are correct
	/// independently and cost one comparison — but they are no longer the only thing
	/// standing between a non-aligned count and undefined behaviour.
	///
	/// - Parameters:
	///   - threadCount: The number of elements to process. One thread each.
	///   - width: Threads per threadgroup, clamped to `threadCount`.
	/// - Precondition: Requires non-uniform threadgroup support; see
	///   ``MTLDevice/supportsNonUniformThreadgroups``. Callers gate on it before choosing
	///   the GPU at all, so reaching here without it is a programming error rather than a
	///   runtime condition.
	internal func dispatchExactly(_ threadCount: Int, width: Int = 256) {
		guard threadCount > 0 else { return }

		let threadsPerGroup = MTLSize(width: Swift.min(threadCount, width), height: 1, depth: 1)
		dispatchThreads(MTLSize(width: threadCount, height: 1, depth: 1), threadsPerThreadgroup: threadsPerGroup)
	}

	/// Two-dimensional form, for kernels indexed by `uint2`.
	///
	/// - Parameters:
	///   - rows: Extent in the y dimension.
	///   - columns: Extent in the x dimension.
	///   - tile: Threadgroup edge length, clamped to each extent.
	internal func dispatchExactly(rows: Int, columns: Int, tile: Int = 16) {
		guard rows > 0, columns > 0 else { return }

		let threadsPerGroup = MTLSize(
			width: Swift.min(columns, tile),
			height: Swift.min(rows, tile),
			depth: 1
		)
		dispatchThreads(MTLSize(width: columns, height: rows, depth: 1), threadsPerThreadgroup: threadsPerGroup)
	}
}

// MARK: - Capability

extension MTLDevice {

	/// Whether the device sizes the final threadgroup to fit rather than rounding up.
	///
	/// True on every Apple GPU family and on Mac 2. Where it is false the only ways to
	/// dispatch are to round up — reintroducing surplus threads — or not to use the GPU,
	/// and every GPU path in this library has a CPU implementation to fall back to. The
	/// callers therefore treat this as part of "is the GPU usable here", alongside the
	/// device existing and the population being large enough to be worth it.
	internal var supportsNonUniformThreadgroups: Bool {
		if #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) {
			return supportsFamily(.apple4) || supportsFamily(.mac2)
		}
		return false
	}
}
#endif
