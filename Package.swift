// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
/// _
///
///
///
///
///                              ____
///                              \   \
///                               \   \
///                          /\    \   \
///                         /  \    \   \
///                         \   \    \   \
///                          \   \    \   \
///                      /\   \   \    \   \
///                     /  \   \   \    \   \
///                    /   /    \   \    \   \
///                   /   /      \   \    \   \
///                  /   /        \   \    \   \
///                 /   /          \   \    \   \
///                /   /            \   \    \   \
///               /   /              \   \    \   \
///              /   /                \   \    \   \
///             /   /                  \   \    \   \
///            /   /_________________   \   \    \   \
///           /                      \   \   \    \   \
///          /________________________\   \___\    \___\
///         ___      _____     _              _ _  __
///        /_\ \    / / __|   /_\  _ __  _ __| (_)/ _|_  _
///       / _ \ \/\/ /\__ \  / _ \| '  \| '_ \ | |  _| || |
///      /_/ \_\_/\_/ |___/ /_/ \_\_|_|_| .__/_|_|_|  \_, |
///                                     |_|           |__/
let package = Package(
    name: "AmplifyUI",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Primitives",
            targets: ["Primitives"]
         )
    ],
    targets: [
        .target(
            name: "Primitives"
        )
    ]
)
