import Testing
@testable import BusinessMath

@Suite("PeriodSequence")
struct PeriodSequenceTests {

    // MARK: - Monthly Generation

    @Test("Monthly Jan-Dec 2026 produces 12 periods")
    func monthlyFullYear() {
        let seq = PeriodSequence.monthly(
            from: Period.month(year: 2026, month: 1),
            through: Period.month(year: 2026, month: 12)
        )
        let periods = Array(seq)
        #expect(periods.count == 12)
        #expect(periods.first == Period.month(year: 2026, month: 1))
        #expect(periods.last == Period.month(year: 2026, month: 12))
    }

    @Test("Monthly across year boundary")
    func monthlyCrossYear() {
        let seq = PeriodSequence.monthly(
            from: Period.month(year: 2025, month: 10),
            through: Period.month(year: 2026, month: 3)
        )
        let periods = Array(seq)
        #expect(periods.count == 6)
    }

    // MARK: - Quarterly Generation

    @Test("Quarterly 2026 produces 4 periods")
    func quarterlyFullYear() {
        let seq = PeriodSequence.quarterly(
            fromYear: 2026, fromQuarter: 1,
            throughYear: 2026, throughQuarter: 4
        )
        let periods = Array(seq)
        #expect(periods.count == 4)
        #expect(periods.first == Period.quarter(year: 2026, quarter: 1))
        #expect(periods.last == Period.quarter(year: 2026, quarter: 4))
    }

    // MARK: - Annual Generation

    @Test("Annual 2024-2026 produces 3 periods")
    func annualThreeYears() {
        let seq = PeriodSequence.annual(from: 2024, through: 2026)
        let periods = Array(seq)
        #expect(periods.count == 3)
        #expect(periods.first == Period.year(2024))
        #expect(periods.last == Period.year(2026))
    }

    // MARK: - Edge Cases

    @Test("Start equals end produces single period")
    func singlePeriod() {
        let seq = PeriodSequence.monthly(
            from: Period.month(year: 2026, month: 6),
            through: Period.month(year: 2026, month: 6)
        )
        let periods = Array(seq)
        #expect(periods.count == 1)
    }

    @Test("Conforms to Sequence — works with for-in")
    func sequenceConformance() {
        let seq = PeriodSequence.annual(from: 2024, through: 2026)
        var count = 0
        for _ in seq {
            count += 1
        }
        #expect(count == 3)
    }

    // MARK: - Aggregation

    @Test("Sum aggregation: 12 monthly values sum to correct quarterly totals")
    func sumAggregation() {
        // Create a monthly time series: revenue = month * 1000
        let months = Array(PeriodSequence.monthly(
            from: Period.month(year: 2026, month: 1),
            through: Period.month(year: 2026, month: 12)
        ))

        var values: [Period: Double] = [:]
        for (i, month) in months.enumerated() {
            values[month] = Double(i + 1) * 1000.0
        }
        let monthly = TimeSeries(data: values)

        let quarterly = PeriodSequence.aggregate(
            monthly,
            to: .quarterly,
            method: .sum
        )

        // Q1: 1000+2000+3000 = 6000
        #expect(abs((quarterly[Period.quarter(year: 2026, quarter: 1)] ?? 0) - 6000.0) < 1e-10)
        // Q2: 4000+5000+6000 = 15000
        #expect(abs((quarterly[Period.quarter(year: 2026, quarter: 2)] ?? 0) - 15000.0) < 1e-10)
    }

    @Test("Average aggregation: monthly rates average to quarterly")
    func averageAggregation() {
        let months = Array(PeriodSequence.monthly(
            from: Period.month(year: 2026, month: 1),
            through: Period.month(year: 2026, month: 3)
        ))

        var values: [Period: Double] = [:]
        values[months[0]] = 0.10  // Jan
        values[months[1]] = 0.12  // Feb
        values[months[2]] = 0.14  // Mar
        let monthly = TimeSeries(data: values)

        let quarterly = PeriodSequence.aggregate(
            monthly,
            to: .quarterly,
            method: .average
        )

        // Q1 avg: (0.10+0.12+0.14)/3 = 0.12
        let q1Value = quarterly[Period.quarter(year: 2026, quarter: 1)] ?? 0
        #expect(abs(q1Value - 0.12) < 1e-10)
    }

    @Test("Last-value aggregation: picks last month of quarter")
    func lastValueAggregation() {
        let months = Array(PeriodSequence.monthly(
            from: Period.month(year: 2026, month: 1),
            through: Period.month(year: 2026, month: 6)
        ))

        var values: [Period: Double] = [:]
        for (i, month) in months.enumerated() {
            values[month] = Double(i + 1) * 100.0
        }
        let monthly = TimeSeries(data: values)

        let quarterly = PeriodSequence.aggregate(
            monthly,
            to: .quarterly,
            method: .last
        )

        // Q1 end: March = 300
        #expect(abs((quarterly[Period.quarter(year: 2026, quarter: 1)] ?? 0) - 300.0) < 1e-10)
        // Q2 end: June = 600
        #expect(abs((quarterly[Period.quarter(year: 2026, quarter: 2)] ?? 0) - 600.0) < 1e-10)
    }
}
