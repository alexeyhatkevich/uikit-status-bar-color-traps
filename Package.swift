// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatusBarColorTraps",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "StatusBarColorTraps", targets: ["StatusBarColorTraps"]),
    ],
    targets: [
        .target(name: "StatusBarColorTraps"),
        .testTarget(name: "StatusBarColorTrapsTests", dependencies: ["StatusBarColorTraps"]),
    ]
)
