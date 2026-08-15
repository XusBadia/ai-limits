// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AILimitsCollectors",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AILimitsCollectors", targets: ["AILimitsCollectors"]),
        .executable(name: "ailimits-probe", targets: ["AILimitsProbe"]),
    ],
    dependencies: [.package(path: "../core")],
    targets: [
        .target(name: "AILimitsCollectors", dependencies: [.product(name: "AILimitsCore", package: "core")]),
        .executableTarget(name: "AILimitsProbe", dependencies: ["AILimitsCollectors", .product(name: "AILimitsCore", package: "core")]),
        .testTarget(name: "AILimitsCollectorsTests", dependencies: ["AILimitsCollectors", .product(name: "AILimitsCore", package: "core")]),
    ],
    swiftLanguageModes: [.v5]
)

