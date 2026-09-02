// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReSizeCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ReSizeCore", targets: ["ReSizeCore"])],
    targets: [
        .target(name: "ReSizeCore", path: "ReSize/Core"),
        .testTarget(name: "ReSizeCoreTests", dependencies: ["ReSizeCore"])
    ]
)
