// swift-tools-version: 6.0
import PackageDescription
import Foundation

let fileManager = FileManager.default
let developerDirectories = [
    ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
    "/Applications/Xcode.app/Contents/Developer",
    "/Library/Developer/CommandLineTools",
].compactMap { $0 }

let testingFrameworkDirectory = developerDirectories
    .map { "\($0)/Library/Developer/Frameworks" }
    .first { fileManager.fileExists(atPath: "\($0)/Testing.framework") }
let testingInteropDirectory = developerDirectories
    .map { "\($0)/Library/Developer/usr/lib" }
    .first { fileManager.fileExists(atPath: "\($0)/lib_TestingInterop.dylib") }

let testingSwiftSettings: [SwiftSetting] = testingFrameworkDirectory.map {
    [.unsafeFlags([
        "-F", $0,
    ])]
} ?? []
let testingLinkerSettings: [LinkerSetting] = {
    var settings: [LinkerSetting] = []
    if let testingFrameworkDirectory {
        settings.append(.unsafeFlags([
            "-F", testingFrameworkDirectory,
            "-Xlinker", "-rpath",
            "-Xlinker", testingFrameworkDirectory,
        ]))
        settings.append(.linkedFramework("Testing"))
    }
    if let testingInteropDirectory {
        settings.append(.unsafeFlags([
            "-Xlinker", "-rpath",
            "-Xlinker", testingInteropDirectory,
        ]))
    }
    return settings
}()

let package = Package(
    name: "QuickCal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuickCalKit", targets: ["QuickCalKit"]),
        .executable(name: "QuickCal", targets: ["QuickCal"]),
    ],
    targets: [
        .target(name: "QuickCalKit"),
        .executableTarget(name: "QuickCal", dependencies: ["QuickCalKit"]),
        .testTarget(
            name: "QuickCalKitTests",
            dependencies: ["QuickCalKit"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ]
)
