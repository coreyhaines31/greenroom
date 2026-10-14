// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GreenRoomCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GreenRoomCore", targets: ["GreenRoomCore"])
    ],
    targets: [
        .target(name: "GreenRoomCore"),
        // Prints the connected devices from a terminal, for development. Not shipped.
        .executableTarget(name: "greenroom-dev", dependencies: ["GreenRoomCore"]),
        .testTarget(name: "GreenRoomCoreTests", dependencies: ["GreenRoomCore"])
    ]
)
