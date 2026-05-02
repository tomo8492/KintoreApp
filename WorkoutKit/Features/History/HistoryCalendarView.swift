// MARK: - HistoryCalendarView
// CLAUDE.md §1.1 F-04 / §-1.4 / §-1.14 / §11.4 準拠。
// 月カレンダー。トレ実施日にドット、タップで当日のセッション一覧をシート表示。
// - 週の開始は Calendar.current.firstWeekday(§-1.4)
// - 月送りで 30 日窓より前に行こうとした瞬間に Paywall を要求(unlimitedHistory)
// - ローカライズは Calendar に任せる(週名・月名)

import SwiftUI

struct HistoryCalendarView: View {
    let sessions: [WorkoutSession]
    let onSelect: (WorkoutSession) -> Void
    /// 月送りで無料窓を超えた、または「全期間」アクション時に親へ通知する。
    /// 親 View が PaywallTrigger.gate を呼ぶ。
    let onPaywallRequested: (ProFeature) -> Void

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayRow
            daysGrid
            Spacer(minLength: 0)
        }
        .padding()
        .sheet(item: Binding(
            get: { selectedDay.map(HistoryCalendarSelectedDay.init(date:)) },
            set: { selectedDay = $0?.date }
        )) { wrapper in
            HistoryCalendarDaySessionsSheet(
                date: wrapper.date,
                sessions: sessions(on: wrapper.date),
                onSelect: { session in
                    selectedDay = nil
                    onSelect(session)
                }
            )
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                navigate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("history.calendar.prev-month"))

            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()

            Button {
                navigate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isAtCurrentMonth)
            .accessibilityLabel(Text("history.calendar.next-month"))
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "yMMMM",
            options: 0,
            locale: .current
        )
        return f.string(from: displayedMonth)
    }

    private var isAtCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    // MARK: - Weekday row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1  // weekday: 1=Sun
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: - Days grid

    private var daysGrid: some View {
        let cells = monthCells
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(cells, id: \.id) { cell in
                HistoryCalendarDayCell(
                    cell: cell,
                    isSelected: cell.date.map { calendar.isDate($0, inSameDayAs: selectedDay ?? .distantPast) } ?? false,
                    onTap: { handleTap(on: cell) }
                )
                .frame(height: 44)
            }
        }
    }

    private func handleTap(on cell: MonthCell) {
        guard let date = cell.date else { return }
        if !HistoryCutoff.isWithinFreeWindow(date) {
            onPaywallRequested(.unlimitedHistory)
            return
        }
        selectedDay = date
    }

    private func navigate(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: displayedMonth) else { return }
        let nextStart = calendar.startOfMonth(for: next)

        // 月全体が無料窓より古い → Paywall。窓が月の途中をまたぐ場合は遷移を許可する。
        if months < 0 {
            let endOfNext = calendar.date(byAdding: .month, value: 1, to: nextStart) ?? nextStart
            if endOfNext <= HistoryCutoff.freeWindowStart() {
                onPaywallRequested(.unlimitedHistory)
                return
            }
        }
        displayedMonth = nextStart
    }

    // MARK: - Month cells

    /// グリッドに並べる 1 セル。先頭の空白埋めは date == nil で表現する。
    struct MonthCell: Identifiable {
        let id = UUID()
        let date: Date?
        let dayNumber: Int?
        let isToday: Bool
        let hasSession: Bool
        let isLocked: Bool   // 無料窓外
    }

    private var monthCells: [MonthCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })

        var cells: [MonthCell] = (0..<leadingBlanks).map { _ in
            MonthCell(date: nil, dayNumber: nil, isToday: false, hasSession: false, isLocked: false)
        }

        for offset in 0..<daysInMonth {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monthInterval.start) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            cells.append(MonthCell(
                date: dayStart,
                dayNumber: calendar.component(.day, from: day),
                isToday: calendar.isDateInToday(day),
                hasSession: sessionDays.contains(dayStart),
                isLocked: !HistoryCutoff.isWithinFreeWindow(dayStart)
            ))
        }
        return cells
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sorted { $0.startedAt < $1.startedAt }
    }
}

#Preview {
    HistoryCalendarView(
        sessions: [],
        onSelect: { _ in },
        onPaywallRequested: { _ in }
    )
}
