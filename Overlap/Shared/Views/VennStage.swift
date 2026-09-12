import SwiftUI

/// The Venn diagram: item one on the left, item two on the right, the result in
/// the lens. Geometry per the handoff — two circles pinned to the edges, each
/// `(width + overlap) / 2` wide, so the lens is `overlap` across.
struct VennStage: View {
    let left: (emoji: String, name: String)?
    let right: (emoji: String, name: String)?
    /// Set during the reveal, shown in the lens.
    var result: (emoji: String, name: String)?

    var stageSize: CGSize = CGSize(width: 296, height: 184)
    /// Tunable 40–120; 92 is the shipping default.
    var overlap: CGFloat = 92
    /// Drives the converge-and-deepen sequence. 0 = apart, 1 = lens fills.
    var convergence: Double = 0
    /// tvOS inverts the blend on its dark surface.
    var blend: BlendMode = .multiply
    var emptyStrokeWidth: CGFloat = 1.5

    var onTapLeft: (() -> Void)?
    var onTapRight: (() -> Void)?

    private var circleWidth: CGFloat { (stageSize.width + overlap) / 2 }
    /// The circles translate toward each other as the sequence runs.
    private var converge: CGFloat { (stageSize.width - overlap) / 2 * convergence }

    var body: some View {
        ZStack {
            circle(filled: left != nil)
                .frame(width: circleWidth, height: stageSize.height)
                .offset(x: -(stageSize.width - circleWidth) / 2 + converge)
            circle(filled: right != nil)
                .frame(width: circleWidth, height: stageSize.height)
                .offset(x: (stageSize.width - circleWidth) / 2 - converge)

            labels
            lens
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .animation(Token.tintChange, value: left?.name)
        .animation(Token.tintChange, value: right?.name)
    }

    private func circle(filled: Bool) -> some View {
        Group {
            if filled {
                Circle()
                    .fill(Token.vennFill)
                    .blendMode(blend)
            } else {
                Circle()
                    .strokeBorder(Token.vennEmptyStroke, lineWidth: emptyStrokeWidth)
            }
        }
        // Circles are drawn as ellipses at the stage's aspect, per the mock.
        .scaleEffect(x: 1, y: 1)
    }

    // MARK: - Label zones

    private var labels: some View {
        HStack(spacing: 0) {
            zone(item: left, hint: ("Item", "one"), onTap: onTapLeft)
            Spacer(minLength: 0)
            zone(item: right, hint: ("Item", "two"), onTap: onTapRight)
        }
        .frame(width: stageSize.width, height: stageSize.height)
        // Labels fade out as the circles merge — the result takes over the lens.
        .opacity(1 - convergence)
    }

    private func zone(
        item: (emoji: String, name: String)?,
        hint: (String, String),
        onTap: (() -> Void)?
    ) -> some View {
        VStack(spacing: 6) {
            if let item {
                Text(item.emoji).font(.system(size: 30))
                Text(item.name)
                    .font(.control(13))
                    .foregroundStyle(Token.vennLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                // The two-line hint is the tutorial — there is no overlay.
                VStack(spacing: 1) {
                    Text(hint.0)
                    Text(hint.1)
                }
                .monoMeta(9.5, tracking: 0.1)
            }
        }
        .padding(.horizontal, 6)
        .frame(width: overlap, height: stageSize.height)
        .contentShape(Rectangle())
        // Tapping a filled circle clears that side — idle only; the caller
        // passes nil for `onTap` outside idle.
        .onTapGesture { if item != nil { onTap?() } }
    }

    // MARK: - Lens

    private var lens: some View {
        Group {
            if let result {
                VStack(spacing: 8) {
                    Text(result.emoji)
                        .font(.system(size: 74))
                        .scaleEffect(convergence)
                }
            } else if left != nil || right != nil {
                Text("?")
                    .font(.mono(22))
                    .foregroundStyle(Token.labelTertiary)
            } else {
                Circle()
                    .fill(Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.28))
                    .frame(width: 11, height: 11)
            }
        }
        .frame(width: 96)
    }
}

/// Drives the four-beat combine sequence the handoff calls for: circles
/// converge, the blend deepens as the lens forms, the emoji scales up, the name
/// lands. ~900ms total.
@MainActor
@Observable
final class CombineAnimator {
    var convergence: Double = 0
    var showResult = false
    var nameLanded = false

    func reset() {
        convergence = 0
        showResult = false
        nameLanded = false
    }

    /// Beats 1–2 run during `working`; 3–4 land as the reveal takes over.
    func runConverge() async {
        reset()
        withAnimation(Token.combineSequence) { convergence = 1 }
        try? await Task.sleep(for: .milliseconds(560))
        showResult = true
        withAnimation(Token.emojiPop) { }
        try? await Task.sleep(for: .milliseconds(240))
        withAnimation(Token.revealCurve) { nameLanded = true }
    }
}
