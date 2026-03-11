//
//  Array2D.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// A generic two-dimensional array structure for matrix-style data storage.
///
/// `Array2D` provides efficient row-major storage for tabular data, commonly used
/// for storing ranking matrices and calculating statistical measures like
/// Kendall's W coefficient of concordance.
///
/// ## Overview
///
/// The `Array2D` structure uses row-major storage, meaning elements in the same row
/// are stored contiguously in memory. This is efficient for operations that process
/// data row by row.
///
/// ## Usage Example
///
/// ```swift
/// // Create a 3x4 matrix (3 columns, 4 rows) initialized with zeros
/// var matrix = Array2D<Double>(columns: 3, rows: 4, initialValue: 0.0)
///
/// // Set values using [column, row] subscript
/// matrix[0, 0] = 1.0
/// matrix[1, 1] = 5.0
/// matrix[2, 2] = 9.0
///
/// // Get a value
/// let value = matrix[1, 1]  // Returns 5.0
/// ```
///
/// ## Statistical Methods
///
/// When `T` conforms to `Real`, `Array2D` provides methods for calculating
/// ranking statistics:
///
/// ```swift
/// var ranks = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)
/// // Fill with ranking data from 3 judges rating 4 items...
///
/// let w: Double = ranks.kendallW()  // Coefficient of concordance
/// let f: Double = ranks.fStatistic()  // F-statistic
/// let d: Double = ranks.dValue()  // Sum of squared deviations
/// ```
///
/// ## Mathematical Background
///
/// For ranking matrices where rows represent judges and columns represent items,
/// the structure supports computation of:
///
/// - **Rank sums**: Sum of ranks for each item across all judges
/// - **Kendall's W**: Coefficient of concordance measuring agreement [0, 1]
/// - **F-statistic**: F = (m-1)W / (1-W) for hypothesis testing
/// - **D-value**: Sum of squared deviations from the center rank
///
/// - Note: This structure is `Sendable` when the element type `T` is `Sendable`,
///   making it safe for concurrent access.
public struct Array2D<T: Sendable>: Sendable {
    /// The number of columns in the array.
    public let columns: Int

    /// The number of rows in the array.
    public let rows: Int

    /// Internal storage using row-major order.
    fileprivate var array: [T]

    /// Creates a new two-dimensional array with the specified dimensions.
    ///
    /// All cells are initialized with the provided initial value.
    ///
    /// - Parameters:
    ///   - columns: The number of columns in the array. Must be positive.
    ///   - rows: The number of rows in the array. Must be positive.
    ///   - initialValue: The value to fill all cells with initially.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let matrix = Array2D<Int>(columns: 5, rows: 3, initialValue: 0)
    /// // Creates a 5x3 matrix filled with zeros
    /// ```
    public init(columns: Int, rows: Int, initialValue: T) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        array = Array(repeating: initialValue, count: self.rows * self.columns)
    }

    /// Accesses the element at the specified column and row.
    ///
    /// - Parameters:
    ///   - column: The column index (0-based).
    ///   - row: The row index (0-based).
    ///
    /// - Returns: The element at the specified position.
    ///
    /// - Note: If indices are out of bounds, returns the element at index 0,0
    ///   to avoid crashes. Check bounds before accessing if needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var matrix = Array2D<Int>(columns: 3, rows: 3, initialValue: 0)
    /// matrix[1, 2] = 42  // Set value at column 1, row 2
    /// let value = matrix[1, 2]  // Get value: 42
    /// ```
    public subscript(column: Int, row: Int) -> T {
        get {
            guard column >= 0, column < columns, row >= 0, row < rows else {
                return array[0]
            }
            return array[row * columns + column]
        }
        set {
            guard column >= 0, column < columns, row >= 0, row < rows else {
                return
            }
            array[row * columns + column] = newValue
        }
    }
}

// MARK: - Statistical Methods

extension Array2D where T: Real {
    /// Calculates the sum of values in a specified column.
    ///
    /// This is commonly used to compute rank sums for each item (column)
    /// across all judges (rows).
    ///
    /// - Parameter column: The column index (0-based).
    ///
    /// - Returns: The sum of all elements in the specified column.
    ///   Returns 0 if the column index is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var matrix = Array2D<Double>(columns: 3, rows: 3, initialValue: 0.0)
    /// matrix[1, 0] = 1.0
    /// matrix[1, 1] = 2.0
    /// matrix[1, 2] = 3.0
    ///
    /// let sum: Double = matrix.getRankSum(for: 1)  // Returns 6.0
    /// ```
    public func getRankSum(for column: Int) -> T {
        guard column >= 0, column < columns else { return T(0) }
        var sum = T(0)
        for row in 0..<rows {
            sum += array[row * columns + column]
        }
        return sum
    }

    /// Calculates the average of values in a specified column.
    ///
    /// - Parameter column: The column index (0-based).
    ///
    /// - Returns: The arithmetic mean of all elements in the specified column.
    ///   Returns 0 if the column index is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var matrix = Array2D<Double>(columns: 3, rows: 4, initialValue: 0.0)
    /// // Set column 0 to [2, 4, 6, 8]
    /// matrix[0, 0] = 2.0
    /// matrix[0, 1] = 4.0
    /// matrix[0, 2] = 6.0
    /// matrix[0, 3] = 8.0
    ///
    /// let avg: Double = matrix.getAvgRank(for: 0)  // Returns 5.0
    /// ```
    public func getAvgRank(for column: Int) -> T {
        guard rows > 0 else { return T(0) }
        let rankSum: T = getRankSum(for: column)
        return rankSum / T(rows)
    }

    /// Calculates the D-value (sum of squared deviations from center).
    ///
    /// The D-value measures the total deviation of rank sums from the expected
    /// center value, useful in concordance analysis.
    ///
    /// The formula is: D = Σ(Ri - center)²
    ///
    /// where:
    /// - Ri = rank sum for item i
    /// - center = n(m+1)/2 (expected rank sum if ranks were randomly distributed)
    /// - n = number of judges (rows)
    /// - m = number of items (columns)
    ///
    /// - Returns: The sum of squared deviations from the center.
    ///
    /// - Complexity: O(rows × columns) for computing all rank sums.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var ranks = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)
    /// // Fill with perfect agreement ranks...
    /// for row in 0..<3 {
    ///     for col in 0..<4 {
    ///         ranks[col, row] = Double(col + 1)
    ///     }
    /// }
    ///
    /// let d: Double = ranks.dValue()
    /// // Rank sums: [3, 6, 9, 12], center = 7.5
    /// // D = (3-7.5)² + (6-7.5)² + (9-7.5)² + (12-7.5)² = 45.0
    /// ```
    public func dValue() -> T {
        let center: T = T(rows * (columns + 1)) / T(2)
        var sum = T(0)
        for col in 0..<columns {
            let rankSum: T = getRankSum(for: col)
            let deviation = rankSum - center
            sum += deviation * deviation
        }
        return sum
    }

    /// Calculates Kendall's W coefficient of concordance.
    ///
    /// Kendall's W measures the agreement among multiple judges (raters) ranking
    /// multiple items. Values range from 0 (no agreement) to 1 (perfect agreement).
    ///
    /// The formula is: W = 12S / (n²(k³-k))
    ///
    /// where:
    /// - S = Σ(Ri - R̄)² (sum of squared deviations from mean rank sum)
    /// - n = number of judges (rows)
    /// - k = number of items (columns)
    ///
    /// - Returns: The Kendall's W coefficient in range [0, 1].
    ///   Returns 0 if there's insufficient data for calculation.
    ///
    /// - Complexity: O(rows × columns).
    ///
    /// ## Example
    ///
    /// ```swift
    /// var ranks = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)
    /// // All judges rank identically
    /// for row in 0..<3 {
    ///     for col in 0..<4 {
    ///         ranks[col, row] = Double(col + 1)
    ///     }
    /// }
    ///
    /// let w: Double = ranks.kendallW()  // Returns ≈ 1.0 (perfect agreement)
    /// ```
    ///
    /// ## Statistical Interpretation
    ///
    /// | W Value | Interpretation |
    /// |---------|----------------|
    /// | 0.0     | No agreement beyond chance |
    /// | 0.3     | Weak agreement |
    /// | 0.5     | Moderate agreement |
    /// | 0.7     | Strong agreement |
    /// | 1.0     | Perfect agreement |
    public func kendallW() -> T {
        guard columns > 1 else { return T(0) }

        // Collect rank sums for all columns
        var rankSums: [T] = []
        for col in 0..<columns {
            rankSums.append(getRankSum(for: col))
        }

        // Use the internal function
        return kendallWFromRankSums(rankSums: rankSums, judges: rows, items: columns)
    }

    /// Calculates the F-statistic derived from Kendall's W.
    ///
    /// The F-statistic is used for hypothesis testing when comparing
    /// rankings. It transforms Kendall's W into a value that can be
    /// compared against the F-distribution.
    ///
    /// The formula is: F = (m-1) × W / (1-W)
    ///
    /// where:
    /// - m = number of items (columns)
    /// - W = Kendall's W coefficient
    ///
    /// - Returns: The F-statistic value. Returns 0 if W cannot be computed.
    ///   Approaches infinity as W approaches 1.
    ///
    /// - Note: The F-statistic has (m-1) numerator degrees of freedom
    ///   and n(m-1) denominator degrees of freedom.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var ranks = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)
    /// // Fill with ranking data...
    ///
    /// let f: Double = ranks.fStatistic()
    /// // Use with F-distribution for significance testing
    /// ```
    public func fStatistic() -> T {
        let w: T = kendallW()
        return BusinessMath.fStatistic(kendallW: w, items: columns)
    }
}

// MARK: - CustomStringConvertible

extension Array2D: CustomStringConvertible where T: CustomStringConvertible {
    /// A textual representation of the 2D array.
    ///
    /// Displays the matrix in a readable format with rows and columns aligned.
    public var description: String {
        var result = ""
        for row in 0..<rows {
            var rowValues: [String] = []
            for col in 0..<columns {
                rowValues.append(String(describing: self[col, row]))
            }
            result += rowValues.joined(separator: "\t") + "\n"
        }
        return result
    }
}

// MARK: - Equatable

extension Array2D: Equatable where T: Equatable {
    /// Returns a Boolean value indicating whether two 2D arrays are equal.
    ///
    /// Two `Array2D` instances are considered equal if they have the same
    /// dimensions and contain equal elements at corresponding positions.
    ///
    /// - Parameters:
    ///   - lhs: A 2D array to compare.
    ///   - rhs: Another 2D array to compare.
    ///
    /// - Returns: `true` if the arrays have equal dimensions and elements;
    ///   otherwise, `false`.
    public static func == (lhs: Array2D<T>, rhs: Array2D<T>) -> Bool {
        lhs.columns == rhs.columns && lhs.rows == rhs.rows && lhs.array == rhs.array
    }
}

// MARK: - Hashable

extension Array2D: Hashable where T: Hashable {
    /// Hashes the essential components of this 2D array.
    ///
    /// The hash value incorporates the dimensions and all elements,
    /// ensuring that equal arrays produce equal hash values.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(columns)
        hasher.combine(rows)
        hasher.combine(array)
    }
}
