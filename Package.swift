// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AmplifyUILiveness",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "FaceLiveness",
            targets: ["FaceLiveness"]),
    ],
    dependencies: [
        .package(url: "https://github.com/aws-amplify/amplify-swift-staging", branch: "liveness.main")
    ],
    targets: [
        .target(
            name: "FaceLiveness",
            dependencies: [
                .product(name: "AWSPluginsCore", package: "amplify-swift-staging"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift-staging"),
                .product(name: "AWSPredictionsPlugin", package: "amplify-swift-staging")
            ],
            resources: [
                .process("Resources/Base.lproj")
            ]
        ),
        .testTarget(
            name: "FaceLivenessTests",
            dependencies: ["FaceLiveness"]),
    ]
)
