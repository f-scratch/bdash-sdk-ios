// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BDashSDK",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Core / UIKit / SwiftUI ラッパーを統合した単一 SDK。
        // SwiftUI 対応は UIKit 実装を Representable で薄く包む方式のため、
        // SwiftUI を独立ターゲットに分けず BDashSDK 内に同居させている。
        .library(name: "BDashSDK", targets: ["BDashSDK"]),
        .library(name: "BDashNotificationServiceExtension", targets: ["BDashNotificationServiceExtension"]),
    ],
    targets: [
        .target(
            name: "BDashSDK",
            path: "Sources/BDashSDK",
            exclude: [
                "WebReception/WebReceptionViewController.swift",
                "WebReception/ReportDataInputCell.swift",
            ],
            resources: [
                .process("Resources/BDashMobileSDK.xcdatamodeld"),
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        // App Extension。SDK 本体のコードには依存せず自己完結（リッチプッシュの画像DL）。
        .target(
            name: "BDashNotificationServiceExtension",
            path: "Sources/BDashNotificationServiceExtension",
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
            ]
        ),
    ],
)
