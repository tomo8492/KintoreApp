// MARK: - HistoryCalendarSubviews
// HistoryCalendarView から切り出した補助 View / 値型 / Calendar 拡張。
// MonthCell の描画(DayCell)と日付タップ時の DaySessionsSheet をまとめている。

import SwiftUI

// MARK: - DayCell

struct HistoryCalendarDayCell: View {
    let cell: HistoryCalendarView.MonthCell
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(cell.dayNumber.map(String.init) ?? "")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(textColor)
                Circle()
                    .fill(cell.hasSession ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .overlay {
                if cell.isToday {
                    RoundedRectangle(cornerRadius: AppRadius.chip)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
            .overlay(alignment: .topTrailing) {
                if cell.isLocked && cell.dayNumber != nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(cell.dayNumber == nil)
    }

    private var textColor: Color {
        if cell.dayNumber == nil { return .clear }
        if cell.isLocked { return .secondary }
        return .primary
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if cell.isToday { return Color.accentColor.opacity(0.06) }
        return .clear
    }
}

// MARK: - SelectedDay wrapper

/// `sheet(item:)` が要求する Identifiable に Date を包む。
struct HistoryCalendarSelectedDay: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

// MARK: - DaySessionsSheet

struct HistoryCalendarDaySessionsSheet: View {
    let date: Date
    let sessions: [WorkoutSession]
    let onSelect: (WorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "history.calendar.day.empty",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                } else {
                    ForEach(sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(UnitsFormatter.formatHistoryDate(session.startedAt))
                                    .font(.subheadline.weight(.semibold))
                                Text(GoalLabels.displayName(for: session.goal))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.close")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var headerTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Calendar helper

extension Calendar {
    /// 指定日が含まれる月の 1 日 0:00 を返す。
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
