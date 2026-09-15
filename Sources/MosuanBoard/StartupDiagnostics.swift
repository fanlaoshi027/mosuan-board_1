import AppKit
import Metal

@MainActor
final class MosuanStartupDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fail("系统没有可用的 Metal 图形设备。")
            return
        }
        guard device.makeCommandQueue() != nil else {
            fail("Metal Command Queue 创建失败。")
            return
        }
        guard let resourceBundle = MosuanResourceBundle.bundle else {
            fail("Metal Shader 资源包未找到。请确认安装包包含 MosuanBoard_MosuanBoard.bundle。")
            return
        }
        guard let library = try? device.makeDefaultLibrary(bundle: resourceBundle) else {
            fail("Metal Shader 资源加载失败。请确认安装包包含 default.metallib。")
            return
        }
        guard let vertex = library.makeFunction(name: "inkVertex") else {
            fail("Metal Shader 缺少 inkVertex 函数。")
            return
        }
        guard let fragment = library.makeFunction(name: "inkFragment") else {
            fail("Metal Shader 缺少 inkFragment 函数。")
            return
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            _ = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fail("Metal Render Pipeline 创建失败：\n\(error.localizedDescription)")
        }
    }

    private func fail(_ reason: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "墨算无法启动"
        alert.informativeText = reason + "\n\n版本：0.1.4\n建议重新下载最新安装包。"
        alert.addButton(withTitle: "退出")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
