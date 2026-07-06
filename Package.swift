// swift-tools-version: 6.2

import PackageDescription

let linuxCI = Context.environment["KAWARIMI_LINUX_CI"] == "1"

var products: [Product] = [
    .executable(name: "Kawarimi", targets: ["Kawarimi"]),
    .executable(name: "KawarimiValidate", targets: ["KawarimiValidate"]),
    .library(name: "KawarimiCore", targets: ["KawarimiCore"]),
    .library(name: "KawarimiJutsu", targets: ["KawarimiJutsu"]),
    .library(name: "KawarimiServer", targets: ["KawarimiServer"]),
    .library(name: "KawarimiClient", targets: ["KawarimiClient"]),
    .plugin(
        name: "KawarimiPlugin",
        targets: ["KawarimiPlugin"]
    ),
]

var targets: [Target] = [
    .target(
        name: "KawarimiCore",
        dependencies: [
            .product(name: "HTTPTypes", package: "swift-http-types"),
        ]
    ),
    .target(
        name: "KawarimiJutsu",
        dependencies: [
            "KawarimiCore",
            .product(name: "Yams", package: "Yams"),
            .product(name: "OpenAPIKit", package: "OpenAPIKit"),
            .product(name: "OpenAPIKit30", package: "OpenAPIKit"),
            .product(name: "OpenAPIKitCompat", package: "OpenAPIKit"),
        ]
    ),
    .executableTarget(
        name: "Kawarimi",
        dependencies: [
            "KawarimiCore",
            "KawarimiJutsu",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .executableTarget(
        name: "KawarimiValidate",
        dependencies: [
            "KawarimiCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .plugin(
        name: "KawarimiPlugin",
        capability: .buildTool(),
        dependencies: ["Kawarimi"]
    ),
    .target(
        name: "KawarimiServer",
        dependencies: [
            "KawarimiCore",
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]
    ),
    .target(
        name: "KawarimiClient",
        dependencies: [
            "KawarimiCore",
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]
    ),
    .target(
        name: "KawarimiHengeCore",
        dependencies: [
            "KawarimiCore",
            .product(name: "HTTPTypes", package: "swift-http-types"),
        ],
        path: "Sources/KawarimiHengeCore"
    ),
    .testTarget(
        name: "KawarimiJutsuTests",
        dependencies: ["KawarimiJutsu", "KawarimiCore"],
        path: "Tests/KawarimiJutsuTests",
        resources: [.copy("../KawarimiCoreTests/Fixtures")]
    ),
    .testTarget(
        name: "KawarimiHengeCoreTests",
        dependencies: ["KawarimiHengeCore", "KawarimiCore"],
        path: "Tests/KawarimiHengeCoreTests"
    ),
    .testTarget(
        name: "KawarimiCoreTests",
        dependencies: ["KawarimiCore"],
        resources: [.copy("Fixtures")]
    ),
    .testTarget(
        name: "KawarimiServerTests",
        dependencies: [
            "KawarimiServer",
            "KawarimiCore",
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]
    ),
    .testTarget(
        name: "KawarimiClientTests",
        dependencies: [
            "KawarimiClient",
            "KawarimiCore",
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]
    ),
    .testTarget(
        name: "KawarimiTests",
        dependencies: []
    ),
    .testTarget(
        name: "KawarimiValidateTests",
        dependencies: ["KawarimiCore"]
    ),
]

if !linuxCI {
    products.append(.library(name: "KawarimiHenge", targets: ["KawarimiHenge"]))
    targets.append(
        .target(
            name: "KawarimiHenge",
            dependencies: [
                "KawarimiCore",
                "KawarimiHengeCore",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/KawarimiHenge"
        )
    )
}

let package = Package(
    name: "Kawarimi",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "3.9.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    ],
    targets: targets
)
