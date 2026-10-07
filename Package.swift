// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tomales",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Tomales", targets: ["Tomales"])],
    targets: [
        .target(
            name: "SystemProbe",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Tomales",
            dependencies: ["SystemProbe"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("IOKit")]
        )
    ]
)

