// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stubli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StuebliApp", targets: ["StubliUI"]),
        .executable(name: "stubli", targets: ["StubliCLI"]),
        .executable(name: "stubli-checks", targets: ["StubliChecks"])
    ],
    targets: [
        .target(name: "StubliCore", resources: [.copy("Resources/ikea-ch.json")]),
        .executableTarget(name: "StubliUI", dependencies: ["StubliCore"], path: "Sources/Stubli"),
        .executableTarget(name: "StubliCLI", dependencies: ["StubliCore"]),
        .executableTarget(name: "StubliChecks", dependencies: ["StubliCore"], path: "Tests/StubliCoreTests")
    ]
)
