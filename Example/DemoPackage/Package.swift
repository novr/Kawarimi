// swift-tools-version: 6.2

import PackageDescription

let linuxCI = Context.environment["KAWARIMI_LINUX_CI"] == "1"

var products: [Product] = [
    .library(name: "DemoAPI", targets: ["DemoAPI"]),
]

var targets: [Target] = [
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
            .product(name: "KawarimiServer", package: "Kawarimi"),
            .product(
                name: "OpenAPIVapor",
                package: "swift-openapi-vapor",
                condition: .when(platforms: [.macOS, .linux])
            ),
            .product(name: "Vapor", package: "vapor", condition: .when(platforms: [.macOS, .linux])),
        ],
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .testTarget(
        name: "DemoAPITests",
        dependencies: ["DemoAPI"],
        path: "Tests/DemoAPITests"
    ),
    .testTarget(
        name: "DemoServerE2ETests",
        dependencies: [
            "DemoAPI",
            .product(name: "KawarimiCore", package: "Kawarimi"),
        ],
        path: "Tests/DemoServerE2ETests"
    ),
]

if !linuxCI {
    products.append(.executable(name: "HengeCli", targets: ["HengeCli"]))
    targets.append(
        .executableTarget(
            name: "HengeCli",
            dependencies: [
                .product(name: "KawarimiCore", package: "Kawarimi"),
                .product(name: "KawarimiHenge", package: "Kawarimi"),
            ]
        )
    )
}

let package = Package(
    name: "DemoPackage",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: products,
    dependencies: [
        .package(name: "Kawarimi", path: "../.."),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/vapor/swift-openapi-vapor", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor", from: "4.89.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: targets
)
