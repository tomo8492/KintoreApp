// MARK: - SessionExerciseRow
// SessionView の種目リスト行。CLAUDE.md §1.1 F-03 準拠。
// - 現在実施中の行はアクセントカラー枠で強調する(自動スクロール先)
// - 完了済みは check、未着手はグレー
// - row id は SessionPlanItem.id(UUID)。同一 slug が複数回出ても並びを保つ。

import SwiftUI

struct SessionExerciseRow: View {
    let item: SessionPlanItem
    let exercise: Exercise?
    let isCurrent: Bool
    let isCompleted: Bool
    let completedSetCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(displayName))
        .accessibilityValue(Text("\(progressText) \(statusKey)"))
    }

    /// F3: VoiceOver で「現在実施中」「完了済み」「未着手」を伝える。
    private var statusKey: String {
        if isCompleted { return String(localized: "a11y.session.row.completed", defaultValue: "完了済み") }
        if isCurrent   { return String(localized: "a11y.session.row.current",   defaultValue: "現在実施中") }
        return String(localized: "a11y.session.row.upcoming", defaultValue: "未着手")
    }

    // MARK: - Subviews

    private var statusIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .font(.title3)
            .accessibilityHidden(true)
    }

    private var iconName: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isCurrent   { return "play.circle.fill" }
        return "circle"
    }

    private var iconColor: Color {
        if isCompleted { return .accentColor }
        if isCurrent   { return .accentColor }
        return .secondary
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
            .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.gray.opacity(0.06))
    }

    // MARK: - Display

    private var displayName: String {
        if let ex = exercise {
            return Locale.current.language.languageCode?.identifier == "ja" ? ex.nameJa : ex.nameEn
        }
        return item.slug
    }

    private var progressText: String {
        let format = String(
            localized: "session.row.set-progress",
            defaultValue: "%lld / %lld セット"
        )
        return String(format: format, completedSetCount, item.plannedSetCount)
    }
}
