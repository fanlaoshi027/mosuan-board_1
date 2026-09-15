import SwiftUI

struct BoardLayerView: View {
    @ObservedObject var store: BoardLayerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("图层").font(.headline)
                Spacer()
                Button { store.addLayer() } label: { Image(systemName: "plus") }.help("新增图层")
                Button { store.deleteCurrentLayer() } label: { Image(systemName: "trash") }.help("删除当前图层")
            }.padding(10)
            Divider()
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.note.layers.reversed()) { layer in
                        HStack(spacing: 8) {
                            Button { store.toggleVisibility(layer.id) } label: { Image(systemName: layer.isVisible ? "eye" : "eye.slash") }.buttonStyle(.plain).help(layer.isVisible ? "隐藏图层" : "显示图层")
                            Button { store.toggleLock(layer.id) } label: { Image(systemName: layer.isLocked ? "lock.fill" : "lock.open") }.buttonStyle(.plain).help(layer.isLocked ? "解锁图层" : "锁定图层")
                            Image(systemName: layer.isBase ? "doc.richtext" : "square.3.layers.3d")
                                .foregroundStyle(layer.isBase ? .secondary : .primary)
                            Text(layer.name).lineLimit(1)
                            Spacer()
                            if layer.id == store.note.currentLayerID { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectLayer(layer.id) }
                    }
                }.padding(.vertical, 6)
            }
        }
        .frame(width: 230, height: 320)
    }
}
