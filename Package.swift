// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Kawarimi",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "Kawarimi", targets: ["Kawarimi"]),
        .library(name: "KawarimiCore", targets: ["KawarimiCore"]),
        .library(name: "KawarimiJutsu", targets: ["KawarimiJutsu"]),
        .library(name: "KawarimiHenge", targets: ["KawarimiHenge"]),
        .plugin(
            name: "KawarimiPlugin",
            targets: ["KawarimiPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "6.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
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
            dependencies: ["KawarimiJutsu"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .plugin(
            name: "KawarimiPlugin",
            capability: .buildTool(),
            dependencies: ["Kawarimi"]
        ),
        .target(
            name: "KawarimiHenge",
            dependencies: [
                "KawarimiCore",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .testTarget(
            name: "KawarimiCoreTests",
            dependencies: ["KawarimiCore", "KawarimiJutsu"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "KawarimiHengeTests",
            dependencies: [
                "KawarimiHenge",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .testTarget(
            name: "KawarimiTests",
            dependencies: []
        ),
    ]
)
