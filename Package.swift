// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "CodeEditView",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "CodeEditView",
            targets: ["CodeEditView"]),
    ],
    targets: [
        .target(
            name: "CodeEditView"
        ),
        .testTarget(
            name: "CodeEditViewTests",
            dependencies: ["CodeEditView"]),
    ]
)
