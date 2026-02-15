// swift-tools-version: 6.0
// M2DX-Core — DX7 FM Synthesis Engine Library

import PackageDescription

let package = Package(
    name: "M2DXCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "M2DXCore",
            targets: ["M2DXCore"]
        ),
    ],
    targets: [
        .target(
            name: "M2DXCore",
            resources: [
                .copy("Preset/Resources/SysEx"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        .testTarget(
            name: "M2DXCoreTests",
            dependencies: ["M2DXCore"]
        ),
    ]
)
