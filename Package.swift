// swift-tools-version:4.0
// Generated automatically by Perfect Assistant 2
// Date: 2017-11-22 17:52:51 +0000
import PackageDescription

let package = Package(
	name: "PerfectSwORM",
	products: [
		.library(name: "PerfectSwORM", targets: ["PerfectSwORM"])
	],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-SQLite.git", "3.0.0"..<"4.0.0")
	],
	targets: [
		.target(name: "PerfectSwORM", dependencies: []),
		.testTarget(name: "PerfectSwORMTests", dependencies: ["PerfectSwORM", "PerfectSQLite"])
	]
)
