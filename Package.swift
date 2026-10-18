// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudePulse",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/PhilRoli/menubar-kit", from: "1.3.0")],
    targets: [
        .executableTarget(
            name: "ClaudePulse",
            dependencies: [.product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Sources/ClaudePulse"
        ),
        .testTarget(
            name: "ClaudePulseTests",
            dependencies: ["ClaudePulse", .product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Tests/ClaudePulseTests"
        )
    ]
)
