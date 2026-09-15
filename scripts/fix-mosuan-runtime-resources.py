from pathlib import Path

renderer = Path("Sources/MosuanBoard/Metal/InkRenderer.swift")
text = renderer.read_text()
old = "guard let queue = device.makeCommandQueue(), let library = try? device.makeDefaultLibrary(bundle: Bundle.module), let vf = library.makeFunction(name: \"inkVertex\"), let ff = library.makeFunction(name: \"inkFragment\") else { return nil }"
new = "guard let queue = device.makeCommandQueue(), let resourceBundle = MosuanResourceBundle.bundle, let library = try? device.makeDefaultLibrary(bundle: resourceBundle), let vf = library.makeFunction(name: \"inkVertex\"), let ff = library.makeFunction(name: \"inkFragment\") else { return nil }"
if old in text:
    renderer.write_text(text.replace(old, new, 1))
elif "MosuanResourceBundle.bundle" not in text:
    raise SystemExit("InkRenderer Metal resource lookup is neither old nor fixed")
