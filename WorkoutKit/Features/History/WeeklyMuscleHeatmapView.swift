// MARK: - WeeklyMuscleHeatmapView
// CLAUDE.md §7 デザイン原則 / §11 NG リスト 準拠。
// History > Charts の目玉カード。今週(Calendar.autoupdatingCurrent の
// weekOfYear 区間)に完了した ExerciseSet を exercise.primaryMuscle 単位で
// 集計し、CompactBodyDiagramView と同じ「body-base + per-muscle overlay」の
// レンダリング手法で濃淡表示する(front/back は body-base 1 枚に既に
// 左右で焼き込まれているため、別画像を作らずそのまま流用する)。
//
// CLAUDE.md NG リスト:
//   - 文字列は Localizable.xcstrings 経由(LocalizedStringKey / String(localized:))
//   - print/force unwrap/.shared なし
//   - View には @State / @Observable のみ(本 View は sessions を受け取るだけの stateless)

import SwiftUI

struct WeeklyMuscleHeatmapView: View {
    let sessions: [WorkoutSession]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let viewBoxAspect: CGFloat =
        BodyHitZones.viewBox.width / BodyHitZones.viewBox.height

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            diagram
                .aspectRatio(Self.viewBoxAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
            legend
        }
        .padding(16)
        .premiumDiagramCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("a11y.history.body-heatmap.label"))
        .accessibilityValue(accessibilityValueText)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("history.body-heatmap.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("history.body-heatmap.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Diagram stack

    /// CompactBodyDiagramView と同じ ZStack 構成(silhouette + per-muscle overlay)。
    /// 差分は opacity をタップ選択ではなく「今週のセット数の正規化値」から出す点のみ。
    private var diagram: some View {
        ZStack {
            Image("Body/body-base")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(silhouetteColor)
                .scaledToFit()

            ForEach(orderedMuscles, id: \.self) { muscle in
                if let asset = highlightAssetName(for: muscle),
                   let opacity = intensities[muscle] {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .opacity(opacity)
                        .animation(reduceMotion ? nil : .easeOut, value: opacity)
                }
            }

            if isEmptyWeek {
                Text("history.body-heatmap.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Legend

    /// 凡例は色そのもの(AppColor.accent の薄い〜濃いグラデーション)のみ。
    /// テキストラベルは subtitle が既に説明しているため付けない。
    private var legend: some View {
        LinearGradient(
            colors: [AppColor.accent.opacity(0.25), AppColor.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Aggregation

    /// Calendar.autoupdatingCurrent の週区間(ユーザーロケールの週開始日に追従)。
    private var weekInterval: DateInterval? {
        Calendar.autoupdatingCurrent.dateInterval(of: .weekOfYear, for: .now)
    }

    /// 今週に開始したセッション。呼び出し元(HistoryChartsView)から渡される
    /// sessions は既に「完了済み」(finishedAt != nil)にフィルタ済みのため、
    /// ここでは週区間の絞り込みのみ行う。
    private var weekSessions: [WorkoutSession] {
        guard let weekInterval else { return [] }
        return sessions.filter { weekInterval.contains($0.startedAt) }
    }

    /// 部位別「完了済みセット数」。.fullBody は個別ハイライト画像を持たないため除外する。
    private var setCountsByMuscle: [Muscle: Int] {
        var counts: [Muscle: Int] = [:]
        for session in weekSessions {
            for set in session.sets {
                guard set.completedAt != nil else { continue }
                guard let exercise = set.exercise else { continue }
                let muscle = exercise.primaryMuscle
                guard muscle != .fullBody else { continue }
                counts[muscle, default: 0] += 1
            }
        }
        return counts
    }

    private var maxSetCount: Int {
        setCountsByMuscle.values.max() ?? 0
    }

    private var isEmptyWeek: Bool {
        maxSetCount == 0
    }

    /// opacity = 0.25 + 0.75 * (sets / maxSets)。0 セットの部位は非表示(nil)。
    private var intensities: [Muscle: Double] {
        guard maxSetCount > 0 else { return [:] }
        var result: [Muscle: Double] = [:]
        for (muscle, count) in setCountsByMuscle where count > 0 {
            result[muscle] = 0.25 + 0.75 * (Double(count) / Double(maxSetCount))
        }
        return result
    }

    private var orderedMuscles: [Muscle] {
        Muscle.allCases.filter { $0 != .fullBody }.sorted { $0.rawValue < $1.rawValue }
    }

    private func highlightAssetName(for muscle: Muscle) -> String? {
        guard muscle != .fullBody else { return nil }
        return "Body/body-\(muscle.rawValue)"
    }

    private var silhouetteColor: Color {
        Color.gray.opacity(0.45)
    }

    // MARK: - Accessibility

    /// 「胸 6 セット、背中 4 セット、肩 3 セット」のように上位 3 部位を
    /// ローカライズ済み部位名 + セット数で読み上げる。今週の記録が無ければ
    /// empty メッセージをそのまま値として返す。
    private var accessibilityValueText: Text {
        let top = setCountsByMuscle
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .prefix(3)

        guard !top.isEmpty else {
            return Text("history.body-heatmap.empty")
        }

        let setsTemplate = String(localized: "history.row.sets", defaultValue: "%lld セット")
        let parts = top.map { entry -> String in
            let name = String(localized: String.LocalizationValue("muscle.\(entry.key.rawValue)"))
            let countText = String(format: setsTemplate, entry.value)
            return "\(name) \(countText)"
        }
        return Text(parts.joined(separator: "、"))
    }
}

#Preview("WeeklyMuscleHeatmap - empty") {
    WeeklyMuscleHeatmapView(sessions: [])
        .padding()
}
