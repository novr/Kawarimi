// swift-tools-version: 6.2

import PackageDescription

let linuxCI = Context.environment["KAWARIMI_LINUX_CI"] == "1"

var products: [Product] = [
    .executable(name: "Kawarimi", targets: ["Kawarimi"]),
    .library(name: "KawarimiCore", targets: ["KawarimiCore"]),
    .library(name: "KawarimiJutsu", targets: ["KawarimiJutsu"]),
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
        dependencies: ["KawarimiCore", "KawarimiJutsu"],
        swiftSettings: [.unsafeFlags(["-parse-as-library"])]
    ),
    .plugin(
        name: "KawarimiPlugin",
        capability: .buildTool(),
        dependencies: ["Kawarimi"]
    ),
    .testTarget(
        name: "KawarimiCoreTests",
        dependencies: ["KawarimiCore", "KawarimiJutsu"],
        resources: [.copy("Fixtures")]
    ),
    .testTarget(
        name: "KawarimiTests",
        dependencies: []
    ),
]

if !linuxCI {
    products.append(.library(name: "KawarimiHenge", targets: ["KawarimiHenge"]))
    targets.append(
        contentsOf: [
            .target(
                name: "KawarimiHenge",
                dependencies: [
                    "KawarimiCore",
                    .product(name: "HTTPTypes", package: "swift-http-types"),
                ]
            ),
            .testTarget(
                name: "KawarimiHengeTests",
                dependencies: [
                    "KawarimiHenge",
                    .product(name: "HTTPTypes", package: "swift-http-types"),
                ]
            ),
        ]
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
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit.git", from: "3.9.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: targets
)
