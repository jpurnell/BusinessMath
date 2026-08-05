# Updating Blog Statistics

This documents the process for updating verified statistics in:
`Blog/published/week-12/03-wed-final-statistics.md`

## Quick Update (recommended)

Run the two main scripts and use their output to update the blog:

```bash
cd /Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath

# 1. Collect all core stats (tests, LOC, modules, APIs, deps, git)
swift "project/summaries/analyzers/blog_stats_collector.swift"

# 2. Categorize DocC tutorials by topic
swift "project/summaries/analyzers/tutorial_categorizer.swift"
```

Both scripts print formatted tables ready to copy into the blog post and save JSON to `project/summaries/data/`.

## Full Update (with coverage data)

For code coverage stats, first run tests with coverage enabled, then extract:

```bash
# 3. Build coverage data (takes several minutes)
swift test --enable-code-coverage

# 4. Extract line coverage per file
swift "project/summaries/analyzers/line_coverage_extractor.swift"

# 5. Check documentation gaps
swift "project/summaries/analyzers/doc_gap_analyzer.swift"

# 6. Map source files to test files
swift "project/summaries/analyzers/file_test_mapper.swift"
```

## What Each Script Produces

| Script | Output File | Blog Sections Updated |
|--------|------------|----------------------|
| `blog_stats_collector.swift` | `data/blog_stats.json` | Test Coverage, Lines of Code, Module Breakdown, Dependencies, Documentation, Platform Support, Summary |
| `tutorial_categorizer.swift` | `data/tutorial_categories.json` | Tutorial Categories table |
| `line_coverage_extractor.swift` | `data/line_coverage.json` | Code Coverage % (if tests run with --enable-code-coverage) |
| `doc_gap_analyzer.swift` | `data/doc_gaps.json` | API Reference Coverage (documented %) |
| `file_test_mapper.swift` | `data/file_mapping.json` | Source-to-test file mapping |

## Blog Sections and Their Data Sources

### Verifiable from analyzers
- **Overall Test Statistics** — `blog_stats_collector`
- **Tests by Module** — `blog_stats_collector`
- **Lines of Code** — `blog_stats_collector`
- **Module Breakdown** — `blog_stats_collector`
- **Dependency Graph** — `blog_stats_collector`
- **DocC Tutorials** — `tutorial_categorizer`
- **Tutorial Categories** — `tutorial_categorizer`
- **API Reference Coverage** — `doc_gap_analyzer`
- **Platform Support** — `blog_stats_collector` (reads Package.swift)
- **Summary ("The Numbers Tell a Story")** — `blog_stats_collector`

### NOT verifiable from analyzers (manual/external data)
- **Performance Benchmarks** — requires running dedicated benchmarks
- **Community Metrics** — GitHub API or manual check
- **User Feedback** — survey data
- **Production Usage** — external tracking
- **Version History** — partially from git tags, but dates/descriptions are editorial
- **Migration Impact** — editorial content

## JSON Data Location

All JSON output goes to:
```
project/summaries/data/
├── blog_stats.json           # Core stats (tests, LOC, modules, APIs)
├── tutorial_categories.json  # DocC article categorization
├── doc_gaps.json             # Undocumented API report
├── file_mapping.json         # Source → test file mapping
└── line_coverage.json        # Per-file coverage (requires coverage run)
```

## Tips

- Run `blog_stats_collector.swift` first — it takes ~30s due to `swift test --list-tests`
- The formatted tables in stdout are designed to paste directly into the blog markdown
- Compare JSON snapshots over time to track growth trends
- The module test counts use pattern matching and may overlap — totals won't sum exactly to total tests
