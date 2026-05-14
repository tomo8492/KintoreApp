// MARK: - WorkoutKitWatchWidget
// CLAUDE.md v0.5 §-1.19 準拠。
//
// Apple Watch の Smart Stack に表示する単一の accessoryRectangular ウィジェット。
// フルアプリではなく Widget Extension のみで提供(工数最小化)。
//
// 表示:
//   - ✅ 完了 / 📅 未実施 のステータス
//   - 今日のセット数(完了時のみ)
//
// 文字列はアプリ本体の Localizable.xcstrings を参照(別 Bundle なので、
// project.yml の Resources で同 catalog を Watch 拡張に同梱する設計だが、
// v0.5 初版は最小ファイル数で動作する scaffold とし、catalog 連携は Phase 4)。

import SwiftUI
import WidgetKit

@main
struct WorkoutKitWatchBundle: WidgetBundle {
    var body: some Widget {
        WorkoutKitWatchWidget()
    }
}

struct WorkoutKitWatchWidget: Widget {
    let kind: String = "WorkoutKitWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutWidgetProvider()) { entry in
            WorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("WorkoutKit")
        .description("今日のワークアウト状況")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - View

struct WorkoutWidgetView: View {
    let entry: WorkoutWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            statusBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isCompletedToday ? "完了" : "未実施")
                    .font(.headline)
                    .lineLimit(1)
                if entry.isCompletedToday {
                    Text("\(entry.totalSetsToday) セット")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("WorkoutKit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .widgetURL(URL(string: "workoutkit://today"))
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(entry.isCompletedToday ? Color.green.opacity(0.25) : Color.gray.opacity(0.20))
                .frame(width: 36, height: 36)
            Image(systemName: entry.isCompletedToday ? "checkmark" : "calendar")
                .foregroundStyle(entry.isCompletedToday ? Color.green : Color.secondary)
                .font(.system(size: 16, weight: .semibold))
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Preview

#Preview("rectangular / done", as: .accessoryRectangular) {
    WorkoutKitWatchWidget()
} timeline: {
    WorkoutWidgetEntry.sample
}

#Preview("rectangular / empty", as: .accessoryRectangular) {
    WorkoutKitWatchWidget()
} timeline: {
    WorkoutWidgetEntry.placeholder
}
