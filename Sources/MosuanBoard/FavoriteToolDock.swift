import SwiftUI

extension Notification.Name {
    static let mosuanAddFavoritePen = Notification.Name("mosuan.addFavoritePen")
}

enum FavoriteDockPlacement: String, CaseIterable {
    case top
    case leftInside
    case rightInside
    case leftOutside
    case rightOutside

    var isVertical: Bool { self != .top }
}

struct FavoriteToolDock: View {
    let placement: FavoriteDockPlacement
    let presetIDs: [UUID]
    let onSelect: (PenPreset) -> Void
    let onRemove: (UUID) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    private var presets: [PenPreset] {
        presetIDs.compactMap { id in PenPreset.defaults.first { $0.id == id } }
    }

    var body: some View {
        Group {
            if placement.isVertical {
                VStack(spacing: 2) { content }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 5)
            } else {
                HStack(spacing: 2) { content }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { onDragChanged($0.translation) }
                .onEnded { onDragEnded($0.translation) }
        )
    }

    @ViewBuilder private var content: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.green)
            .frame(width: 28, height: 28)

        if !presets.isEmpty {
            Divider()
                .frame(width: placement.isVertical ? 26 : nil,
                       height: placement.isVertical ? nil : 24)
        }

        ForEach(presets) { preset in
            Button { onSelect(preset) } label: {
                Circle()
                    .fill(Color(red: preset.style.color.red,
                                green: preset.style.color.green,
                                blue: preset.style.color.blue))
                    .frame(width: 19, height: 19)
                    .overlay { Circle().stroke(.white.opacity(0.55), lineWidth: 1) }
                    .frame(width: 30, height: 32)
            }
            .buttonStyle(.plain)
            .help(preset.name)
            .contextMenu {
                Button("移出收藏") { onRemove(preset.id) }
            }
        }

        Divider()
            .frame(width: placement.isVertical ? 26 : nil,
                   height: placement.isVertical ? nil : 24)

        Image(systemName: "plus")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.green)
            .frame(width: 28, height: 28)
            .help("拖动收藏笔槽到绿色吸附位置")
    }
}

struct FavoriteDockHost: View {
    @Binding var presetID: UUID
    @Binding var tool: BoardTool

    @State private var favorites: [UUID]
    @State private var placement: FavoriteDockPlacement
    @State private var dragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var highlighted: FavoriteDockPlacement?

    init(presetID: Binding<UUID>, tool: Binding<BoardTool>) {
        _presetID = presetID
        _tool = tool
        let stored = UserDefaults.standard.stringArray(forKey: "mosuan.favoritePenIDs") ?? []
        _favorites = State(initialValue: stored.compactMap(UUID.init(uuidString:)))
        let raw = UserDefaults.standard.string(forKey: "mosuan.favoriteDockPlacement") ?? FavoriteDockPlacement.top.rawValue
        _placement = State(initialValue: FavoriteDockPlacement(rawValue: raw) ?? .top)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if dragging { dropTargets(in: proxy.size) }
                dock(in: proxy.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mosuanAddFavoritePen)) { note in
            guard let id = note.object as? UUID else { return }
            addFavorite(id)
        }
    }

    private func dock(in size: CGSize) -> some View {
        FavoriteToolDock(
            placement: placement,
            presetIDs: favorites,
            onSelect: { preset in
                presetID = preset.id
                tool = .pen
            },
            onRemove: removeFavorite,
            onDragChanged: { translation in
                dragging = true
                dragOffset = translation
                highlighted = nearestPlacement(in: size, translation: translation)
            },
            onDragEnded: { translation in
                let target = nearestPlacement(in: size, translation: translation)
                placement = target
                UserDefaults.standard.set(target.rawValue, forKey: "mosuan.favoriteDockPlacement")
                dragOffset = .zero
                highlighted = nil
                dragging = false
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: placement))
        .padding(edgePadding(for: placement))
        .offset(dragOffset)
        .opacity(favorites.isEmpty ? 0 : 1)
        .allowsHitTesting(!favorites.isEmpty)
    }

    private func alignment(for placement: FavoriteDockPlacement) -> Alignment {
        switch placement {
        case .top: return .top
        case .leftInside, .leftOutside: return .leading
        case .rightInside, .rightOutside: return .trailing
        }
    }

    private func edgePadding(for placement: FavoriteDockPlacement) -> EdgeInsets {
        switch placement {
        case .top: return EdgeInsets(top: 72, leading: 0, bottom: 0, trailing: 0)
        case .leftInside: return EdgeInsets(top: 0, leading: 66, bottom: 0, trailing: 0)
        case .rightInside: return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 66)
        case .leftOutside: return EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0)
        case .rightOutside: return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)
        }
    }

    @ViewBuilder
    private func dropTargets(in size: CGSize) -> some View {
        ForEach(FavoriteDockPlacement.allCases, id: \.rawValue) { target in
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlighted == target ? Color.green.opacity(0.34) : Color.green.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.green.opacity(highlighted == target ? 0.8 : 0.38),
                                lineWidth: highlighted == target ? 2 : 1)
                }
                .frame(width: target.isVertical ? 52 : 270,
                       height: target.isVertical ? 270 : 42)
                .position(targetPoint(target, in: size))
        }
    }

    private func targetPoint(_ target: FavoriteDockPlacement, in size: CGSize) -> CGPoint {
        switch target {
        case .top: return CGPoint(x: size.width / 2, y: 74)
        case .leftInside: return CGPoint(x: 74, y: size.height / 2)
        case .rightInside: return CGPoint(x: size.width - 74, y: size.height / 2)
        case .leftOutside: return CGPoint(x: 25, y: size.height / 2)
        case .rightOutside: return CGPoint(x: size.width - 25, y: size.height / 2)
        }
    }

    private func nearestPlacement(in size: CGSize, translation: CGSize) -> FavoriteDockPlacement {
        let start = targetPoint(placement, in: size)
        let point = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        return FavoriteDockPlacement.allCases.min {
            distance(point, targetPoint($0, in: size)) < distance(point, targetPoint($1, in: size))
        } ?? .top
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func addFavorite(_ id: UUID) {
        guard !favorites.contains(id), PenPreset.defaults.contains(where: { $0.id == id }) else { return }
        favorites.append(id)
        UserDefaults.standard.set(favorites.map(\.uuidString), forKey: "mosuan.favoritePenIDs")
    }

    private func removeFavorite(_ id: UUID) {
        favorites.removeAll { $0 == id }
        UserDefaults.standard.set(favorites.map(\.uuidString), forKey: "mosuan.favoritePenIDs")
    }
}
