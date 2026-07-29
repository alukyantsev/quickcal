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
        .testTarget(
            name: "QuickCalKitTests",
            dependencies: ["QuickCalKit"],
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                ]),
            ]
        ),
    ]
)
