// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "clipdoctor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "clipdoctor",
            path: "Sources/clipdoctor"
        )
    ]
)