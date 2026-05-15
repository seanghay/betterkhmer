// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BetterKhmer",
    products: [.library(name: "BetterKhmer", targets: ["BetterKhmer"])],
    targets: [
        .target(name: "BetterKhmer", path: "Sources/BetterKhmer"),
        .testTarget(name: "BetterKhmerTests", dependencies: ["BetterKhmer"], path: "Tests/BetterKhmerTests"),
    ]
)
