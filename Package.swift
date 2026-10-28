// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NetSwitchBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NetSwitchCore"),
        .executableTarget(name: "NetSwitchBar", dependencies: ["NetSwitchCore"]),
        .testTarget(name: "NetSwitchCoreTests", dependencies: ["NetSwitchCore"]),
    ]
)
