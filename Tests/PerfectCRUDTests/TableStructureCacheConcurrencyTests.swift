import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - Phase 0 regression: tableStructureCache concurrency hazard
//
// `tableStructureCache` (Create.swift) is a global cache with no synchronization
// prior to this fix. It's reachable concurrently in real deployments — e.g. two
// requests to an app's schema-setup route both calling `db.create(SomeModel.self)`
// at once — and an unsynchronized `Dictionary` write under concurrent access is
// undefined behavior, not just a slow path. This model type is unique to this file
// so concurrent runs of other test suites (which populate the same global cache for
// their own models) can't interfere with or be interfered with by these tests.

private struct ConcurrencyProbeModel: Codable {
	var id: Int
	var name: String
	var email: String?
}

@Suite("tableStructureCache concurrency")
struct TableStructureCacheConcurrencyTests {

	// `TableStructure` is a plain, non-Sendable class — reasonable for its normal
	// single-threaded-per-call usage, but not something to hand across task
	// boundaries in this test. Each task extracts a small Sendable summary of the
	// structure it received instead of returning the class itself.
	private struct StructureSummary: Sendable, Equatable {
		let tableName: String
		let columnNames: [String]
	}

	@Test("concurrent first-time computation for the same type doesn't crash and converges to one consistent structure")
	func concurrentComputationIsSafe() async throws {
		// Deliberately not calling CRUDClearTableStructureCache() here: this model
		// type is unique to this test, so there's nothing to clear, and clearing the
		// global cache could disrupt other suites computing structures concurrently.
		let taskCount = 64

		let results = try await withThrowingTaskGroup(of: StructureSummary.self) { group in
			for _ in 0..<taskCount {
				group.addTask {
					let structure = try ConcurrencyProbeModel.CRUDTableStructure()
					return StructureSummary(tableName: structure.tableName,
											 columnNames: structure.columns.map(\.name).sorted())
				}
			}
			var collected: [StructureSummary] = []
			for try await result in group {
				collected.append(result)
			}
			return collected
		}

		#expect(results.count == taskCount)

		// Every concurrent caller must observe the same logical table structure —
		// same table name, same column set — regardless of which task actually
		// populated the cache first.
		let first = results[0]
		for summary in results {
			#expect(summary == first)
			#expect(summary.columnNames.count == 3)
		}

		// A subsequent, ordinary sequential call must return the now-cached value
		// with the fully-populated shape (no half-built entry left behind by a race).
		let afterward = try ConcurrencyProbeModel.CRUDTableStructure()
		#expect(afterward.tableName == first.tableName)
		#expect(afterward.columns.count == 3)
	}

	@Test("CRUDClearTableStructureCache is itself safe to call concurrently with lookups")
	func clearDuringConcurrentLookupsIsSafe() async throws {
		// Exercises the lock across both call paths (the cache-mutating clear function
		// and the compute-or-return-cached path) at once. This doesn't assert anything
		// about *which* result a racing lookup sees relative to a racing clear — only
		// that neither path corrupts the shared dictionary or crashes the process.
		_ = try ConcurrencyProbeModel.CRUDTableStructure()

		try await withThrowingTaskGroup(of: Void.self) { group in
			for _ in 0..<32 {
				group.addTask {
					_ = try ConcurrencyProbeModel.CRUDTableStructure()
				}
			}
			for _ in 0..<8 {
				group.addTask {
					CRUDClearTableStructureCache()
				}
			}
			try await group.waitForAll()
		}

		// The cache is left in a usable state either way — a call after the storm
		// must still succeed and return a well-formed structure.
		let structure = try ConcurrencyProbeModel.CRUDTableStructure()
		#expect(structure.columns.count == 3)
	}
}
