// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "sborders",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "sborders", targets: ["Sborders"])],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
    .package(url: "https://github.com/starkwm/stark-configuration", from: "0.0.1"),
    .package(url: "https://github.com/starkwm/stark-ipc", from: "0.0.1"),
  ],
  targets: [
    .executableTarget(
      name: "Sborders",
      dependencies: [
        "SbordersCore", .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      exclude: ["Version.swift.tmpl"]
    ),
    .target(
      name: "SbordersCore",
      dependencies: [
        .product(name: "StarkConfiguration", package: "stark-configuration"),
        .product(name: "StarkIPC", package: "stark-ipc"),
      ]
    ),
    .testTarget(name: "SbordersTests", dependencies: ["Sborders"]),
    .testTarget(name: "SbordersCoreTests", dependencies: ["SbordersCore"]),
  ],
  swiftLanguageModes: [.v6]
)
