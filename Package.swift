// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-card-kit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CardKit", targets: ["CardKit"]),
    ],
    targets: [
        .target(name: "CardKit"),
        .testTarget(name: "CardKitTests", dependencies: ["CardKit"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
