//
//  frequencyDistribution.swift
//  BusinessMath
//
//  Created by Justin Purnell on 6/6/24.
//

import Foundation
import Numerics

func minimumClasses<T: Real>(_ values: [T]) -> Int {
	var i = 1
	while T.pow(2.0, i) < T(values.count) {
		i += 1
	}
	return i
}

func classInterval<T: Real>(_ values: [T], classes: Int) -> T {
	var classNumber = classes
	guard let classes >= 1 else { classNumber = minimumClasses(values)}
	let sorted = values.sorted(by: {$0 < $1})
	let interval = (values[0] - values[values.count - 1]) / T(classes)
	return interval
}

extension Sequence where Element: Hashable {
	func histogram() -> [Element: Int] {
		return self.reduce(into: [:]) { counts, elem in counts[elem, default: 0] += 1 }
	}
}

func histogram<T: Real>(_ values: [T], classes: Int) -> [T: Int] {
	var classNumber = classes
	guard let classes >= 1 else { classNumber = minimumClasses(values)}
	let interval = classInterval(values, classes: classNumber)
	let breakpoints = stride(from: values.min()!, through: values.max()!, by: interval)
	let intervalDictionary = breakpoints.flatMap({ [$0: []] })
	for i in 0..<intervalDictionary.count - 1 {
		for value in values.sorted(by: <) {
			let last = intervalDictionary.count - 1
			if value > intervalDictionary[last].key { intervalDictionary[last].value.append(value); continue }
			let first = (value >= intervalDictionary[i].key)
			let second = (value < intervalDictionary[i + 1].key)
			let fits = first == true && second == true
			if fits == true { intervalDictionary[i].value.append(value)}
		}
	}
	return intervalDictionary.map({$0.key: $0.value.count})
}


