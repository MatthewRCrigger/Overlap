#if !os(tvOS)
import SwiftUI


/// Drag-and-drop combining with room to leave items lying around.
/// Shared by iPad and Mac; only the chrome around it differs.
struct BoardScreen: View {
    let game: GameState
    @Environment(\.colorScheme) private var scheme

    #if os(macOS)
    private let pillSize = PillSize.macBoard
    private let traySize = PillSize.macTray
    private let gridSpacing: CGFloat = 32
    private let toolbarHeight: CGFloat = 48
    #else
    private let pillSize = PillSize.iPadBoard
    private let traySize = PillSize.iPadTray
    private let gridSpacing: CGFloat = 40
    private let toolbarHeight: CGFloat = 58
    #endif

    @State private var dragging: ItemID?
    @State private var dragLocation: CGPoint = .zero
    @State private var dropTarget: ItemID?
    @State private var showingResetConfirmation = false
    /// The board's frame in the shared "stage" space — lets a drag that starts
    /// in the tray hit-test and land on the board with no coordinate seams.
    @State private var boardFrame: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            #if !os(macOS)
            topBar
            #endif
            HStack(spacing: 0) {
                tray
                board
            }
            // One coordinate space over tray + board, so the dragged pill rides
            // under the finger continuously from sidebar to grid.
            .coordinateSpace(.named("stage"))
            .overlay(alignment: .topLeading) {
                if let dragging {
                    DraggedPill(
                        emoji: game.emoji(of: dragging),
                        name: game.name(of: dragging),
                        size: pillSize
                    )
                    .position(dragLocation)
                    .allowsHitTesting(false)
                }
            }
        }
        .background(Token.surface)
        .confirmationDialog("Reset your game?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                game.resetProgress()
            }
        } message: {
            Text("This permanently removes every discovery and attempted combination. You’ll start again with Water, Fire, Wind, and Earth.")
        }
    }

    // MARK: - Tray

    private var tray: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tray").monoMeta(10)
            ScrollView {
                // Wrapping pills; lazy because the collection runs to thousands.
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(game.trayOrder, id: \.self) { id in
                        pill(id, size: traySize, isOnBoard: false)
                    }
                }
            }
            .scrollIndicators(.hidden)

            explainer
        }
        .padding(14)
        #if os(macOS)
        .frame(width: 214)
        .background(Token.sidebar)
        #else
        .frame(width: 250)
        #endif
        .hairline(.trailing)
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Drag one onto another")
                .font(.control(13))
                .foregroundStyle(Token.ink)
            Text("Drop on empty space to park it.")
                .font(.system(size: 12))
                .foregroundStyle(Token.labelSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous).fill(Token.grouped)
        )
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                dotGrid

                ForEach(Array(game.boardItems.keys), id: \.self) { id in
                    let point = game.boardItems[id] ?? .zero
                    // Halo under the drop target — chip onto chip, no merge.
                    if dropTarget == id { dropBloom.position(point) }
                    pill(id, size: pillSize, isOnBoard: true)
                        .position(point)
                }

                if case .deadEnd = game.phase { deadEndToast.position(center(geo)) }

                // A match reads in place: the result pill has already landed on
                // the board above, and this names it. No takeover, no merge —
                // the player never leaves the board.
                if case .reveal(let reveal) = game.phase {
                    MatchToast(game: game, reveal: reveal)
                        .position(matchToastPoint(reveal, in: geo))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("stage"))
            } action: { frame in
                boardFrame = frame
            }
            .overlay(alignment: .bottom) { floatingToolbar }
            .animation(Token.revealCurve, value: game.phase)
        }
    }

    /// The toast sits just above the pill that just landed, clamped inside the
    /// board so a combine near an edge can't push it off-screen.
    private func matchToastPoint(_ reveal: Reveal, in geo: GeometryProxy) -> CGPoint {
        guard let landed = game.boardItems[reveal.result] else { return center(geo) }
        let halfWidth: CGFloat = 172
        let halfHeight: CGFloat = 106
        return CGPoint(
            x: min(max(landed.x, halfWidth), max(halfWidth, geo.size.width - halfWidth)),
            y: min(max(landed.y - halfHeight - 30, halfHeight), max(halfHeight, geo.size.height - halfHeight))
        )
    }

    /// 76px top bar: wordmark, counts, and the browse entry points.
    private var topBar: some View {
        HStack(spacing: 16) {
            Text("Overlap")
                .font(.display(22))
                .tracking(-22 * 0.03)
                .foregroundStyle(Token.ink)
            Text("\(game.collectedCount) collected · \(game.totalUntriedLeads) untried leads")
                .monoMeta(10, color: Token.labelSecondary)
            Spacer()
            NavigationLink { CollectionScreen(game: game) } label: {
                Text("Collection").font(.control(13.5)).foregroundStyle(Token.accent)
            }
            NavigationLink { ChainsScreen(game: game) } label: {
                Text("Chains").font(.control(13.5)).foregroundStyle(Token.accent)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .hairline(.bottom)
    }

    /// Floating glass toolbar: clear, the two most recent items, and undo.
    private var floatingToolbar: some View {
        HStack(spacing: 14) {
            Button {
                game.clearBoard()
            } label: {
                Text("Clear board").font(.control(13.5)).foregroundStyle(Token.accent)
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Text("Reset game").font(.control(13.5))
            }

            Rectangle().fill(Token.hairline).frame(width: Token.hairlineWidth, height: 22)

            ForEach(game.collectionNewestFirst.prefix(2), id: \.self) { id in
                ItemPill(emoji: game.emoji(of: id),
                         name: game.name(of: id),
                         size: .inline)
            }

            Rectangle().fill(Token.hairline).frame(width: Token.hairlineWidth, height: 22)

            Button { game.undo() } label: {
                Text("Undo ⌘Z").monoMeta(10, color: game.canUndo ? Token.accent : Token.labelTertiary)
            }
            .disabled(!game.canUndo)
            .keyboardShortcut("z", modifiers: .command)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .frame(height: toolbarHeight)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth))
        .shadow(color: .black.opacity(0.09), radius: 3, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 17, y: 12)
        .padding(.bottom, 22)
    }

    private func center(_ geo: GeometryProxy) -> CGPoint {
        CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
    }

    private var dotGrid: some View {
        Canvas { context, size in
            let dot = Token.boardDot
            var y: CGFloat = 20
            while y < size.height {
                var x: CGFloat = 20
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(dot))
                    x += gridSpacing
                }
                y += gridSpacing
            }
        }
        .allowsHitTesting(false)
    }

    /// Drop target highlight. Deliberately not a Venn: the board is a
    /// drag-chips-onto-chips surface, and the merging-circles treatment both
    /// misdescribed the interaction and implied a takeover that no longer
    /// happens. A halo around the target pill is the whole affordance.
    private var dropBloom: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Token.revealAccent.opacity(scheme == .dark ? 0.24 : 0.12))
                .frame(width: dropHaloSize.width, height: dropHaloSize.height)
            Capsule(style: .continuous)
                .strokeBorder(Token.revealAccent.opacity(0.55), lineWidth: 1.5)
                .frame(width: dropHaloSize.width, height: dropHaloSize.height)
            Text("Release to combine")
                .monoMeta(9.5, tracking: 0.13, color: Token.revealAccent)
                .offset(y: dropHaloSize.height / 2 + 12)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// Sized to wrap the target pill with a little breathing room.
    private var dropHaloSize: CGSize {
        CGSize(width: 140 + 26, height: pillSize.height + 22)
    }

    // MARK: - Pills & dragging

    private func pill(_ id: ItemID, size: PillSize, isOnBoard: Bool) -> some View {
        ItemPill(
            emoji: game.emoji(of: id),
            name: game.name(of: id),
            size: size,
            style: .normal,
            isDragSource: dragging == id
        )
        .gesture(dragGesture(id, isOnBoard: isOnBoard))
    }

    /// One gesture for tray and board pills alike, in the shared "stage" space,
    /// so a drag begun in the sidebar carries straight over the grid.
    private func dragGesture(_ id: ItemID, isOnBoard: Bool) -> some Gesture {
        DragGesture(coordinateSpace: .named("stage"))
            .onChanged { value in
                guard game.acceptsInput else { return }
                dragging = id
                dragLocation = value.location
                dropTarget = hitTest(toBoard(value.location), preferringOtherThan: id)
            }
            .onEnded { value in
                defer { dragging = nil; dropTarget = nil }
                guard game.acceptsInput else { return }
                let point = toBoard(value.location)
                if let target = hitTest(point, preferringOtherThan: id) {
                    game.combine(target, id)
                } else if boardFrame.contains(value.location) {
                    // Drop on empty board space parks the item there.
                    game.park(id, at: point)
                }
                // A drop back over the tray is a no-op: a tray pill snaps home,
                // a board pill stays where it was.
            }
    }

    /// Stage coordinates → board-local coordinates (what `boardItems` stores).
    private func toBoard(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - boardFrame.minX, y: point.y - boardFrame.minY)
    }

    /// Hit-testing is generous — target radius exceeds the pill's bounds by ~12pt.
    /// Other pills take precedence, but the dragged pill remains a valid
    /// fallback target so an item can be combined with itself.
    private func hitTest(_ point: CGPoint, preferringOtherThan id: ItemID) -> ItemID? {
        let slop: CGFloat = 12
        let matches = game.boardItems.compactMap { entry -> ItemID? in
            let frame = CGRect(
                x: entry.value.x - 70 - slop,
                y: entry.value.y - pillSize.height / 2 - slop,
                width: 140 + slop * 2,
                height: pillSize.height + slop * 2
            )
            return frame.contains(point) ? entry.key : nil
        }
        return matches.first(where: { $0 != id }) ?? matches.first(where: { $0 == id })
    }

    @ViewBuilder
    private var deadEndToast: some View {
        VStack(spacing: 5) {
            Text("Nothing in common.")
                .font(.control(15))
                .foregroundStyle(Token.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
    }

    // MARK: - Toolbar

}

#endif
