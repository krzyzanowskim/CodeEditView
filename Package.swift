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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/TextBufferKit", .branch("main"))
    ],
    targets: [
        .target(
            name: "CodeEditView",
            dependencies: [
                "TextBufferKit"
            ]
        ),
        .testTarget(
            name: "CodeEditViewTests",
            dependencies: ["CodeEditView"]),
    ]
)
