// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MosuanBoard",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MosuanBoard", targets: ["MosuanBoard"])],
    targets: [
        .executableTarget(
            name: "MosuanBoard",
            path: "Sources/MosuanBoard",
            exclude: [
                "BoardScreen.swift",
                "BoardScreenFixed.swift",
                "BoardScreenV2.swift",
                "PDFTeachingWorkspace.swift",
                "Metal/InkRendererFixed.swift",
                "Core/GraphicObjectStoreFixed.swift",
                "Core/GraphicObjectStoreV2.swift",
                "Core/GraphicObjectStoreV3.swift",
                "Platform/iPadOS",
                "SMART_LINE_AND_ERASER.md"
            ],
            resources: [.process("Metal/InkShaders.metal")]
        )
    ]
)
