# Mosuan Board 本地构建

## 环境

- macOS 14 或更高版本
- Xcode 16.4（当前开发环境）
- Swift Package Manager
- Apple Silicon Mac 推荐

## 第一次构建

在项目根目录执行：

```bash
chmod +x build-mosuan.sh
./build-mosuan.sh
```

成功后：

```text
Build/
├── Mosuan Board.app
└── Mosuan-Board-0.1.0.dmg
```

双击 DMG，将 `Mosuan Board.app` 拖入“应用程序”即可。

## Gatekeeper

0.1.0 测试版暂未配置 Developer ID 签名和 Apple notarization。第一次打开如果 macOS 阻止启动：

1. 在 Finder 中找到 `Mosuan Board.app`
2. 右键 → 打开
3. 在确认窗口再次选择“打开”

正式公开发布时再加入 Developer ID 签名和 notarization。

## 注意

本项目使用 Swift Package Manager 打包 Metal shader。Metal shader 位于 `Sources/MosuanBoard/Metal/InkShaders.metal`，运行时从 SwiftPM 资源 Bundle 加载。
