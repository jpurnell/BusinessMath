import Testing
import Foundation
@testable import BusinessMath

@Suite("Anomaly Detection Tests")
struct AnomalyDetectionTests {

	// MARK: - Helper Functions

	func makeNormalData() -> TimeSeries<Double> {
		// Data centered around 100 with small variation
		let periods = (0..<100).map { Period.day( Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = []

		for _ in 0..<100 {
			// Normal variation ±5 around 100
			values.append(100.0 + Double.random(in: -5.0...5.0))
		}

		return TimeSeries(periods: periods, values: values)
	}

	func makeDataWithAnomalies() -> TimeSeries<Double> {
		let periods = (0..<100).map { Period.day( Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = []

		for i in 0..<100 {
			if i == 50 {
				// Anomaly: spike to 150
				values.append(150.0)
			} else if i == 75 {
				// Anomaly: drop to 50
				values.append(50.0)
			} else {
				// Normal value around 100
				values.append(100.0 + Double.random(in: -5.0...5.0))
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
			let minSevereScore = severeAnomalies.map { $0.deviationScore }.min()!
			let maxMildScore = mildAnomalies.map { $0.deviationScore }.max()!
			
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
		let data = makeDataWithAnomalies()

		let anomalies = detector.detect(in: data, threshold: 2.5)

		for anomaly in anomalies {
			// Expected value should be close to 100 (the normal level)
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
