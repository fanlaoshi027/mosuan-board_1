import SwiftUI

struct DynamicIsoscelesTriangleParameterPanel: View {
    @Binding var degrees: Double
    @Binding var legLength: Double
    var onValueChanged: (() -> Void)?
    var onParameterEditingChanged: ((Bool) -> Void)?
    var onPlaybackChanged: ((Bool) -> Void)?

    @State private var isPlaying = false
    @State private var isEditingParameter = false
    private let presets: [Int] = [30, 45, 60, 90, 120, 150]

    private var apexAngle: Int { Int(degrees.rounded()) }
    private var baseAngle: Int { Int(((180 - degrees) / 2).rounded()) }
    private var roundedLegLength: Int { Int(legLength.rounded()) }
    private var baseLength: Int {
        Int((2 * legLength * sin(degrees * .pi / 360)).rounded())
    }

    private func setAngle(_ value: Double) {
        if isPlaying { isPlaying = false; onPlaybackChanged?(false) }
        degrees = value
        onValueChanged?()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("等腰三角形")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("∠A = \(apexAngle)°")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }

            Slider(value: $degrees, in: 30...150, step: 1) {
                Text("顶角")
            } onEditingChanged: { editing in
                isEditingParameter = editing
                onParameterEditingChanged?(editing)
                if !editing { onValueChanged?() }
            }
            .disabled(isPlaying)

            HStack {
                Text("30°").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("150°").font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 5) {
                ForEach(presets, id: \.self) { value in
                    Button("\(value)°") { setAngle(Double(value)) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(apexAngle == value ? .accentColor : nil)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("边长")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("AB = AC = \(roundedLegLength)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                Slider(value: $legLength, in: 50...300, step: 1) {
                    Text("等腰边长")
                } onEditingChanged: { editing in
                    isEditingParameter = editing
                    onParameterEditingChanged?(editing)
                    if !editing { onValueChanged?() }
                }
                .disabled(isPlaying)
                HStack {
                    Text("50").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("300").font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Text("∠B = ∠C = \(baseAngle)°")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text("BC = \(baseLength)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Button {
                    let next = !isPlaying
                    onPlaybackChanged?(next)
                    isPlaying = next
                } label: {
                    Label(isPlaying ? "暂停" : "播放", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button("回到 60°") { setAngle(60) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(minWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .onDisappear {
            if isEditingParameter {
                isEditingParameter = false
                onParameterEditingChanged?(false)
            }
            if isPlaying {
                isPlaying = false
                onPlaybackChanged?(false)
            }
        }
    }
}
