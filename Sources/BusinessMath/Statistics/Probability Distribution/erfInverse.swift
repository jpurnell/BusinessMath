//
//  erfInverse.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// erfInv allows us to calculate the zScore for a desired Area under a normal curve without having to rely on a lookup table
// https://stackoverflow.com/questions/36784763/is-there-an-inverse-error-public function-available-in-swifts-foundation-import

/// Computes the inverse of the error function.
///
/// The error function (also called the Gauss error function) is a special function of probability theory and statistics. This method implements the inverse error function, also known as the quantile function or the percent-point function `erf-1()`. The quantile function is the function that, given a probability `y`, returns a value `x` such that `Pr[X <= x] = y`. It's particularly important in statistics for generating values of random variables for a given probability.
///
/// - Parameter y: The probability for which to find `x`.
///
/// - Returns: The value `x` that corresponds to the given `y` probability when passed to the error function. If `abs(y)` equals `1`, it returns `y * T(Int.max)`. If `abs(y)` is greater than `1`, it returns `.nan`.
///
/// - Precondition: `y` should be a value between `-1` and `1` (inclusive).
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let y = 0.5
///     let result = erfInv(y: y)
///     print(result)
///
/// Use this function when you need to perform a quantile function or percent-point function operation on your dataset.
public func erfInv<T: Real>(y: T) -> T {
    let center = T(7) / T(10)
	let a:[T] = [ T(Int(0886226899 as Double)) / T(Int(1000000000.0)), T(Int(-1645349621 as Double)) / T(Int(1000000000.0)),  T(Int(0914624893 as Double)) / T(Int(1000000000.0)), T(Int(-0140543331 as Double)) / T(Int(1000000000.0))]
	let b:[T] = [T(Int(-2118377725 as Double)) / T(Int(1000000000.0)),  T(Int(1442710462 as Double)) / T(Int(1000000000.0)), T(Int(-0329097515 as Double)) / T(Int(1000000000.0)),  T(Int(0012229801 as Double)) / T(Int(1000000000.0))]
	let c:[T] = [T(Int(-1970840454 as Double)) / T(Int(1000000000.0)), T(Int(-1624906493 as Double)) / T(Int(1000000000.0)),  T(Int(3429567803 as Double)) / T(Int(1000000000.0)),  T(Int(1641345311 as Double)) / T(Int(1000000000.0))]
	let d:[T] = [ T(Int(3543889200 as Double)) / T(Int(1000000000.0)),  T(Int(1637067800 as Double)) / T(Int(1000000000.0))]
    if abs(y) <= center {
        let z = T.pow(y,2)
        let num = (((a[3]*z + a[2])*z + a[1])*z) + a[0]
        let den = ((((b[3]*z + b[2])*z + b[1])*z + b[0])*z + T(1))
        var x = y*num/den
        x = x - (T.erf(x) - y)/(T(2)/T.sqrt(.pi)*T.exp(-x*x))
        x = x - (T.erf(x) - y)/(T(2)/T.sqrt(.pi)*T.exp(-x*x))
        return x
    }
    else if abs(y) > center && abs(y) < T(1) {
        let z = T.pow(-1 * T.log((T(1) - abs(y))/T(2)), (T(1) / T(2)))
//        let z = T.pow(-T.log((T(1)-abs(y))/T(2)),0.5)
        let num = ((c[3]*z + c[2])*z + c[1])*z + c[0]
        let den = (d[1]*z + d[0])*z + T(1)

        var x = y/T.pow(T.pow(y,2),(T(1) / T(2)))*num/den
        x = x - (T.erf(x) - y)/(T(2)/T.sqrt(.pi)*T.exp(-x*x))
        x = x - (T.erf(x) - y)/(T(2)/T.sqrt(.pi)*T.exp(-x*x))
        return x
    } else if abs(y) == T(1) {
        return y * T(Int.max)
    } else {
        return .nan
    }
}
