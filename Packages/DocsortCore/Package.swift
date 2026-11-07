// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "DocsortCore",
  platforms: [.macOS(.v27)],
  products: [
    .library(name: "DocsortCore", targets: ["DocsortCore"])
  ],
  targets: [
    .target(name: "DocsortCore"),
    .testTarget(name: "DocsortCoreTests", dependencies: ["DocsortCore"]),
  ]
)
