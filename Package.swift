// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PicPress",
    platforms: [.macOS(.v14)],
    dependencies: [
        // WebP-Encoder — ImageIO kann WebP nur dekodieren, nicht encodieren.
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "PicPress",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode")
            ],
            path: "Sources/PicPress"
        )
    ]
)
