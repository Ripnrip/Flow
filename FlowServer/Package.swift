// swift-tools-version: 6.2
// The swift-tools-version declares the minimum Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlowServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FlowServer", targets: ["FlowServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.10.0"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.54.0"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.26.0")
    ],
    targets: [
        .executableTarget(
            name: "FlowServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Supabase", package: "supabase-swift")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
