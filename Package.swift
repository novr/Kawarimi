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
        .library(name: "KawarimiHenge", targets: ["KawarimiHenge"]),
        .plugin(
            name: "KawarimiPlugin",
            targets: ["KawarimiPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "3.9.0"),
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
            dependencies: ["KawarimiCore"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .plugin(
            name: "KawarimiPlugin",
            capability: .buildTool(),
            dependencies: ["Kawarimi"]
        ),
        .target(
            name: "KawarimiHenge",
            dependencies: ["KawarimiCore"]
        ),
        .testTarget(
            name: "KawarimiCoreTests",
            dependencies: ["KawarimiCore"],
            resources: [.copy("openapi.yaml")]
        ),
        .testTarget(
            name: "KawarimiTests",
            dependencies: [],
            resources: [.copy("openapi.yaml")]
        ),
        .testTarget(
            name: "KawarimiHengeTests",
            dependencies: ["KawarimiHenge"]
        ),
    ]
)
