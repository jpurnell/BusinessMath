---
title: Integer Programming: Optimal Decisions with Whole Numbers
date: 2026-03-04 13:00
series: BusinessMath Quarterly Series
week: 9
post: 2
docc_source: 5.8-IntegerProgramming.md
playground: Week09/Integer-Programming.playground
tags: businessmath, swift, optimization, integer-programming, branch-and-bound, discrete-optimization, scheduling
layout: BlogPostLayout
published: false
---

# Integer Programming: Optimal Decisions with Whole Numbers

**Part 30 of 12-Week BusinessMath Series**

---

## What You'll Learn

- Understanding when integer constraints are necessary
- Implementing branch-and-bound for exact integer solutions
- Using relaxation techniques for faster approximate solutions
- Modeling binary (0/1) decision variables
- Solving scheduling, assignment, and selection problems
- Performance trade-offs: exact vs. heuristic methods

---

## The Problem

Many business decisions require whole numbers:
- **Capital budgeting**: How many machines to purchase? (Can't buy 2.7 machines)
- **Workforce planning**: How many employees to hire? (Can't hire 14.3 people)
- **Project selection**: Which projects to fund? (Binary yes/no)
- **Production scheduling**: How many batches to produce? (Integer batch sizes)

**Continuous optimization solvers give you fractional answers—but you need integers.**

---

## The Solution

BusinessMath provides integer programming solvers that find optimal whole-number solutions. The core technique is **branch-and-bound**: solve relaxed continuous problems, then systematically explore integer solutions.

### Pattern 1: Capital Budgeting (0/1 Knapsack)

**Business Problem**: You have $500K budget. Which projects should you fund?

```swift
import BusinessMath

// Define projects
struct Project {
    let name: String
    let cost: Double
    let npv: Double
    let requiredStaff: Int
}

let projects = [
    Project(name: "New Product Launch", cost: 200_000, npv: 350_000, requiredStaff: 5),
    Project(name: "Factory Upgrade", cost: 180_000, npv: 280_000, requiredStaff: 3),
    Project(name: "Marketing Campaign", cost: 100_000, npv: 150_000, requiredStaff: 2),
    Project(name: "IT System", cost: 150_000, npv: 200_000, requiredStaff: 4),
    Project(name: "R&D Initiative", cost: 120_000, npv: 180_000, requiredStaff: 6)
]

let budget = 500_000.0
let availableStaff = 10

// Binary decision variables: x[i] ∈ {0, 1} (fund project i or not)
// Objective: Maximize total NPV
// Constraints: Total cost ≤ budget, total staff ≤ available

let integerOptimizer = IntegerProgrammingSolver()

// Objective: Maximize NPV (minimize negative NPV)
let objective: (Vector<Int>) -> Double = { decisions in
    -zip(projects, decisions.elements).map { project, decision in
        project.npv * Double(decision)
    }.reduce(0, +)
}

// Constraint 1: Budget
let budgetConstraint: (Vector<Int>) -> Bool = { decisions in
    let totalCost = zip(projects, decisions.elements).map { project, decision in
        project.cost * Double(decision)
    }.reduce(0, +)
    return totalCost <= budget
}

// Constraint 2: Staff availability
let staffConstraint: (Vector<Int>) -> Bool = { decisions in
    let totalStaff = zip(projects, decisions.elements).map { project, decision in
        project.requiredStaff * decision
    }.reduce(0, +)
    return totalStaff <= availableStaff
}

// Solve using branch-and-bound
let result = try integerOptimizer.minimize(
    objective,
    variables: projects.count,
    domain: 0...1,  // Binary: each variable is 0 or 1
    constraints: [budgetConstraint, staffConstraint]
)

// Interpret results
print("Optimal Project Portfolio:")
var totalCost = 0.0
var totalNPV = 0.0
var totalStaff = 0

for (project, decision) in zip(projects, result.solution.elements) {
    if decision == 1 {
        print("  ✓ \(project.name)")
        print("    Cost: \(project.cost.currency()), NPV: \(project.npv.currency()), Staff: \(project.requiredStaff)")
        totalCost += project.cost
        totalNPV += project.npv
        totalStaff += project.requiredStaff
    }
}

print("\nPortfolio Summary:")
print("  Total Cost: \(totalCost.currency()) / \(budget.currency())")
print("  Total NPV: \(totalNPV.currency())")
print("  Total Staff: \(totalStaff) / \(availableStaff)")
print("  Budget Utilization: \((totalCost / budget * 100).number())%")
```

### Pattern 2: Production Scheduling with Lot Sizes

**Business Problem**: Minimize production costs. Each product has a fixed setup cost and must be produced in minimum lot sizes.

```swift
// Products with setup costs and lot size requirements
struct ProductionRun {
    let product: String
    let setupCost: Double
    let variableCost: Double
    let minimumLotSize: Int
    let demand: Int
}

let productionRuns = [
    ProductionRun(product: "Widget A", setupCost: 5_000, variableCost: 10, minimumLotSize: 100, demand: 450),
    ProductionRun(product: "Widget B", setupCost: 3_000, variableCost: 8, minimumLotSize: 50, demand: 280),
    ProductionRun(product: "Widget C", setupCost: 4_000, variableCost: 12, minimumLotSize: 75, demand: 350)
]

let maxProductionCapacity = 1000

// Decision variables: number of lots to produce (integer)
// Objective: Minimize total cost (setup + variable)
// Constraints: Meet demand, don't exceed capacity, minimum lot sizes

let costObjective: (Vector<Int>) -> Double = { lots in
    zip(productionRuns, lots.elements).map { run, numLots in
        if numLots > 0 {
            return run.setupCost + (run.variableCost * Double(numLots * run.minimumLotSize))
        } else {
            return 0.0
        }
    }.reduce(0, +)
}

// Constraint 1: Meet demand for each product
let demandConstraints = productionRuns.enumerated().map { i, run in
    { (lots: Vector<Int>) -> Bool in
        lots[i] * run.minimumLotSize >= run.demand
    }
}

// Constraint 2: Total production within capacity
let capacityConstraint: (Vector<Int>) -> Bool = { lots in
    let totalProduction = zip(productionRuns, lots.elements).map { run, numLots in
        numLots * run.minimumLotSize
    }.reduce(0, +)
    return totalProduction <= maxProductionCapacity
}

// Solve
let productionResult = try integerOptimizer.minimize(
    costObjective,
    variables: productionRuns.count,
    domain: 0...20,  // Max 20 lots per product
    constraints: demandConstraints + [capacityConstraint]
)

print("Optimal Production Schedule:")
for (run, numLots) in zip(productionRuns, productionResult.solution.elements) {
    let totalUnits = numLots * run.minimumLotSize
    let cost = numLots > 0 ? run.setupCost + (run.variableCost * Double(totalUnits)) : 0.0

    print("  \(run.product): \(numLots) lots × \(run.minimumLotSize) units = \(totalUnits) units")
    print("    Demand: \(run.demand), Excess: \(totalUnits - run.demand)")
    print("    Cost: \(cost.currency())")
}

let totalCost = productionResult.value
print("\nTotal Production Cost: \(totalCost.currency())")
```

### Pattern 3: Assignment Problem (Workers to Tasks)

**Business Problem**: Assign workers to tasks to minimize total time, where each worker has different efficiencies.

```swift
// Workers and their time to complete each task (hours)
let workers = ["Alice", "Bob", "Carol", "Dave"]
let tasks = ["Task 1", "Task 2", "Task 3", "Task 4"]

// Time matrix: timeMatrix[worker][task] = hours
let timeMatrix = [
    [8, 12, 6, 10],   // Alice's times
    [10, 9, 7, 12],   // Bob's times
    [7, 11, 9, 8],    // Carol's times
    [11, 8, 10, 7]    // Dave's times
]

// Binary assignment matrix: x[i][j] = 1 if worker i assigned to task j
// Objective: Minimize total time
// Constraints: Each worker assigned to exactly one task, each task assigned to exactly one worker

// Flatten assignment matrix to 1D vector for optimizer
let numWorkers = workers.count
let numTasks = tasks.count

let assignmentObjective: (Vector<Int>) -> Double = { assignments in
    var totalTime = 0.0
    for i in 0..<numWorkers {
        for j in 0..<numTasks {
            let index = i * numTasks + j
            if assignments[index] == 1 {
                totalTime += Double(timeMatrix[i][j])
            }
        }
    }
    return totalTime
}

// Constraint 1: Each worker assigned to exactly one task
let workerConstraints = (0..<numWorkers).map { worker in
    { (assignments: Vector<Int>) -> Bool in
        let assignmentsForWorker = (0..<numTasks).map { task in
            assignments[worker * numTasks + task]
        }
        return assignmentsForWorker.reduce(0, +) == 1
    }
}

// Constraint 2: Each task assigned to exactly one worker
let taskConstraints = (0..<numTasks).map { task in
    { (assignments: Vector<Int>) -> Bool in
        let assignmentsForTask = (0..<numWorkers).map { worker in
            assignments[worker * numTasks + task]
        }
        return assignmentsForTask.reduce(0, +) == 1
    }
}

// Solve
let assignmentResult = try integerOptimizer.minimize(
    assignmentObjective,
    variables: numWorkers * numTasks,
    domain: 0...1,
    constraints: workerConstraints + taskConstraints
)

print("Optimal Assignment:")
var totalTime = 0
for i in 0..<numWorkers {
    for j in 0..<numTasks {
        let index = i * numTasks + j
        if assignmentResult.solution[index] == 1 {
            let time = timeMatrix[i][j]
            print("  \(workers[i]) → \(tasks[j]) (\(time) hours)")
            totalTime += time
        }
    }
}

print("\nTotal Time: \(totalTime) hours")

// Compare to greedy heuristic
print("\nGreedy Heuristic (for comparison):")
var greedyTime = 0
var assignedWorkers = Set<Int>()
var assignedTasks = Set<Int>()

// Sort all (worker, task, time) pairs by time
var allPairs: [(worker: Int, task: Int, time: Int)] = []
for i in 0..<numWorkers {
    for j in 0..<numTasks {
        allPairs.append((worker: i, task: j, time: timeMatrix[i][j]))
    }
}
allPairs.sort { $0.time < $1.time }

// Greedily assign shortest times first
for pair in allPairs {
    if !assignedWorkers.contains(pair.worker) && !assignedTasks.contains(pair.task) {
        print("  \(workers[pair.worker]) → \(tasks[pair.task]) (\(pair.time) hours)")
        greedyTime += pair.time
        assignedWorkers.insert(pair.worker)
        assignedTasks.insert(pair.task)
    }

    if assignedWorkers.count == numWorkers {
        break
    }
}

print("\nGreedy Total Time: \(greedyTime) hours")
print("Optimal is \(greedyTime - totalTime) hours better (\((Double(greedyTime - totalTime) / Double(greedyTime) * 100).number())% improvement)")
```

---

## How It Works

### Branch-and-Bound Algorithm

1. **Relax**: Solve continuous version (allows fractional values)
2. **Branch**: If solution is fractional, split into two subproblems:
   - Subproblem A: x[i] ≤ floor(fractional_value)
   - Subproblem B: x[i] ≥ ceil(fractional_value)
3. **Bound**: Track best integer solution found so far
4. **Prune**: Discard subproblems that can't improve on best solution
5. **Repeat**: Continue until all subproblems explored or pruned

### Performance Characteristics

| Problem Size | Variables | Exact Solution Time | Heuristic Time |
|--------------|-----------|---------------------|----------------|
| Small (10 vars) | 10 | <1 second | <0.1 second |
| Medium (50 vars) | 50 | 5-30 seconds | 0.5 seconds |
| Large (100 vars) | 100 | 1-10 minutes | 2 seconds |
| Very Large (500+) | 500+ | Hours or infeasible | 10-30 seconds |

**Rule of Thumb**: For problems with >100 integer variables, use heuristics (genetic algorithms, simulated annealing) for approximate solutions.

---

## Real-World Application

### Logistics: Truck Routing and Loading

**Company**: Regional distributor with 8 warehouses, 40 delivery locations
**Challenge**: Minimize delivery costs while meeting delivery windows

**Integer Variables**:
- Number of trucks to deploy from each warehouse (integer)
- Which customers each truck serves (binary assignment)

**Before BusinessMath**:
- Manual routing with spreadsheet
- Rules of thumb ("send 3 trucks from Warehouse A")
- No optimization, high fuel costs

**After BusinessMath**:
```swift
let routingOptimizer = TruckRoutingOptimizer(
    warehouses: warehouseLocations,
    customers: customerOrders,
    trucks: truckFleet
)

let optimalRouting = try routingOptimizer.minimizeCost(
    constraints: [
        .deliveryWindows,
        .truckCapacity,
        .driverHours
    ]
)
```

**Results**:
- Fuel costs reduced: 18%
- Trucks required: 12 (down from 15)
- On-time deliveries: 97% (up from 89%)

---

## Try It Yourself

Download the complete playground with 5 integer programming examples:

```
→ Download: Week09/Integer-Programming.playground
→ Full API Reference: BusinessMath Docs – Integer Programming Guide
```

### Modifications to Try

1. **Add Precedence Constraints**: Some projects must be completed before others
2. **Multi-Period Scheduling**: Extend production to quarterly planning
3. **Partial Assignments**: Allow workers to split time across multiple tasks
4. **Penalty Costs**: Add penalty for unmet demand vs. fixed constraint

---

## Next Steps

**Tomorrow**: We'll explore **Adaptive Selection** for automatically choosing the best optimization algorithm for your problem.

**Thursday**: Week 9 concludes with **Parallel Optimization** for leveraging multiple CPU cores.

---

**Series**: [Week 9 of 12] | **Topic**: [Part 5 - Business Applications] | **Case Studies**: [4/6 Complete]

**Topics Covered**: Integer programming • Branch-and-bound • Binary decisions • Assignment problems • Production scheduling

**Playgrounds**: [Week 1-9 available] • [Next: Adaptive selection]
