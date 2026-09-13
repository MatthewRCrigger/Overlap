import SwiftUI

/// Browse everything you own; find the thing you forgot you had.
struct CollectionScreen: View {
    let game: GameState

    @State private var query = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case untried = "Untried leads"
        case deepest = "Deepest"
        case deadEnds = "All pairs tried"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                header
                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered, id: \.self) { id in
                        CollectionRow(game: game, id: id)
                        Divider().overlay(Token.hairline)
                    }
                }
            }
        }
        .background(Token.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Internal counts only — never the dictionary total.
            Text("\(game.collectedCount) of ∞").monoMeta(11)
            Text("Collection")
                .font(.display(38))
                .tracking(-38 * 0.035)
                .foregroundStyle(Token.ink)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Token.labelTertiary)
                TextField("Search \(game.collectedCount) items", text: $query)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: Token.Radius.field, style: .continuous).fill(Token.grouped))

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Filter.allCases) { option in
                        chip(option)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 14)
    }

    private func chip(_ option: Filter) -> some View {
        let isActive = filter == option
        return Button { filter = option } label: {
            Text(option.rawValue)
                .font(.control(13.5))
                .foregroundStyle(isActive ? .white : Token.labelSecondary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(isActive ? Token.accent : Token.grouped))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing by that name")
                .font(.control(15))
                .foregroundStyle(Token.ink)
            // Never suggest undiscovered items — that would leak the dictionary.
            Text(query)
                .monoMeta(10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var filtered: [ItemID] {
        var items = game.collectionNewestFirst

        switch filter {
        case .all: break
        case .untried: items = items.filter { game.untriedLeadCount(for: $0) > 0 }
        case .deepest: items = items.sorted { (game.depth(of: $0) ?? 0) > (game.depth(of: $1) ?? 0) }
        case .deadEnds: items = items.filter(game.isDeadEnd)
        }

        guard !query.isEmpty else { return items }
        let needle = query.lowercased()
        return items.filter { game.name(of: $0).lowercased().contains(needle) }
    }
}

struct CollectionRow: View {
    let game: GameState
    let id: ItemID

    var body: some View {
        HStack(spacing: 12) {
            Text(game.emoji(of: id))
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Token.Radius.field, style: .continuous)
                        .fill(Token.itemFill)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name(of: id))
                    .font(.display(19))
                    .foregroundStyle(Token.ink)
                    .lineLimit(1)
                Text(subtitle).monoMeta(9.5, tracking: 0.1)
            }

            Spacer()
            badge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        let depthText = game.depth(of: id).map { "depth \($0)" } ?? "unreachable"
        guard let (a, b) = game.recipe(for: id) else { return depthText }
        return "\(game.name(of: a)) + \(game.name(of: b)) · \(depthText)"
    }

    @ViewBuilder
    private var badge: some View {
        let leads = game.untriedLeadCount(for: id)
        if leads > 0 {
            Text("\(leads) leads")
                .monoMeta(9.5, tracking: 0.1, color: Token.accentText)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Capsule().fill(Token.accent.opacity(0.12)))
        } else {
            Text("All pairs tried")
                .monoMeta(9.5, tracking: 0.1)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Capsule().fill(Token.grouped))
        }
    }
}
