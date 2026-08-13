#!/usr/bin/env swift

import Foundation

// MARK: - Tutorial Categorizer
// Categorizes DocC articles by topic area and counts code examples per category
// Used to populate the "Tutorial Categories" table in the blog post

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let doccDir = "\(packageRoot)/Sources/BusinessMath/BusinessMath.docc"

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

// MARK: - Data Structures

struct ArticleInfo {
	let path: String
	let relativePath: String
	let filename: String
	let title: String
	let category: String
	let codeBlockCount: Int
	let lineCount: Int
}

// MARK: - Category Definitions

// Primary categorization uses the file naming convention:
//   1.x = Getting Started / Basics
//   2.x = Analysis
//   3.x = Financial Modeling
//   4.x = Simulation
//   5.x = Optimization
//   Part1-5 = Learning Paths
//   Appendix = Reference
// Falls back to keyword matching for files that don't follow the convention.

let prefixCategories: [(prefix: String, category: String)] = [
	("1.", "Getting Started"),
	("2.", "Financial Analysis"),
	("3.", "Financial Modeling"),
	("4.", "Simulation"),
	("5.", "Optimization"),
	("Part1", "Getting Started"),
	("Part2", "Financial Analysis"),
	("Part3", "Financial Modeling"),
	("Part4", "Simulation"),
	("Part5", "Optimization"),
	("Appendix", "Reference"),
]

// Fallback keyword rules for files without numeric prefixes.
// Only filename + title are searched (not content) to avoid false matches.
let keywordRules: [(category: String, patterns: [String])] = [
	("Statistics", ["statistic", "regression", "correlation", "hypothesis", "linearregression"]),
	("Getting Started", ["gettingstarted", "businessmath.md", "learningpath"]),
	("Time Series", ["timeseries", "time-series"]),
	("Financial Modeling", ["model", "valuation", "scenario"]),
	("Simulation", ["montecarlo", "simulation"]),
	("Optimization", ["optimi", "gradient", "solver"]),
	("Financial Analysis", ["ratio", "analysis"]),
]

// MARK: - Main Logic

print("📂 Tutorial Categorizer")
print("Categorizing DocC articles by topic...\n")

// Find all .md files (excluding build artifacts)
let filesOutput = runCommand("find '\(doccDir)' -name '*.md' -not -path '*/.docc-build/*' -type f")
let files = filesOutput.components(separatedBy: "\n").filter { !$0.isEmpty }.sorted()

print("Found \(files.count) articles to categorize.\n")

var articles: [ArticleInfo] = []

for filePath in files {
	guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }

	let filename = URL(fileURLWithPath: filePath).lastPathComponent
	let relativePath = filePath.replacingOccurrences(of: doccDir + "/", with: "")

	// Extract title from first # heading or frontmatter
	var title = filename.replacingOccurrences(of: ".md", with: "")
	let lines = content.components(separatedBy: "\n")
	for line in lines {
		let trimmed = line.trimmingCharacters(in: .whitespaces)
		if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
			title = String(trimmed.dropFirst(2))
			break
		}
	}

	// Count ```swift code blocks
	var codeBlockCount = 0
	for line in lines {
		if line.trimmingCharacters(in: .whitespaces).hasPrefix("```swift") {
			codeBlockCount += 1
		}
	}

	// Categorize: try filename prefix first, then keyword fallback
	var category = "Other"

	// 1. Check filename prefix (e.g., "1.1-GettingStarted.md" → "1." → "Getting Started")
	for rule in prefixCategories {
		if filename.hasPrefix(rule.prefix) {
			category = rule.category
			break
		}
	}

	// 2. Fallback: keyword match on filename + title only (not content, to avoid false positives)
	if category == "Other" {
		let searchText = (filename + " " + title).lowercased()
		for rule in keywordRules {
			if rule.patterns.contains(where: { searchText.contains($0) }) {
				category = rule.category
				break
			}
		}
	}

	articles.append(ArticleInfo(
		path: filePath,
		relativePath: relativePath,
		filename: filename,
		title: title,
		category: category,
		codeBlockCount: codeBlockCount,
		lineCount: lines.count
	))
}

// MARK: - Analysis

let byCategory = Dictionary(grouping: articles) { $0.category }
let sortedCategories = byCategory.sorted { $0.value.count > $1.value.count }

// MARK: - Report Output

print("================================================================================")
print("TUTORIAL CATEGORIZATION REPORT")
print("================================================================================\n")

print("### Tutorial Categories\n")
print("| Category | Articles | Code Examples |")
print("|----------|----------|--------------|")
for (category, categoryArticles) in sortedCategories {
	let totalExamples = categoryArticles.reduce(0) { $0 + $1.codeBlockCount }
	print("| **\(category)** | \(categoryArticles.count) | \(totalExamples) |")
}

let totalArticles = articles.count
let totalExamples = articles.reduce(0) { $0 + $1.codeBlockCount }
print("| **Total** | **\(totalArticles)** | **\(totalExamples)** |")

print("\n### Articles by Category\n")
for (category, categoryArticles) in sortedCategories {
	print("**\(category)** (\(categoryArticles.count) articles):")
	for article in categoryArticles.sorted(by: { $0.filename < $1.filename }) {
		let exampleNote = article.codeBlockCount > 0 ? " (\(article.codeBlockCount) examples)" : ""
		print("  - \(article.relativePath)\(exampleNote)")
	}
	print()
}

// Articles categorized as "Other" — may need manual review
let otherArticles = articles.filter { $0.category == "Other" }
if !otherArticles.isEmpty {
	print("⚠️  \(otherArticles.count) article(s) categorized as 'Other' — review category rules if needed.\n")
}

// MARK: - JSON Export

let jsonReport: [String: Any] = [
	"timestamp": ISO8601DateFormatter().string(from: Date()),
	"summary": [
		"total_articles": totalArticles,
		"total_code_examples": totalExamples,
		"categories": sortedCategories.map { [
			"name": $0.key,
			"article_count": $0.value.count,
			"code_examples": $0.value.reduce(0) { $0 + $1.codeBlockCount }
		] as [String: Any] }
	] as [String: Any],
	"articles": articles.map { [
		"file": $0.relativePath,
		"title": $0.title,
		"category": $0.category,
		"code_examples": $0.codeBlockCount,
		"lines": $0.lineCount
	] as [String: Any] }
]

let outputDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/data"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let outputPath = "\(outputDir)/tutorial_categories.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonReport, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("✅ Tutorial categories saved to: \(outputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
} else {
	print("❌ Failed to save JSON output")
}

print("\n✨ Tutorial categorization complete!\n")
