import SwiftUI

/// Compact inspector for the most common teaching control: a dynamic numeric parameter.
/// The panel is deliberately model-agnostic so it can be reused by macOS and iPadOS.
struct DynamicGeometryParameterPanel: View {
    @Binding var parameter: GeometryParameter
    @Binding var isPlaying: Bool
    var valueSuffix: String = ""
    var onValueChanged: (() -> Void)?
    var onPlayChanged: ((Bool) -> Void)?

    @State private var valueText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(parameter.name)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(parameter.value) },
                    set: { newValue in
                        parameter.setValue(CGFloat(newValue))
                        valueText = numericText(parameter.value)
                        onValueChanged?()
                    }
                ),
                in: Double(parameter.minimum)...Double(parameter.maximum),
                step: max(0.0001, Double(parameter.step))
            )

            HStack {
                Text(numericText(parameter.minimum) + valueSuffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(numericText(parameter.maximum) + valueSuffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("数值", text: $valueText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onSubmit { commitTextValue() }

                Button {
                    commitTextValue()
                } label: {
                    Text("应用")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    isPlaying.toggle()
                    onPlayChanged?(isPlaying)
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!parameter.isAnimatable)

                Menu {
                    Picker("循环", selection: Binding(
                        get: { parameter.animationLoop },
                        set: { parameter.animationLoop = $0 }
                    )) {
                        Text("往返").tag(GeometryParameterLoop.pingPong)
                        Text("重新开始").tag(GeometryParameterLoop.restart)
                    }
                } label: {
                    Image(systemName: "repeat")
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
            }

            HStack {
                Text("步长")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(numericText(parameter.step) + valueSuffix)
                    .monospacedDigit()
            }
            .font(.caption)
        }
        .padding(14)
        .frame(minWidth: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .onAppear {
            valueText = numericText(parameter.value)
        }
        .onChange(of: parameter.value) { _, newValue in
            valueText = numericText(newValue)
        }
    }

    private var displayValue: String {
        numericText(parameter.value) + valueSuffix
    }

    private func commitTextValue() {
        guard let value = Double(valueText) else {
            valueText = numericText(parameter.value)
            return
        }
        parameter.setValue(CGFloat(value))
        valueText = numericText(parameter.value)
        onValueChanged?()
    }

    private func numericText(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded.rounded() - rounded) < 0.0001 {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.2f", Double(rounded))
    }
}
