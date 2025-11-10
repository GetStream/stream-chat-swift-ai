// swift-tools-version:5.9

import Foundation
import PackageDescription

let package = Package(
    name: "StreamChatAI",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "StreamChatAI",
            targets: ["StreamChatAI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Splash.git", exact: "0.16.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", exact: "2.4.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.10.2")
    ],
    targets: [
        .target(
            name: "StreamChatAI",
            dependencies: [
                .product(name: "Splash", package: "Splash"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        )
    ]
)
