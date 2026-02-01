// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Kawarimi",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Kawarimi", targets: ["Kawarimi"]),
        .plugin(
            name: "KawarimiPlugin",
            targets: ["KawarimiPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "3.9.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "KawarimiCore",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "OpenAPIKit30", package: "OpenAPIKit"),
            ]
        ),
        .executableTarget(
            name: "Kawarimi",
            dependencies: [
                "KawarimiCore",
                .product(name: "_OpenAPIGeneratorCore", package: "swift-openapi-generator"),
            ]
        ),
        .plugin(
            name: "KawarimiPlugin",
            capability: .buildTool(),
            dependencies: ["Kawarimi"]
        ),
        .testTarget(
            name: "KawarimiCoreTests",
            dependencies: ["KawarimiCore"],
            resources: [.copy("openapi.yaml")]
        ),
        .testTarget(
            name: "KawarimiIntegrationTests",
            dependencies: [],
            resources: [.copy("openapi.yaml")]
        ),
    ]
)
