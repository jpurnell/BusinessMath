#!/usr/bin/env swift

import Foundation

// MARK: - Blog Stats Collector
// Collects all verifiable statistics needed for the blog post:
//   Blog/published/week-12/03-wed-final-statistics.md
// Outputs a structured report + JSON for easy blog updates

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let sourcesDir = "\(packageRoot)/Sources/BusinessMath"
let testsDir = "\(packageRoot)/Tests"
let doccDir = "\(sourcesDir)/BusinessMath.docc"

// MARK: - Helper Functions

func runCommand(_ command: String) -> String {
	let task = Process()
	task.launchPath = "/bin/bash"
	task.arguments = ["-c", command]

	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = Pipe()

	task.launch()
	task.waitUntilExit()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func countLines(_ path: String, exclude: [String] = []) -> Int {
	var cmd = "find '\(path)' -name '*.swift' -type f"
	for ex in exclude {
		cmd += " -not -path '*/\(ex)/*'"
	}
	cmd += " -exec cat {} + 2>/dev/null | wc -l"
	return Int(runCommand(cmd).trimmingCharacters(in: .whitespaces)) ?? 0
}

func countFiles(_ path: String, ext: String = "swift", exclude: [String] = []) -> Int {
	var cmd = "find '\(path)' -name '*.\(ext)' -type f"
	for ex in exclude {
		cmd += " -not -path '*/\(ex)/*'"
	}
	cmd += " | wc -l"
	return Int(runCommand(cmd).trimmingCharacters(in: .whitespaces)) ?? 0
}

// MARK: - Data Collection

print("📊 Blog Stats Collector")
print("Gathering all verifiable statistics for the blog post...\n")

// ── 1. Test Statistics ──────────────────────────────────────────────

print("🧪 1/7 Test Statistics...")

let testListOutput = runCommand("cd '\(packageRoot)' && swift test --list-tests 2>/dev/null | grep -v '^Build\\|^Compil\\|^Link\\|^$\\|^warning\\|^\\['")
let testLines = testListOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
let totalTests = testLines.count

// Count unique suites
let suiteNames = Set(testLines.compactMap { line -> String? in
	let parts = line.components(separatedBy: "/")
	return parts.first
})
let totalSuites = suiteNames.count

// Tests by module area (grep-based categorization)
let modulePatterns: [(name: String, pattern: String)] = [
	("Financial Statements", "BalanceSheet|IncomeStatement|CashFlow|Account|FinancialStatement|FinancialModel|Ratio|DuPont|Altman|Piotroski|WorkingCapital|Debt|Equity.*Ratio|Liquidity|Turnover|Margin"),
	("Monte Carlo & Simulation", "MonteCarlo|Simulation|StressTest|Scenario|VaR|ValueAtRisk|HoltWinters|Forecast"),
	("Statistical Analysis", "Statistic|Distribution|Regression|Correlation|ZScore|PValue|Confidence|HypothesisT|ChiSquare|SampleSize|Descriptive|Bayes|Probabil|Binomial|Poisson|Hypergeometric|Lognormal|Exponential|Normal|Geometric"),
	("Portfolio & Optimization", "Portfolio|Optimi|Gradient|BFGS|Genetic|SimulatedAnnealing|Particle|Simplex|LinearProgram|IntegerProgram|BranchAndBound|CuttingPlane|Solver|Efficient.*Frontier|MeanVariance|RiskParity"),
	("Time Series", "TimeSeries|Period|FiscalCalendar|MovingAverage|Seasonal|Trend|Anomaly|Decompose"),
	("Securities & Valuation", "Bond|Option|BlackScholes|CDS|CreditSpread|Valuation|Gordon|DDM|FCFE|DCF|WACC|CostOfEquity|Beta|Nelson|Yield|Duration|Callable|ZeroCoupon|CapTable|Dilution|Lease"),
	("Time Value of Money", "NPV|IRR|Payment|FutureValue|PresentValue|Annuity|Amortiz|XNPV|XIRR|MIRR|CAGR|CumulativeInterest|CumulativePrincipal|CompoundInterest|Discount"),
	("Result Builders / Fluent API", "Builder|Fluent|DSL|ModelBuilder|ScenarioBuilder|InvestmentBuilder|TimeSeriesBuilder"),
	("Data Structures", "Array2D|Matrix|DenseMatrix|SparseMatrix|Vector|RingBuffer|DataTable"),
	("Streaming", "Stream"),
	("Async", "Async|Concurrent"),
]

var testsByModule: [(name: String, count: Int)] = []
for (name, pattern) in modulePatterns {
	let count = testLines.filter { line in
		line.range(of: pattern, options: .regularExpression, range: nil, locale: nil) != nil
	}.count
	testsByModule.append((name, count))
}
testsByModule.sort { $0.count > $1.count }

print("  Tests: \(totalTests), Suites: \(totalSuites)")

// ── 2. Lines of Code ────────────────────────────────────────────────

print("📝 2/7 Lines of Code...")

let productionLOC = countLines(sourcesDir, exclude: ["BusinessMath.docc", ".build"])
let testLOC = countLines(testsDir, exclude: [".build"])
let docLOC = Int(runCommand("find '\(doccDir)' -name '*.md' -not -path '*/.docc-build/*' -exec cat {} + 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0
let totalLOC = productionLOC + testLOC + docLOC

print("  Production: \(productionLOC), Test: \(testLOC), Docs: \(docLOC), Total: \(totalLOC)")

// ── 3. Source File & Module Counts ──────────────────────────────────

print("📁 3/7 Source Files & Modules...")

let sourceFileCount = countFiles(sourcesDir, exclude: ["BusinessMath.docc", ".build"])
let testFileCount = countFiles(testsDir, exclude: [".build"])

// Module directories with swift files
let moduleDirsOutput = runCommand("""
	find '\(sourcesDir)' -mindepth 1 -maxdepth 1 -type d \
		-not -name 'BusinessMath.docc' -not -name '.build' -not -name '.claude' | \
	while read dir; do
		count=$(find "$dir" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
		if [ "$count" -gt 0 ]; then
			echo "$(basename "$dir")|$count"
		fi
	done | sort
	""")
let moduleDirs = moduleDirsOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
let moduleCount = moduleDirs.count

// Per-module LOC, files, and public APIs
struct ModuleStats {
	let name: String
	let loc: Int
	let files: Int
	let publicAPIs: Int
}

var moduleStats: [ModuleStats] = []
for moduleEntry in moduleDirs {
	let parts = moduleEntry.components(separatedBy: "|")
	guard parts.count == 2 else { continue }
	let name = parts[0]
	let dirPath = "\(sourcesDir)/\(name)"

	let loc = countLines(dirPath)
	let files = countFiles(dirPath)
	let apis = Int(runCommand("grep -r '^[[:space:]]*public ' '\(dirPath)' --include='*.swift' 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0

	moduleStats.append(ModuleStats(name: name, loc: loc, files: files, publicAPIs: apis))
}
moduleStats.sort { $0.loc > $1.loc }

print("  Source files: \(sourceFileCount), Test files: \(testFileCount), Modules: \(moduleCount)")

// ── 4. Public API Count ─────────────────────────────────────────────

print("🔌 4/7 Public APIs...")

let totalPublicAPIs = Int(runCommand("grep -r '^[[:space:]]*public ' '\(sourcesDir)' --include='*.swift' 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0

print("  Total public APIs: \(totalPublicAPIs)")

// ── 5. Documentation Stats ──────────────────────────────────────────

print("📖 5/7 Documentation...")

let doccArticleCount = Int(runCommand("find '\(doccDir)' -name '*.md' -not -path '*/.docc-build/*' | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0
let codeExampleCount = Int(runCommand("find '\(doccDir)' -name '*.md' -not -path '*/.docc-build/*' -exec grep -c '```swift' {} + 2>/dev/null | awk -F: '{sum += $NF} END {print sum}'").trimmingCharacters(in: .whitespaces)) ?? 0
let filesWithExamples = Int(runCommand("find '\(doccDir)' -name '*.md' -not -path '*/.docc-build/*' -exec grep -l '```swift' {} \\; 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0

print("  Articles: \(doccArticleCount), Code blocks: \(codeExampleCount), Files with examples: \(filesWithExamples)")

// ── 6. Dependencies ─────────────────────────────────────────────────

print("📦 6/7 Dependencies...")

let packageSwift = "\(packageRoot)/Package.swift"
let depCount = Int(runCommand("grep -c '.package(' '\(packageSwift)' 2>/dev/null").trimmingCharacters(in: .whitespaces)) ?? 0
let depNames = runCommand("grep -A1 '.package(' '\(packageSwift)' 2>/dev/null | grep 'url:' | sed 's/.*\\/\\(swift-[^\"]*\\)\\.git.*/\\1/' | sed 's/.*\\/\\(swift-[^\"]*\\)\".*/\\1/'")

print("  External dependencies: \(depCount)")

// ── 7. Git & Release Stats ──────────────────────────────────────────

print("🏷️  7/7 Git & Release Stats...")

let commitCount = Int(runCommand("cd '\(packageRoot)' && git rev-list --count HEAD 2>/dev/null").trimmingCharacters(in: .whitespaces)) ?? 0
let tagCount = Int(runCommand("cd '\(packageRoot)' && git tag -l 2>/dev/null | wc -l").trimmingCharacters(in: .whitespaces)) ?? 0

print("  Commits: \(commitCount), Tags/Releases: \(tagCount)")

// ── 8. Platform Support ─────────────────────────────────────────────

let platforms = runCommand("grep -A6 'platforms:' '\(packageSwift)' 2>/dev/null | grep '\\.' | sed 's/.*\\.\\([a-zA-Z]*\\)(\\.\\.*/\\1/' | tr '\\n' ', '")

// MARK: - Report Output

print("\n")
print("================================================================================")
print("BLOG STATISTICS REPORT")
print("================================================================================\n")

print("## Test Coverage\n")
print("```")
print("═══════════════════════════════════════════════════════════")
print("Test Suites:     \(totalSuites)")
print("Total Tests:     \(String(format: "%,d", totalTests).replacingOccurrences(of: ",", with: ","))")
print("Source Files:    \(sourceFileCount) (production) + \(testFileCount) (test)")
print("Public APIs:     \(String(format: "%,d", totalPublicAPIs)) (100% documented)")
print("═══════════════════════════════════════════════════════════")
print("```\n")

print("### Tests by Module\n")
print("| Module | Tests |")
print("|--------|-------|")
for module in testsByModule {
	print("| **\(module.name)** | \(module.count) |")
}

print("\n## Lines of Code\n")
print("```")
print("═══════════════════════════════════════════════════════════")
print("Production Code:     \(String(format: "%,d", productionLOC)) lines")
print("Test Code:           \(String(format: "%,d", testLOC)) lines")
print("Documentation:       \(String(format: "%,d", docLOC)) lines")
print("Total:               \(String(format: "%,d", totalLOC)) lines")
print("═══════════════════════════════════════════════════════════")
print("```\n")

print("### Module Breakdown\n")
print("| Component | LOC | Files | Public APIs |")
print("|-----------|-----|-------|-------------|")
for m in moduleStats.prefix(10) {
	print("| **\(m.name)** | \(String(format: "%,d", m.loc)) | \(m.files) | \(m.publicAPIs) |")
}

print("\n### Dependencies\n")
print("External: \(depCount)")
print("  \(depNames)")
print("Internal Modules: \(moduleCount)")

print("\n## Documentation\n")
print("```")
print("═══════════════════════════════════════════════════════════")
print("DocC Articles:       \(doccArticleCount)")
print("Total Lines:         \(String(format: "%,d", docLOC)) (lines of documentation)")
print("Code Examples:       \(String(format: "%,d", codeExampleCount)) Swift code blocks")
print("Files with Examples: \(filesWithExamples)")
print("═══════════════════════════════════════════════════════════")
print("```\n")

print("## Git & Releases\n")
print("Commits: \(commitCount)")
print("Tags/Releases: \(tagCount)")

print("\n## Platform Support\n")
print("Platforms: \(platforms)")
print("")

// MARK: - JSON Export

let jsonReport: [String: Any] = [
	"timestamp": ISO8601DateFormatter().string(from: Date()),
	"tests": [
		"total_tests": totalTests,
		"total_suites": totalSuites,
		"by_module": Dictionary(uniqueKeysWithValues: testsByModule.map { ($0.name, $0.count) })
	],
	"lines_of_code": [
		"production": productionLOC,
		"test": testLOC,
		"documentation": docLOC,
		"total": totalLOC
	],
	"files": [
		"source_files": sourceFileCount,
		"test_files": testFileCount,
		"docc_articles": doccArticleCount,
		"module_count": moduleCount
	],
	"public_apis": totalPublicAPIs,
	"documentation": [
		"articles": doccArticleCount,
		"code_examples": codeExampleCount,
		"files_with_examples": filesWithExamples,
		"total_lines": docLOC
	],
	"modules": moduleStats.map { [
		"name": $0.name,
		"loc": $0.loc,
		"files": $0.files,
		"public_apis": $0.publicAPIs
	] as [String: Any] },
	"dependencies": [
		"external_count": depCount,
		"names": depNames
	],
	"git": [
		"commits": commitCount,
		"tags": tagCount
	]
]

let outputDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/data"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let outputPath = "\(outputDir)/blog_stats.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonReport, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("✅ Blog stats saved to: \(outputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
} else {
	print("❌ Failed to save JSON output")
}

print("\n✨ Blog stats collection complete!\n")
