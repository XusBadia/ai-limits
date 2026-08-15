// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AILimitsCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "AILimitsCore", targets: ["AILimitsCore"])],
    targets: [
        .target(name: "AILimitsCore"),
        .testTarget(name: "AILimitsCoreTests", dependencies: ["AILimitsCore"]),
    ]
)

