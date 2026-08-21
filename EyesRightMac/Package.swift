// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyesRightMac",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
            exact: "1.19.2"
        ),
    ],
    targets: [
        .executableTarget(
            name: "EyesRightMac",
            dependencies: [
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
            ],
            path: "Sources/EyesRightMac",
            resources: [
                .copy("Resources/pet_eye_best.onnx"),
                .copy("Resources/IMG_20260819_142559_cutout.png"),
                .copy("Resources/guang_overlay.jpg"),
            ]
        ),
    ]
)
