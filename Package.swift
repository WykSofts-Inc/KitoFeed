// swift-tools-version: 5.9
//
//  Package.swift
//  KitoFeed
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoFeed",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoFeed", targets: ["KitoFeed"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "KitoFeed", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoFeedTests", dependencies: ["KitoFeed"]),
    ]
)
