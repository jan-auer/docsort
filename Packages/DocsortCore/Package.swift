// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "DocsortCore",
  platforms: [.macOS(.v27)],
  products: [
    .library(name: "DocsortCore", targets: ["DocsortCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/ordo-one/FuzzyMatch.git", exact: "1.4.0")
  ],
  targets: [
    .target(
      name: "DocsortCore",
      dependencies: [.product(name: "FuzzyMatch", package: "FuzzyMatch")]),
    .testTarget(
      name: "DocsortCoreTests", dependencies: ["DocsortCore"],
      resources: [.copy("Destinations/Fixtures/destination-corpus.txt")]),
  ]
)
