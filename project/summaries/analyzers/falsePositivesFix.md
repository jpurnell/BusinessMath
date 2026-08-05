# Documentation Analyzer False Positives Fix

## Summary

The documentation coverage analyzer is reporting false positives for two patterns that are actually valid DocC documentation. This results in items being incorrectly flagged as "undocumented" when they have proper documentation.

## Issue 1: `@available` Attributes Between Doc Comment and Declaration

### Problem

The analyzer does not recognize doc comments that are separated from their declaration by `@available` attributes. This is a valid Swift/DocC pattern.

### Example of Valid Documentation Being Flagged

```swift
/// Represents data points in 3D space (X, Y, Z coordinates) with support for
/// color-coding, size variation, and fitted regression planes for multi-variable analysis.
@available(visionOS 1.0, *)
@available(iOS, unavailable)
@available(macOS, unavailable)
public struct Scatter3DData: Sendable {
```

The analyzer flags `Scatter3DData` as undocumented, but the `///` comment on lines above correctly attaches to the struct through the `@available` attributes.

### Affected Items in Current Report

All 9 struct declarations in `Charts3D/Data/Visualization3DData.swift`:
- `Scatter3DData` (line 11)
- `BoxPlot3DData` (line 82)
- `BoxPlot3DSeries` (line 103)
- `DistributionSurfaceData` (line 169)
- `Spatial3DData` (line 253)
- `EfficientFrontier3DData` (line 341)
- `VolatilitySurface3DData` (line 434)
- `CorrelationMatrix3DData` (line 488)
- `MonteCarloPath3DData` (line 535)

### Fix Required

When checking if a declaration has documentation, the analyzer should:

1. Look backwards from the declaration line
2. Skip over any `@available(...)` attributes
3. Skip over any `@MainActor`, `@Observable`, or other attributes
4. Check if a `///` doc comment exists immediately before the attributes

### Pseudocode for Fix

```python
def has_documentation(declaration_line_number, file_lines):
    line_index = declaration_line_number - 1  # 0-indexed

    # Walk backwards, skipping attributes
    while line_index > 0:
        line_index -= 1
        line = file_lines[line_index].strip()

        # Skip empty lines between attributes
        if line == "":
            continue

        # Skip @available and other attributes
        if line.startswith("@"):
            continue

        # Check for doc comment
        if line.startswith("///"):
            return True

        # Any other content means no doc comment
        break

    return False
```

---

## Issue 2: Code Examples in Documentation Comments

### Problem

The analyzer is detecting code patterns inside documentation comment blocks (multiline `/** */` or consecutive `///` lines) and treating them as actual undocumented code.

### Example

```swift
/**
 # SVG Export Usage

 ## Adding SVG Support to Your Chart

 ```swift
 extension MyChart: SVGExportable {
     public func generateSVG(size: CGSize) -> String {  // <-- Flagged as undocumented!
         // ...
     }
 }
 ```
 */
```

The analyzer flags `generateSVG` at line 95 in `Examples/SVGExportExample.swift` as undocumented, but this is just a code example inside a documentation block.

### Affected Items in Current Report

- `generateSVG` in `Examples/SVGExportExample.swift` (line 95)

### Fix Required

Before analyzing a line for documentation coverage:

1. Check if the line is inside a `/** */` block comment
2. Check if the line is inside a markdown code fence (``` ``` ```) within documentation
3. Skip lines that are part of documentation examples

### Pseudocode for Fix

```python
def is_inside_doc_block(line_number, file_lines):
    in_block_comment = False
    in_code_fence = False

    for i, line in enumerate(file_lines):
        stripped = line.strip()

        # Track block comments
        if "/**" in stripped and "*/" not in stripped:
            in_block_comment = True
        if "*/" in stripped:
            in_block_comment = False

        # Track code fences within comments
        if in_block_comment and stripped.startswith("```"):
            in_code_fence = not in_code_fence

        if i == line_number:
            return in_block_comment or in_code_fence

    return False

def should_check_for_docs(line_number, file_lines):
    # Skip if inside documentation block
    if is_inside_doc_block(line_number, file_lines):
        return False
    return True
```

---

## Expected Outcome After Fix

After implementing these fixes:

1. The 9 structs in `Visualization3DData.swift` should be recognized as documented
2. The `generateSVG` example in `SVGExportExample.swift` should not be flagged
3. Documentation coverage should increase from ~96.4% to ~100% (or close to it)

## Testing the Fix

Run the analyzer on the BusinessMath-UI codebase and verify:

```bash
# These should NOT appear in undocumented_apis:
- Scatter3DData
- BoxPlot3DData
- BoxPlot3DSeries
- DistributionSurfaceData
- Spatial3DData
- EfficientFrontier3DData
- VolatilitySurface3DData
- CorrelationMatrix3DData
- MonteCarloPath3DData
- generateSVG (from SVGExportExample.swift)
```
