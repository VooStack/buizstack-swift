// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BuizStack",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "BuizStack", targets: ["BuizStack"])
    ],
    targets: [
        .target(name: "BuizStack", resources: [.process("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "BuizStackTests", dependencies: ["BuizStack"]),
    ]
)
