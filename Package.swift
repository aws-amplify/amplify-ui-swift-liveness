// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "AmazonFaceLiveness",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "XFaceLiveness",
            targets: ["XFaceLiveness"]
        ),
        .library(
            name: "FaceLivenessCore",
            targets: ["FaceLivenessCore"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/aws-amplify/amplify-swift.git",
            from: "2.35.0"
        ),
    ],
    targets: [
        // X custom UI layer
        .target(
            name: "XFaceLiveness",
            dependencies: [
                "FaceLivenessCore",
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSPredictionsPlugin", package: "amplify-swift"),
            ]
        ),
        // Upstream amplify-ui-swift-liveness source (vendored for customization)
        .target(
            name: "FaceLivenessCore",
            dependencies: [
                .product(name: "AWSPluginsCore", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSPredictionsPlugin", package: "amplify-swift"),
            ],
            resources: [
                .process("Resources/Base.lproj"),
                .copy("Resources/face_detection_short_range.mlmodelc"),
            ]
        ),
    ]
)
