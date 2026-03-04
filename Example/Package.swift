// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Example",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/vapor/swift-openapi-vapor", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor", from: "4.89.0"),
    ],
    targets: [
        .target(
            name: "DemoAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            resources: [.copy("kawarimi.yaml")],
            plugins: [.plugin(name: "KawarimiPlugin", package: "Kawarimi")]
        ),
        .executableTarget(
            name: "DemoServer",
            dependencies: [
                "DemoAPI",
                .product(name: "KawarimiCore", package: "Kawarimi"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
                .product(name: "Vapor", package: "vapor"),
            ],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .executableTarget(
            name: "DemoApp",
            dependencies: [
                "DemoAPI",
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .executableTarget(
            name: "DemoAppUI",
            dependencies: ["DemoAPI"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(
            name: "DemoAPITests",
            dependencies: ["DemoAPI"],
            path: "Tests/DemoAPITests"
        ),
    ]
)
