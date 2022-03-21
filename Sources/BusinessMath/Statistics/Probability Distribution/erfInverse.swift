//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// erfInv allows us to calculate the zScore for a desired Area under a normal curve without having to rely on a lookup table
// https://stackoverflow.com/questions/36784763/is-there-an-inverse-error-public function-available-in-swifts-foundation-import

public func erfInv<T: Real>(y: T) -> T {
    let center = T(7) / T(10)
    let a:[T] = [ T(0886226899) / T(1000000000), T(-1645349621) / T(1000000000),  T(0914624893) / T(1000000000), T(-0140543331) / T(1000000000)]
    let b:[T] = [T(-2118377725) / T(1000000000),  T(1442710462) / T(1000000000), T(-0329097515) / T(1000000000),  T(0012229801) / T(1000000000)]
    let c:[T] = [T(-1970840454) / T(1000000000), T(-1624906493 ) / T(1000000000),  T(3429567803) / T(1000000000),  T(1641345311) / T(1000000000)]
    let d:[T] = [ T(3543889200) / T(1000000000),  T(1637067800) / T(1000000000)]
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
