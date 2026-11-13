//
//  ReferenceGraphs.swift
//  TestSupport
//
//  Published reference graphs, as plain edge lists. Test-only: never part of the library.
//

import Foundation

/// Published graphs with known structure, for tests.
public enum ReferenceGraphs {

	/// Krackhardt's kite graph: ten people, eighteen ties.
	public static let kiteEdges: [(String, String)] = [
		("Andre", "Beverly"), ("Andre", "Carol"), ("Andre", "Diane"),
		("Andre", "Fernando"),
		("Beverly", "Diane"), ("Beverly", "Ed"), ("Beverly", "Garth"),
		("Carol", "Diane"), ("Carol", "Fernando"),
		("Diane", "Ed"), ("Diane", "Fernando"), ("Diane", "Garth"),
		("Ed", "Garth"),
		("Fernando", "Garth"), ("Fernando", "Heather"),
		("Garth", "Heather"),
		("Heather", "Ike"),
		("Ike", "Jane"),
	]

	/// Zachary's karate club (1977): thirty-four members, seventy-eight ties.
	public static let karateEdges: [(Int, Int)] = [
		(1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9),
		(1, 11), (1, 12), (1, 13), (1, 14), (1, 18), (1, 20), (1, 22), (1, 32),
		(2, 3), (2, 4), (2, 8), (2, 14), (2, 18), (2, 20), (2, 22), (2, 31),
		(3, 4), (3, 8), (3, 9), (3, 10), (3, 14), (3, 28), (3, 29), (3, 33),
		(4, 8), (4, 13), (4, 14),
		(5, 7), (5, 11),
		(6, 7), (6, 11), (6, 17),
		(7, 17),
		(9, 31), (9, 33), (9, 34),
		(10, 34),
		(14, 34),
		(15, 33), (15, 34),
		(16, 33), (16, 34),
		(19, 33), (19, 34),
		(20, 34),
		(21, 33), (21, 34),
		(23, 33), (23, 34),
		(24, 26), (24, 28), (24, 30), (24, 33), (24, 34),
		(25, 26), (25, 28), (25, 32),
		(26, 32),
		(27, 30), (27, 34),
		(28, 34),
		(29, 32), (29, 34),
		(30, 33), (30, 34),
		(31, 33), (31, 34),
		(32, 33), (32, 34),
		(33, 34),
	]

	/// Published degrees for the kite graph.
	public static let kiteDegrees: [String: Int] = [
		"Diane": 6, "Fernando": 5, "Garth": 5, "Andre": 4, "Beverly": 4,
		"Carol": 3, "Ed": 3, "Heather": 3, "Ike": 2, "Jane": 1,
	]

	/// The faction each karate-club member actually joined, as Zachary recorded it.
	///
	/// Node 1 is the instructor, node 34 the administrator. Node 9 is the famous awkward case:
	/// he joined the officer's club for reasons outside the network.
	public static let karateInstructorFaction: Set<Int> = [
		1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 17, 18, 20, 22,
	]

	/// Published degrees for the well-known karate club members.
	public static let karateDegrees: [Int: Int] = [
		34: 17, 1: 16, 33: 12, 3: 10, 2: 9, 32: 6, 4: 6, 24: 5,
	]
}
