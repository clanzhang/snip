// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "snip",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "snip", targets: ["Snip"])
    ],
    targets: [
        .executableTarget(
            name: "Snip",
            path: "Sources/Snip",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation")
            ]
        ),
        .testTarget(
            name: "SnipTests",
            dependencies: ["Snip"],
            path: "Tests/SnipTests"
        )
    ]
)