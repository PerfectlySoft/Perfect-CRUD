import Testing
import Foundation
// Deliberately a plain import, not `@testable` — this file exists to catch access-level
// regressions in the public API surface. Every other file in this target uses
// `@testable import`, which grants access to internal members and would silently mask
// a `CRUDTableStructure` visibility regression the way it did before this fix.
import PerfectCRUD

private struct CrossModuleProbeModel: Codable {
	var id: Int
	var name: String
}

@Test func crossModuleCRUDTableStructureIsPublic() throws {
	let structure = try CrossModuleProbeModel.CRUDTableStructure()
	#expect(structure.columns.map { $0.name }.contains("name"))
}
