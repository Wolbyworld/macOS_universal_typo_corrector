// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "LuziaUniversalTypoCorrecter",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "LuziaUniversalTypoCorrecter",
            targets: ["LuziaUniversalTypoCorrecter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "LuziaUniversalTypoCorrecter",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]),
    ]
) 