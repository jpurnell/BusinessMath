#!/usr/bin/env swift

import Foundation

// MARK: - File Test Mapper
// Maps source files to their corresponding test files
// Identifies which files have tests and which don't

let packageRoot = "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath"
let sourcesDir = "\(packageRoot)/Sources/BusinessMath"
let testsDir = "\(packageRoot)/Tests/BusinessMathTests"

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

// MARK: - Main Logic

print("🔍 File Test Mapper")
print("Finding which source files have corresponding test files...\n")

// Get all source files
let sourceFilesOutput = runCommand("find '\(sourcesDir)' -name '*.swift' -type f")
let sourceFiles = sourceFilesOutput.components(separatedBy: "\n")
	.filter { !$0.isEmpty && !$0.contains(".build") }
	.sorted()

// Get all test files and create a lookup set
let testFilesOutput = runCommand("find '\(testsDir)' -name '*.swift' -type f")
let testFilePaths = testFilesOutput.components(separatedBy: "\n")
	.filter { !$0.isEmpty }

// Create mapping: source filename → test file path
var testFileMapping: [String: String] = [:]
for testPath in testFilePaths {
	let testFileName = URL(fileURLWithPath: testPath).lastPathComponent
	// Strip "Tests.swift" to get source filename
	if testFileName.hasSuffix("Tests.swift") {
		let sourceFileName = testFileName.replacingOccurrences(of: "Tests.swift", with: ".swift")
		testFileMapping[sourceFileName] = testPath
	}
}

// Analyze each source file
struct FileInfo {
	let sourcePath: String
	let relativePath: String
	let fileName: String
	let testPath: String?
	let hasTests: Bool
}

var filesWithTests: [FileInfo] = []
var filesWithoutTests: [FileInfo] = []

for sourceFile in sourceFiles {
	let url = URL(fileURLWithPath: sourceFile)
	let fileName = url.lastPathComponent
	let relativePath = sourceFile.replacingOccurrences(of: sourcesDir + "/", with: "")

	let testPath = testFileMapping[fileName]
	let hasTests = testPath != nil

	let info = FileInfo(
		sourcePath: sourceFile,
		relativePath: relativePath,
		fileName: fileName,
		testPath: testPath,
		hasTests: hasTests
	)

	if hasTests {
		filesWithTests.append(info)
	} else {
		filesWithoutTests.append(info)
	}
}

// MARK: - Output

print("📊 Results:")
print("- Total source files: \(sourceFiles.count)")
print("- Files with tests: \(filesWithTests.count) (\(String(format: "%.1f", Double(filesWithTests.count) / Double(sourceFiles.count) * 100))%)")
print("- Files WITHOUT tests: \(filesWithoutTests.count) (\(String(format: "%.1f", Double(filesWithoutTests.count) / Double(sourceFiles.count) * 100))%)")
print()

if !filesWithoutTests.isEmpty {
	print("📋 Files without tests (first 15):")
	for (index, file) in filesWithoutTests.prefix(15).enumerated() {
		print("  \(index + 1). \(file.relativePath)")
	}
	if filesWithoutTests.count > 15 {
		print("  ... and \(filesWithoutTests.count - 15) more")
	}
	print()
}

// MARK: - JSON Export

let jsonOutput: [String: Any] = [
	"timestamp": ISO8601DateFormatter().string(from: Date()),
	"summary": [
		"total_files": sourceFiles.count,
		"files_with_tests": filesWithTests.count,
		"files_without_tests": filesWithoutTests.count,
		"coverage_percent": Double(filesWithTests.count) / Double(sourceFiles.count) * 100
	],
	"files_with_tests": filesWithTests.map { [
		"source": $0.relativePath,
		"test": $0.testPath?.replacingOccurrences(of: packageRoot + "/", with: "") ?? ""
	]},
	"files_without_tests": filesWithoutTests.map { [
		"source": $0.relativePath,
		"suggested_test": "Tests/BusinessMathTests/\($0.fileName.replacingOccurrences(of: ".swift", with: "Tests.swift"))"
	]}
]

let outputDir = "\(packageRoot)/development-guidelines/05_SUMMARIES/data"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let outputPath = "\(outputDir)/file_mapping.json"
if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
   let jsonString = String(data: jsonData, encoding: .utf8) {
	try? jsonString.write(toFile: outputPath, atomically: true, encoding: .utf8)
	print("✅ Mapping saved to: \(outputPath.replacingOccurrences(of: packageRoot + "/", with: ""))")
} else {
	print("❌ Failed to save JSON output")
}

print()
