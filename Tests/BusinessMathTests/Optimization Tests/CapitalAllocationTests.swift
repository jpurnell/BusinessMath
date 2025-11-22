import Testing
import Foundation
@testable import BusinessMath

@Suite("Capital Allocation Tests")
struct CapitalAllocationTests {

	// MARK: - Helper Functions

	func makeSampleProjects() -> [CapitalAllocationOptimizer<Double>.Project] {
		return [
			CapitalAllocationOptimizer.Project(
				name: "Project A",
				npv: 100_000,
				capitalRequired: 50_000,
				risk: 0.2
			),
			CapitalAllocationOptimizer.Project(
				name: "Project B",
				npv: 150_000,
				capitalRequired: 100_000,
				risk: 0.3
			),
			CapitalAllocationOptimizer.Project(
				name: "Project C",
				npv: 80_000,
				capitalRequired: 40_000,
				risk: 0.15
			)
		]
	}

	// MARK: - Project Tests

	@Test("Project ROI calculation")
	func projectROI() throws {
		let project = CapitalAllocationOptimizer<Double>.Project(
			name: "Test Project",
			npv: 100_000,
			capitalRequired: 50_000
		)

		#expect(project.roi == 2.0)  // 100k / 50k = 2.0
	}

	// MARK: - Greedy Allocation

	@Test("Optimize allocation - unlimited budget")
	func unlimitedBudget() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = makeSampleProjects()

		let result = optimizer.optimize(
			projects: projects,
			budget: 1_000_000  // Plenty of budget
		)

		// Should allocate to all projects
		#expect(result.projectsSelected.count == 3)
		#expect(result.capitalUsed == 190_000)  // 50k + 100k + 40k
		#expect(result.totalNPV == 330_000)  // 100k + 150k + 80k
	}

	@Test("Optimize allocation - limited budget")
	func limitedBudget() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = makeSampleProjects()

		let result = optimizer.optimize(
			projects: projects,
			budget: 100_000
		)

		// Should select projects with highest ROI
		// Project A: ROI = 2.0, Project C: ROI = 2.0, Project B: ROI = 1.5
		#expect(result.capitalUsed <= 100_000)
		#expect(result.projectsSelected.count > 0)
	}

	@Test("Optimize allocation - very limited budget")
	func veryLimitedBudget() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = makeSampleProjects()

		let result = optimizer.optimize(
			projects: projects,
			budget: 45_000
		)

		// Can only afford Project C (40k)
		#expect(result.capitalUsed <= 45_000)
		#expect(result.totalNPV > 0)
	}

	@Test("Optimize allocation - zero budget")
	func zeroBudget() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = makeSampleProjects()

		let result = optimizer.optimize(
			projects: projects,
			budget: 0
		)

		#expect(result.projectsSelected.isEmpty)
		#expect(result.capitalUsed == 0)
		#expect(result.totalNPV == 0)
	}

	// MARK: - Integer Allocation (0-1 Knapsack)

	@Test("Integer allocation - all or nothing")
	func integerAllocation() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = makeSampleProjects()

		let result = optimizer.optimizeIntegerProjects(
			projects: projects,
			budget: 150_000
		)

		// Should select optimal combination
		#expect(result.capitalUsed <= 150_000)

		// Verify each project is either fully funded or not at all
		for (projectName, capital) in result.allocations {
			let project = projects.first { $0.name == projectName }!
			#expect(capital == project.capitalRequired || capital == 0)
		}
	}

	@Test("Integer allocation vs greedy comparison")
	func integerVsGreedy() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()

		// Create projects where greedy != optimal
		let projects = [
			CapitalAllocationOptimizer.Project(
				name: "Small High ROI",
				npv: 30,
				capitalRequired: 10
			),
			CapitalAllocationOptimizer.Project(
				name: "Medium High ROI",
				npv: 50,
				capitalRequired: 20
			),
			CapitalAllocationOptimizer.Project(
				name: "Large Medium ROI",
				npv: 70,
				capitalRequired: 30
			)
		]

		let budget: Double = 30

		let greedy = optimizer.optimize(projects: projects, budget: budget)
		let integer = optimizer.optimizeIntegerProjects(projects: projects, budget: budget)

		// Integer should find optimal solution
		#expect(integer.totalNPV >= greedy.totalNPV)
	}

	// MARK: - Allocation Result

	@Test("Allocation result description")
	func allocationResultDescription() throws {
		let result = CapitalAllocationOptimizer<Double>.AllocationResult(
			allocations: ["Project A": 50_000, "Project B": 100_000],
			totalNPV: 250_000,
			capitalUsed: 150_000,
			projectsSelected: ["Project A", "Project B"]
		)

		let description = result.description

		#expect(description.contains("Total NPV: 250000"))
		#expect(description.contains("Capital Used: 150000"))
		#expect(description.contains("Projects Selected: 2"))
		#expect(description.contains("Project A"))
		#expect(description.contains("Project B"))
	}

	// MARK: - Edge Cases

	@Test("Single project")
	func singleProject() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = [
			CapitalAllocationOptimizer.Project(
				name: "Only Project",
				npv: 100_000,
				capitalRequired: 50_000
			)
		]

		let result = optimizer.optimize(projects: projects, budget: 75_000)

		#expect(result.projectsSelected.count == 1)
		#expect(result.allocations["Only Project"] == 50_000)
	}

	@Test("No projects")
	func noProjects() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects: [CapitalAllocationOptimizer<Double>.Project] = []

		let result = optimizer.optimize(projects: projects, budget: 100_000)

		#expect(result.projectsSelected.isEmpty)
		#expect(result.totalNPV == 0)
		#expect(result.capitalUsed == 0)
	}

	@Test("All projects too expensive")
	func allProjectsTooExpensive() throws {
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = [
			CapitalAllocationOptimizer.Project(name: "A", npv: 100_000, capitalRequired: 200_000),
			CapitalAllocationOptimizer.Project(name: "B", npv: 150_000, capitalRequired: 250_000)
		]

		let result = optimizer.optimize(projects: projects, budget: 100_000)

		#expect(result.projectsSelected.isEmpty)
		#expect(result.totalNPV == 0)
	}
}

@Suite("Capital Allocation Additional Tests")
struct CapitalAllocationAdditionalTests {

	@Test("Prefers lower capital when ROI ties (if specified by design)")
	func tieBreakOnCapital() {
		// Only enable if your optimizer specifies this tie-break; otherwise remove/adjust.
		let optimizer = CapitalAllocationOptimizer<Double>()
		let projects = [
			CapitalAllocationOptimizer<Double>.Project(name: "A", npv: 20, capitalRequired: 10), // ROI=2.0
			CapitalAllocationOptimizer<Double>.Project(name: "B", npv: 40, capitalRequired: 20), // ROI=2.0
		]
		let result = optimizer.optimize(projects: projects, budget: 10)
		#expect(result.projectsSelected.contains("A"))
		#expect(!result.projectsSelected.contains("B"))
	}
}
