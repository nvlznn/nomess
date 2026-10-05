// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoMess",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NoMess", targets: ["NoMess"]),
        .executable(name: "nomess-clean", targets: ["nomess-clean"]),
    ],
    targets: [
        .target(name: "NoMessCore"),
        .executableTarget(name: "NoMess", dependencies: ["NoMessCore"]),
        .executableTarget(name: "nomess-clean", dependencies: ["NoMessCore"]),
        .testTarget(name: "NoMessCoreTests", dependencies: ["NoMessCore"]),
    ]
)
