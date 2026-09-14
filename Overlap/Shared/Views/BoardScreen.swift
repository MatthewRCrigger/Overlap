#if !os(tvOS)
import SwiftUI


/// Drag-and-drop combining with room to leave items lying around.
///
/// One board, two chromes. iPad and Mac put the tray in a leading sidebar;
/// iPhone rotates that same tray under the board as a shelf, because a phone
/// has no width to spare and the drag must never leave the screen. The board,
/// the gesture, and the coordinate space are identical in both.
struct BoardScreen: View {
    let game: GameState
    @Environment(\.colorScheme) private var scheme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The phone shelf, not the iPad sidebar.
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private var isCompact: Bool { false }
    #endif

    #if os(macOS)
    private let regularPillSize = PillSize.macBoard
    private let traySize = PillSize.macTray
    private let gridSpacing: CGFloat = 32
    private let toolbarHeight: CGFloat = 48
    #else
    private let regularPillSize = PillSize.iPadBoard
    private let traySize = PillSize.iPadTray
    private let gridSpacing: CGFloat = 40
    private let toolbarHeight: CGFloat = 58
    #endif

    /// Board pills are the phone's 44pt touch size in compact.
    private var pillSize: PillSize { isCompact ? .iPhone : regularPillSize }
    private var shelfPillSize: PillSize { isCompact ? .iPhone : traySize }

    @State private var dragging: ItemID?
    @State private var dragLocation: CGPoint = .zero
    @State private var dropTarget: ItemID?
    @State private var showingResetConfirmation = false
    /// The compact header owns this, since the shared run bar is hidden there.
    @State private var showingRuns = false
    /// The board's frame in the shared "stage" space — lets a drag that starts
    /// in the tray hit-test and land on the board with no coordinate seams.
    @State private var boardFrame: CGRect = .zero
    /// Filters the shelf only. The board keeps whatever is parked on it —
    /// a filter that emptied the workspace would lose work.
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .background(Token.surface)
        .sheet(isPresented: $showingRuns) { RunControls(game: game) }
        .confirmationDialog("Start a new run?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("New Run") {
                game.resetProgress()
            }
        } message: {
            Text("Your current run is kept. The new run starts with Water, Fire, Wind, and Earth using the same context.")
        }
    }

    // MARK: - Layouts

    /// iPad / Mac: tray at the leading edge, board filling the rest.
    private var regularLayout: some View {
        VStack(spacing: 0) {
            #if !os(macOS)
            topBar
            #endif
            HStack(spacing: 0) {
                tray
                board
            }
            .coordinateSpace(.named("stage"))
            .overlay(alignment: .topLeading) { draggedPill }
        }
    }

    /// iPhone: header, board, then the shelf under it. The tray edge is
    /// `.bottom` rather than `.leading`, but it is the same tray and the same
    /// named coordinate space, so a drag from shelf to board crosses no seam.
    private var compactLayout: some View {
        VStack(spacing: 0) {
            compactHeader
            // `board` is a GeometryReader, which has no intrinsic height and
            // would otherwise claim the stack and sit over the shelf, eating
            // the shelf's taps. `layoutPriority(1)` on the shelf makes it take
            // the height it asks for first; the board gets the remainder.
            board
            shelf.layoutPriority(1)
        }
        .coordinateSpace(.named("stage"))
        .overlay(alignment: .topLeading) { draggedPill }
    }

    /// The pill riding under the finger. `.position` expands to fill whatever
    /// it is placed in, so the whole overlay — not just the pill inside it —
    /// has to be transparent to hits, or it swallows every tap on the shelf.
    private var draggedPill: some View {
        ZStack {
            if let dragging {
                DraggedPill(
                    emoji: game.emoji(of: dragging),
                    name: game.name(of: dragging),
                    size: pillSize
                )
                .position(dragLocation)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Compact chrome

    /// Title, run identity, and the live counts. The run name rides in the
    /// chrome because a pair means nothing without the context that resolved it.
    private var compactHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Overlap")
                    .font(.display(28))
                    .tracking(-28 * 0.03)
                    .foregroundStyle(Token.ink)
                Text(runLine)
                    .monoMeta(10, color: Token.labelSecondary)
                    .lineLimit(1)
                statusLine
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { game.clearBoard() } label: {
                    Text("Clear")
                        .font(.control(13))
                        .foregroundStyle(canClear ? Token.accent : Token.labelTertiary)
                        .frame(height: 44)
                        .padding(.horizontal, 15)
                        .background(Capsule().fill(Token.grouped.opacity(0.9)))
                        .overlay(Capsule().strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth))
                }
                .disabled(!canClear)

                Menu {
                    Button("Runs and history") { showingRuns = true }
                    Button("Undo last combine") { game.undo() }.disabled(!game.canUndo)
                    Divider()
                    Button("New run") { showingResetConfirmation = true }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Token.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Token.grouped.opacity(0.9)))
                        .overlay(Circle().strokeBorder(Token.hairline, lineWidth: Token.hairlineWidth))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var runLine: String {
        let run = game.activeRun?.name ?? "Run"
        return game.context.isUnset ? run : "\(run) · \(game.context.text)"
    }

    /// Swaps the counts for the working line while a pair is resolving, so the
    /// header carries the state instead of a separate spinner chrome.
    @ViewBuilder
    private var statusLine: some View {
        if case .working = game.phase {
            Text("Looking for the overlap…")
                .monoMeta(10, color: Token.revealAccent)
        } else {
            Text("\(game.collectedCount) collected · \(game.totalUntriedLeads) untried leads")
                .monoMeta(10, color: Token.labelTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canClear: Bool { !game.boardItems.isEmpty }

    // MARK: - Shelf (compact tray)

    /// The iPad tray rotated under the board: grab handle, search, the browse
    /// links the tab bar used to carry, then the pills themselves.
    private var shelf: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Token.labelTertiary.opacity(0.5))
                .frame(width: 36, height: 5)

            shelfControls

            if shelfItems.isEmpty {
                shelfEmptyState
            } else {
                shelfPills
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Token.surface)
        .hairline(.top)
    }

    private var shelfControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Token.labelTertiary)
                TextField("Search \(game.collectedCount) items", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Token.labelTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: Token.Radius.field, style: .continuous)
                    .fill(Token.grouped)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Token.Radius.field, style: .continuous)
                    .strokeBorder(searchFocused ? Token.accent.opacity(0.9) : .clear, lineWidth: 1.5)
            )
            // The row is wider than the text itself; without a shape, taps to
            // the right of the caret fall through to the shelf behind it.
            .contentShape(RoundedRectangle(cornerRadius: Token.Radius.field, style: .continuous))

            // While editing, the browse links give way to Cancel — the shelf
            // is a text field at that moment, and leaving the screen mid-edit
            // is never what the player means.
            if searchFocused {
                Button {
                    query = ""
                    searchFocused = false
                } label: {
                    Text("Cancel").font(.control(12.5)).foregroundStyle(Token.accent)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { CollectionScreen(game: game) } label: {
                    Text("Collection").font(.control(12.5)).foregroundStyle(Token.accent)
                }
                Rectangle()
                    .fill(Token.hairline)
                    .frame(width: Token.hairlineWidth, height: 14)
                NavigationLink { ChainsScreen(game: game) } label: {
                    Text("Chains")
                        .font(.control(12.5))
                        .foregroundStyle(canChain ? Token.accent : Token.labelTertiary)
                }
                .disabled(!canChain)
            }
        }
    }

    /// Chains needs at least one combine before it has anything to show.
    private var canChain: Bool { game.collectedCount > game.engine.baseItems.count }

    private var shelfPills: some View {
        ScrollView {
            // Wrapping rows, lazy because the collection runs to thousands.
            FlowLayout(spacing: 8) {
                ForEach(shelfItems, id: \.self) { id in
                    pill(id, size: shelfPillSize, isOnBoard: false)
                }
            }
            .padding(.bottom, 4)
        }
        .frame(height: shelfHeight)
        .scrollIndicators(.hidden)
        // A partial row at the cut signals there is more below.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    /// Three rows of 44pt pills plus their gaps.
    private var shelfHeight: CGFloat { 174 }

    private var shelfEmptyState: some View {
        Text("Nothing in this run matches “\(query)”.")
            .font(.system(size: 13.5))
            .foregroundStyle(Token.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: shelfHeight, alignment: .top)
            .padding(.top, 10)
    }

    /// Search narrows the shelf only — never the board.
    private var shelfItems: [ItemID] {
        let all = game.trayOrder
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return all }
        return all.filter { game.name(of: $0).localizedCaseInsensitiveContains(term) }
    }

    /// The empty board carries the only instruction the app needs.
    private var boardEmptyState: some View {
        VStack(spacing: 12) {
            Circle()
                .strokeBorder(
                    Token.labelTertiary.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Token.labelTertiary)
                )
            Text("Drag two things up here")
                .font(.control(17))
                .foregroundStyle(Token.ink)
            Text(emptyBoardSubtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(Token.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 48)
        .allowsHitTesting(false)
    }

    /// Named after the run's context, so the instruction says who is deciding.
    /// With no context set there is no one to name, so the sentence drops it
    /// rather than printing the sentinel.
    private var emptyBoardSubtitle: String {
        guard !game.context.isUnset else {
            return "Drop one on top of another to see what they have in common."
        }
        return "Drop one on top of another and \(game.context.text) decides what they have in common."
    }

    /// The one full-width alert in the design: a run-level condition, not a
    /// pair-level one, so it sits on the board rather than in a toast.
    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Token.warning)
            Text("No connection. Pairs you've already resolved still work; new ones queue until you're back.")
                .font(.system(size: 12.5))
                .foregroundStyle(Token.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Token.warning.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Token.warning.opacity(0.5), lineWidth: Token.hairlineWidth)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    /// The in-place spinner: it sits at the midpoint where the result will
    /// land, so the player's eye is already in the right place.
    private func workingIndicator(_ pair: PairKey) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Token.revealAccent)
            Text(workingLabel(pair))
                .font(.control(13.5))
                .foregroundStyle(Token.revealAccent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Token.revealAccent.opacity(0.1)))
        .overlay(Capsule().strokeBorder(Token.revealAccent.opacity(0.3), lineWidth: 1))
        .allowsHitTesting(false)
    }

    private func workingLabel(_ pair: PairKey) -> String {
        let inputs = ComboEngine.parseInputs(of: pair)
        guard inputs.count == 2 else { return "Looking for the overlap…" }
        return "\(game.name(of: inputs[0])) + \(game.name(of: inputs[1]))"
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


                // The empty board is the tutorial: no overlay, no coach marks,
                // just the instruction where the work will happen.
                if game.boardItems.isEmpty, dragging == nil, isCompact {
                    boardEmptyState.position(center(geo))
                }

                // The fetch is in place — the spinner sits at the midpoint the
                // result will land on, while the rest of the board stays live.
                if case .working(let pair) = game.phase, isCompact {
                    workingIndicator(pair).position(workingPoint(pair, in: geo))
                }

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
            .overlay(alignment: .bottom) {
                if isCompact {
                    if game.isOffline { offlineBanner }
                } else {
                    floatingToolbar
                }
            }
            .animation(Token.revealCurve, value: game.phase)
        }
        // The board is a GeometryReader with a full-bleed contentShape. Without
        // clipping, parked pills and that shape spill past the board's visual
        // bounds and sit over the shelf, swallowing its taps.
        .clipped()
    }

    /// The spinner lands where the result will: the midpoint of the two inputs
    /// if both are still on the board, otherwise whichever one is.
    private func workingPoint(_ pair: PairKey, in geo: GeometryProxy) -> CGPoint {
        let inputs = ComboEngine.parseInputs(of: pair)
        let points = inputs.compactMap { game.boardItems[$0] }
        guard let first = points.first else { return center(geo) }
        guard points.count == 2 else { return first }
        return CGPoint(x: (first.x + points[1].x) / 2, y: (first.y + points[1].y) / 2)
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
                Text("New run").font(.control(13.5))
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
        let width = dropTarget.map(pillWidth(of:)) ?? 140
        return CGSize(width: width + 26, height: pillSize.height + 22)
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
    ///
    /// Board pills lift immediately. Shelf pills wait for 8pt of travel, so a
    /// vertical flick still scrolls the shelf instead of tearing a pill out of
    /// it — the one place the two sources need to behave differently.
    private func dragGesture(_ id: ItemID, isOnBoard: Bool) -> some Gesture {
        DragGesture(minimumDistance: isOnBoard ? 0 : 8, coordinateSpace: .named("stage"))
            .onChanged { value in
                guard game.acceptsInput else { return }
                if dragging != id {
                    dragging = id
                    liftFeedback()
                }
                dragLocation = value.location
                let target = hitTest(toBoard(value.location), preferringOtherThan: id)
                if target != dropTarget {
                    dropTarget = target
                    if target != nil { targetFeedback() }
                }
            }
            .onEnded { value in
                defer { dragging = nil; dropTarget = nil }
                guard game.acceptsInput, dragging == id else { return }
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

    /// Soft on lift, rigid on target enter. iOS only — the Mac has no haptics
    /// on a trackpad drag of this kind, and tvOS has no board.
    private func liftFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func targetFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }

    /// Stage coordinates → board-local coordinates (what `boardItems` stores).
    private func toBoard(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - boardFrame.minX, y: point.y - boardFrame.minY)
    }

    /// Hit-testing is generous — target radius exceeds the pill's bounds by ~12pt.
    /// Other pills take precedence, but the dragged pill remains a valid
    /// fallback target so an item can be combined with itself (Fire + Fire).
    private func hitTest(_ point: CGPoint, preferringOtherThan id: ItemID) -> ItemID? {
        let slop: CGFloat = 12
        let matches = game.boardItems.compactMap { entry -> ItemID? in
            let width = pillWidth(of: entry.key)
            let frame = CGRect(
                x: entry.value.x - width / 2 - slop,
                y: entry.value.y - pillSize.height / 2 - slop,
                width: width + slop * 2,
                height: pillSize.height + slop * 2
            )
            return frame.contains(point) ? entry.key : nil
        }
        return matches.first(where: { $0 != id }) ?? matches.first(where: { $0 == id })
    }

    /// Pills are sized by their label, so the target has to be too — a fixed
    /// width would under-cover long names and over-cover short ones.
    private func pillWidth(of id: ItemID) -> CGFloat {
        ItemPill.width(emoji: game.emoji(of: id), name: game.name(of: id), size: pillSize)
    }


    // MARK: - Toolbar

}

#endif
