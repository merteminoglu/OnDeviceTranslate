// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OnDeviceTranslate",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "OnDeviceTranslate", targets: ["OnDeviceTranslate"])],
    targets: [
        .target(name: "TranslateCore"),
        .executableTarget(name: "OnDeviceTranslate", dependencies: ["TranslateCore"]),
        .testTarget(name: "TranslateCoreTests", dependencies: ["TranslateCore"])
    ]
)
