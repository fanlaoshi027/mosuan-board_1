# 墨写 · Flutter Path A

这是新的桌面手写软件开发线，采用 Flutter + scribe_canvas，目标平台为 macOS 与 Windows。

## 当前阶段

MVP-01：验证桌面画布、基础笔迹、橡皮、平移、颜色、粗细以及 Undo/Redo。

## 技术路线

- Flutter Desktop
- Dart
- scribe_canvas 0.6.x
- 后续接入 PDF 背景、收藏笔槽、圆盘工具和工程文件

## 开发原则

1. 先把真实书写手感做好，再扩展 PDF。
2. UI 与笔迹核心保持解耦。
3. 小步提交，每个阶段保持可运行。
4. 不加入与讲课书写无关的复杂功能。
