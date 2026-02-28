import Testing
import Foundation
@testable import BusinessMath

@Suite("Anomaly Detection Tests")
struct AnomalyDetectionTests {

	// MARK: - Helper Functions

	private struct Deterministic01 {
		// seed must be in [0, 1)
		private var u: Double
		init(seed: Double) {
			var s = seed
			s = s - floor(s)
			if s == 1.0 { s = 0.0 }
			self.u = s
		}
		mutating func next() -> Double {
			// Add golden ratio conjugate and wrap to [0,1)
			let g = 0.6180339887498949
			var x = u + g
			x = x - floor(x)
			u = x
			return x
		}
	}
	
	func makeNormalData(seed: Double = 0.42) -> TimeSeries<Double> {
		let periods = (0..<100).map { Period.day(Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = []
		var seq = Deterministic01(seed: seed)
		let dist = DistributionUniform(-5.0, 5.0)

		for _ in 0..<100 {
			let jitter = dist.random(seq.next())
			values.append(100.0 + jitter)
		}
		return TimeSeries(periods: periods, values: values)
	}

	func makeDataWithAnomalies(seed: Double = 0.42) -> TimeSeries<Double> {
		let periods = (0..<100).map { Period.day(Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = []
		var seq = Deterministic01(seed: seed)
		let dist = DistributionUniform(-5.0, 5.0)

		for i in 0..<100 {
			if i == 50 {
				values.append(150.0)
			} else if i == 75 {
				values.append(50.0)
			} else {
				let jitter = dist.random(seq.next())
				values.append(100.0 + jitter)
			}
		}
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - Z-Score Detection

	@Test("Detect anomalies with z-score")
	func detectAnomaliesZScore() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeDataWithAnomalies()

		let anomalies = detector.detect(in: data, threshold: 3.0)

		// Should detect the two anomalies at positions 50 and 75
		#expect(anomalies.count >= 1)

		// Check that extreme values are flagged
		let values = anomalies.map { $0.value }
		#expect(values.contains { $0 > 140 || $0 < 60 })
	}

	@Test("No anomalies in normal data")
	func noAnomaliesInNormalData() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeNormalData()

		let anomalies = detector.detect(in: data, threshold: 3.0)

		// Should detect few or no anomalies in normal data
		#expect(anomalies.count < 5)  // Allow for some false positives
	}

	@Test("Different threshold values")
	func differentThresholds() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeDataWithAnomalies()

		let anomalies2 = detector.detect(in: data, threshold: 2.0)  // More sensitive
		let anomalies3 = detector.detect(in: data, threshold: 3.0)
		let anomalies4 = detector.detect(in: data, threshold: 4.0)  // Less sensitive

		// Lower threshold should detect more anomalies
		#expect(anomalies2.count >= anomalies3.count)
		#expect(anomalies3.count >= anomalies4.count)
	}

	@Test("Anomaly severity classification")
	func anomalySeverity() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeDataWithAnomalies()

		let anomalies = detector.detect(in: data, threshold: 2.0)

		// With large anomalies (150 vs 100, and 50 vs 100), 
		// we should detect at least one severe anomaly
		#expect(!anomalies.isEmpty, "Should detect anomalies in data with known outliers")
		
		let hasSevere = anomalies.contains { $0.severity == .severe }
		#expect(hasSevere, "Large deviation (±50 from mean) should be classified as severe")
		
		// Verify that severity classification is working by checking deviation scores
		// Severe anomalies should have higher deviation scores than mild ones
		let severeAnomalies = anomalies.filter { $0.severity == .severe }
		let mildAnomalies = anomalies.filter { $0.severity == .mild }

		if !severeAnomalies.isEmpty && !mildAnomalies.isEmpty {
			guard let minSevereScore = severeAnomalies.map({ $0.deviationScore }).min(),
			      let maxMildScore = mildAnomalies.map({ $0.deviationScore }).max() else {
				Issue.record("Failed to compute min/max deviation scores")
				return
			}

			#expect(minSevereScore > maxMildScore,
					"Severe anomalies should have higher deviation scores than mild ones")
		}
	}

	@Test("Anomaly deviation score")
	func anomalyDeviationScore() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeDataWithAnomalies()

		let anomalies = detector.detect(in: data, threshold: 2.5)

		// All anomalies should have deviation score > threshold
		for anomaly in anomalies {
			#expect(Double(anomaly.deviationScore) > 2.5)
		}
	}

	// MARK: - Window Size Tests

	@Test("Small window vs large window")
	func windowSizeEffect() throws {
		let data = makeDataWithAnomalies()

		let detectorSmall = ZScoreAnomalyDetector<Double>(windowSize: 10)
		let detectorLarge = ZScoreAnomalyDetector<Double>(windowSize: 50)

		let anomaliesSmall = detectorSmall.detect(in: data, threshold: 3.0)
		let anomaliesLarge = detectorLarge.detect(in: data, threshold: 3.0)

		// Both should detect anomalies
		#expect(anomaliesSmall.count > 0)
		#expect(anomaliesLarge.count > 0)
	}

	// MARK: - Expected Value Tracking

	@Test("Anomaly has expected value")
	func anomalyExpectedValue() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
		let data = makeDataWithAnomalies(seed: 0.42)

		let anomalies = detector.detect(in: data, threshold: 2.5)

		// Focus checks on the two known injected anomalies
		let targetPeriods = [data.periods[50], data.periods[75]]
		let targetAnomalies = anomalies.filter { targetPeriods.contains($0.period) }

		// Ensure both known anomalies are flagged
		#expect(targetAnomalies.count == 2)

		for anomaly in targetAnomalies {
			// Expected value should be close to the baseline (~100)
			#expect(abs(anomaly.expectedValue - 100.0) < 20.0)
			// Actual value should deviate significantly
			#expect(abs(anomaly.value - anomaly.expectedValue) > 10.0)
		}
	}

	// MARK: - Edge Cases

	@Test("Insufficient data for window")
	func insufficientData() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)

		let periods = (0..<20).map { Period.day( Date(timeIntervalSince1970: Double($0 * 86400))) }
		let values = Array(repeating: 100.0, count: 20)
		let data = TimeSeries(periods: periods, values: values)

		let anomalies = detector.detect(in: data, threshold: 3.0)

		// Should not detect anomalies (or return empty) with insufficient data
		#expect(anomalies.isEmpty)
	}

	@Test("Constant data has no anomalies")
	func constantData() throws {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)

		let periods = (0..<100).map { Period.day( Date(timeIntervalSince1970: Double($0 * 86400))) }
		let values = Array(repeating: 100.0, count: 100)
		let data = TimeSeries(periods: periods, values: values)

		let anomalies = detector.detect(in: data, threshold: 3.0)

		#expect(anomalies.isEmpty)
	}
}

@Suite("Additional Anomaly Detection – Deterministic")
struct AdditionalAnomalyDetectionTests {

	// MARK: - Helper Functions

	private func dayPeriods(count: Int, start: TimeInterval = 0) -> [Period] {
		(0..<count).map { Period.day(Date(timeIntervalSince1970: start + Double($0 * 86400))) }
	}

	private func monthPeriods(yearStart: Int, monthCount: Int) -> [Period] {
		var periods = [Period]()
		var y = yearStart
		var m = 1
		for _ in 0..<monthCount {
			periods.append(Period.month(year: y, month: m))
			m += 1
			if m == 13 { m = 1; y += 1 }
		}
		return periods
	}

		private func flatWithAnomalies() -> TimeSeries<Double> {
			let periods = dayPeriods(count: 100)
			var values = Array(repeating: 100.0, count: 100)
			values[50] = 150.0
			values[75] = 50.0
//			print(values.map({"\($0)"}).joined(separator: " | "))
			return TimeSeries(periods: periods, values: values)
		}

		@Test("Detect exact anomaly positions deterministically")
		func detectsExactPositions() throws {
			let data = flatWithAnomalies()
			let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)

			let anomalies = detector.detect(in: data, threshold: 3.0)
//			print(anomalies.map({$0.description}).joined(separator: "\n"))

			#expect(!anomalies.isEmpty)
			// Check the two expected positions are flagged
			let periodsFlagged = anomalies.map({ $0.period })
			#expect(periodsFlagged.contains(data.periods[50]))
			#expect(periodsFlagged.contains(data.periods[75]))
			// Expect exactly those two, given a flat baseline
			#expect(anomalies.count == 2)
			// Expected value should be exactly the baseline on a flat window
			for a in anomalies {
				#expect(abs(a.expectedValue - 100.0) < 1e-9)
				#expect(abs(a.value - a.expectedValue) >= 50.0)
				#expect(a.deviationScore > 3.0)
			}
		}

		@Test("Anomalies before warm-up window are ignored")
		func earlyAnomalyIgnored() throws {
			let periods = dayPeriods(count: 40)
			var values = Array(repeating: 100.0, count: 40)
			values[5] = 160.0 // before window of 30
			let data = TimeSeries(periods: periods, values: values)

			let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
			let anomalies = detector.detect(in: data, threshold: 3.0)

			// With no history, early anomaly should not be flagged
			#expect(anomalies.isEmpty)
		}

		@Test("Severity and deviation are monotonic in magnitude")
		func severityOrdering() throws {
			let periods = dayPeriods(count: 80)
			var values = Array(repeating: 100.0, count: 80)
			values[40] = 130.0 // smaller anomaly
			values[60] = 170.0 // larger anomaly
			let data = TimeSeries(periods: periods, values: values)

			let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
			let anomalies = detector.detect(in: data, threshold: 2.0)
//			print(anomalies.map({$0.description}).joined(separator: "\n"))

			guard let aSmall = anomalies.first(where: { $0.period == periods[40] }),
			      let aLarge = anomalies.first(where: { $0.period == periods[60] }) else {
				Issue.record("Expected anomalies at positions 40 and 60 were not detected")
				return
			}

			#expect(aLarge.deviationScore > aSmall.deviationScore)
			// If severities are categorized, larger deviation should not be a lower severity
			#expect(aLarge.severity.rawValue >= aSmall.severity.rawValue)
		}

		@Test("Threshold boundary behavior toggles detection")
		func thresholdBoundary() throws {
			// Build a window with non-zero stddev
			let baseline = (0..<30).map { 100.0 + Double(($0 % 5) - 2) } // mean ~100, std > 0
			let m = mean(baseline)
			let s = stdDev(baseline)
			// Put an anomaly a hair over 3-sigma
			let anomalyValue = m + 3.01 * s

			var values = baseline
			values.append(anomalyValue)
			values.append(contentsOf: Array(repeating: 100.0, count: 10))
			let periods = dayPeriods(count: values.count)
			let data = TimeSeries(periods: periods, values: values)

			let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)

			let anomalies3 = detector.detect(in: data, threshold: 3.0)
			let flagged3 = anomalies3.contains { $0.period == periods[30] }
			#expect(flagged3)

			let anomalies31 = detector.detect(in: data, threshold: 3.1)
			let flagged31 = anomalies31.contains { $0.period == periods[30] }
			#expect(!flagged31)
		}
	}
