// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickCal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuickCalKit", targets: ["QuickCalKit"]),
    ],
    targets: [
        .target(name: "QuickCalKit"),
        .testTarget(name: "QuickCalKitTests", dependencies: ["QuickCalKit"]),
    ]
)
