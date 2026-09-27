//
//  ascendingSample.swift
//  BusinessMath
//

import Foundation

/// A sample sorted ascending, or `nil` when it contains a value that cannot be ordered.
///
/// `Array.sorted()` is not well defined on floating-point data containing `nan`. Every
/// comparison involving a `nan` is false, so `<` is not a strict weak ordering over such a
/// collection and the result is unspecified. That is not a theoretical concern — measured:
///
/// ```
/// [3, 1, nan, 2, 5, 4].sorted()  ==  [1, 3, nan, 2, 4, 5]
/// ```
///
/// The *valid* elements come back out of order. A `nan` does not merely occupy a slot in the
/// result; it corrupts the ordering of the real data around it, and any index-based statistic
/// computed afterwards is reading a mis-ordered array.
///
/// ``quantile(sorted:p:)`` states this precondition explicitly — "sort order is undefined in
/// their presence, so screen them out before calling" — and this is that screen, in one place
/// so its callers cannot each forget it differently. They did: before this existed, the same
/// valid data gave `var95` of `nan`, `1.45` and `1.45` depending only on whether the `nan` sat
/// first, in the middle, or last, an ordering that is meaningless to a percentile.
///
/// Infinities are left alone. They order correctly and are a legitimate observation in a
/// return series; only `nan` breaks the sort.
///
/// - Parameter values: The sample, in any order.
/// - Returns: The sample in ascending order, or `nil` if any element is `nan`.
/// - Complexity: O(*n* log *n*), with one extra O(*n*) pass to screen.
internal func ascendingSample<T: BinaryFloatingPoint>(_ values: [T]) -> [T]? {
	guard !values.contains(where: { $0.isNaN }) else { return nil }
	return values.sorted()
}
