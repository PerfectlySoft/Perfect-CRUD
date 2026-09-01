// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerfectCRUD",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "PerfectCRUD", targets: ["PerfectCRUD"])
    ],
    dependencies: [],
    targets: [
        .target(name: "PerfectCRUD", dependencies: []),
        .testTarget(
            name: "PerfectCRUDTests",
            dependencies: ["PerfectCRUD"],
            path: "Tests/PerfectCRUDTests"
        ),
    ]
)
