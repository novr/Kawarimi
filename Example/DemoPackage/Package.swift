// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DemoPackage",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "DemoAPI", targets: ["DemoAPI"]),
    ],
    dependencies: [
        .package(name: "Kawarimi", path: "../.."),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/vapor/swift-openapi-vapor", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor", from: "4.89.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DemoAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "KawarimiCore", package: "Kawarimi"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
                .plugin(name: "KawarimiPlugin", package: "Kawarimi"),
            ]
        ),
        .executableTarget(
            name: "DemoServer",
            dependencies: [
                "DemoAPI",
                .product(name: "KawarimiCore", package: "Kawarimi"),
                .product(
                    name: "OpenAPIVapor",
                    package: "swift-openapi-vapor",
                    condition: .when(platforms: [.macOS])
                ),
                .product(name: "Vapor", package: "vapor", condition: .when(platforms: [.macOS])),
            ],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(
            name: "DemoAPITests",
            dependencies: ["DemoAPI"],
            path: "Tests/DemoAPITests"
        ),
    ]
)
