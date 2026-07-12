// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DriveRescueAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DriveRescueAssistant", targets: ["DriveRescueAssistant"])
    ],
    targets: [
        .executableTarget(
            name: "DriveRescueAssistant",
            path: "macos/DriveRescueAssistant",
            exclude: ["Resources"]
        )
    ]
)
