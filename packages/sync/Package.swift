// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AILimitsSync",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "AILimitsSync", targets: ["AILimitsSync"])],
    dependencies: [.package(path: "../core")],
    targets: [
        .target(name: "AILimitsSync", dependencies: [.product(name: "AILimitsCore", package: "core")]),
        .testTarget(name: "AILimitsSyncTests", dependencies: ["AILimitsSync", .product(name: "AILimitsCore", package: "core")]),
    ],
    swiftLanguageModes: [.v5]
)

