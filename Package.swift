// swift-tools-version: 5.9
// iOS Demo App for DropOnAir SDK
// Open this directory in Xcode: File → Open → select droponair-demo-ios/

import PackageDescription

let package = Package(
    name: "DropOnAirDemo",
    platforms: [.iOS(.v16), .macOS(.v13)],
    dependencies: [
        // DropOnAir SDK. Latest release: https://github.com/DropOnAir/droponair-sdk-ios-binary/releases
        .package(url: "https://github.com/DropOnAir/droponair-sdk-ios-binary.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "DropOnAirDemo",
            dependencies: [
                .product(name: "DropOnAirSDK", package: "droponair-sdk-ios-binary"),
            ],
            path: "Sources/DropOnAirDemo"
        ),
    ]
)
