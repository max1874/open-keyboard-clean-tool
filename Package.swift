// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "open-keyboard-clean-tool",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OpenKeyboardCleanTool", targets: ["OpenKeyboardCleanTool"])
    ],
    targets: [
        .executableTarget(name: "OpenKeyboardCleanTool"),
        .testTarget(
            name: "OpenKeyboardCleanToolTests",
            dependencies: ["OpenKeyboardCleanTool"]
        )
    ],
    swiftLanguageModes: [.v5]
)
