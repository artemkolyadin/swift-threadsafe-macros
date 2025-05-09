// swift-tools-version:6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-threadsafe-macros",
    platforms: [.macOS(.v14), .iOS(.v14)],
    products: [
        .library(name: "ThreadSafeMacros", targets: ["ThreadSafeMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "600.0.1"),
    ],
    targets: [
        .macro(
            name: "ThreadSafeMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "ThreadSafeMacros", dependencies: ["ThreadSafeMacrosImpl"]),
        .testTarget(
            name: "ThreadSafeMacrosTests",
            dependencies: [
                "ThreadSafeMacrosImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
