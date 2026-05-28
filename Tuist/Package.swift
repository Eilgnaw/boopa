// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Boopa",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
    ]
)
