// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GrooveKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "GrooveKit", targets: ["GrooveKit"])],
    targets: [
        .target(name: "GrooveKit"),
        .testTarget(name: "GrooveKitTests", dependencies: ["GrooveKit"]),
    ]
)
