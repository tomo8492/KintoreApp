// MARK: - HistoryView
// CLAUDE.md §1.1 F-04 / §-1.14 / §-1.15 / §11.4 準拠。
// 履歴・進捗のルート。
// - List / Calendar / Charts の3モード切替(Picker)
// - 直近30日は無料、31日以前は ProFeatureGate.unlimitedHistory ゲート
//   → 起動直後の Paywall は出さず、「Show all」アクションや 31日以前のセッション選択時のみ
// - iPhone(.compact)は NavigationStack、iPad(.regular)は NavigationSplitView
// - View には @State / @Observable Store 直挿し(ViewModel 禁止)

import SwiftUI
import SwiftData
import OSLog

// `HistoryCutoff` は HistoryCutoff.swift に分離 (DEBUG_REPORT Critical-3 で
// TZ-safe 化 + 単一窓口化したため)。

// MARK: - Mode

enum HistoryMode: String, CaseIterable, Identifiable, Sendable {
    case list
    case calendar
    case charts

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .list:     return "history.mode.list"
        case .calendar: return "history.mode.calendar"
        case .charts:   return "history.mode.charts"
        }
    }

    var systemImage: String {
        switch self {
        case .list:     return "list.bullet"
        case .calendar: return "calendar"
        case .charts:   return "chart.bar.xaxis"
        }
    }
}

// MARK: - HistoryView

struct HistoryView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appDependency) private var dependency
    @Environment(\.modelContext) private var modelContext

    /// セッションは新しい順で取得。無料窓フィルタは visibleSessions 側で行う。
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @State private var mode: HistoryMode = .list
    @State private var paywall: PaywallContext?
    /// Pro 解放後の「全期間表示」スイッチ。proGate.isPro が false に戻れば自動で false に倒す。
    @State private var showAllHistory: Bool = false
    @State private var selectedSession: WorkoutSession?
    /// 手動ログ入力シート (F-04 / Issue #88)。Pro ゲート通過後にのみ true になる。
    @State private var showingManualEntry: Bool = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .paywallSheet(paywall: $paywall)
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .onChange(of: dependency.proGate.isPro) { _, newValue in
            if !newValue { showAllHistory = false }
        }
    }

    // MARK: - iPhone

    private var iPhoneBody: some View {
        NavigationStack {
            modeContent
                .navigationTitle("history.title")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarContent }
        }
    }

    // MARK: - iPad

    private var iPadBody: some View {
        NavigationSplitView {
            List(selection: $selectedSession) {
                Section {
                    Picker("history.mode.picker", selection: $mode) {
                        ForEach(HistoryMode.allCases) { m in
                            Label(m.titleKey, systemImage: m.systemImage).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("history.section.sessions") {
                    ForEach(visibleSessions) { session in
                        NavigationLink(value: session) {
                            HistorySessionRow(session: session)
                        }
                    }
                    if !showAllHistory && hasOlderSessions {
                        showAllRow
                    }
                }
            }
            .navigationTitle("history.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleManualEntryRequested()
                    } label: {
                        Label("history.action.manual-entry", systemImage: "square.and.pencil")
                    }
                    .accessibilityLabel(Text("history.action.manual-entry"))
                    .accessibilityHint(Text("a11y.history.manual-entry.hint"))
                }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                detailDestination(for: session)
            }
        } detail: {
            modeContent
        }
    }

    // MARK: - Mode content

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .list:
            HistoryListView(
                sessions: visibleSessions,
                hasOlderSessions: hasOlderSessions,
                showAllHistory: showAllHistory,
                onSelect: { handleSelect($0) },
                onShowAllRequested: { handleShowAllRequested() }
            )
        case .calendar:
            HistoryCalendarView(
                sessions: visibleSessions,
                onSelect: { handleSelect($0) },
                onPaywallRequested: { feature in
                    paywall = PaywallContext(feature: feature)
                }
            )
        case .charts:
            HistoryChartsView(
                sessions: visibleSessions,
                isPro: dependency.proGate.isPro,
                onAdvancedRequested: { handleAdvancedChartsRequested() }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("history.mode.picker", selection: $mode) {
                ForEach(HistoryMode.allCases) { m in
                    Label(m.titleKey, systemImage: m.systemImage).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                handleManualEntryRequested()
            } label: {
                Label("history.action.manual-entry", systemImage: "square.and.pencil")
            }
        }
    }

    private var showAllRow: some View {
        Button {
            handleShowAllRequested()
        } label: {
            Label("history.action.show-all", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel(Text("history.action.show-all"))
        .accessibilityHint(Text("a11y.history.show-all.hint"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func detailDestination(for session: WorkoutSession) -> some View {
        if HistoryCutoff.isWithinFreeWindow(session.startedAt) || dependency.proGate.isPro {
            HistorySessionDetailView(session: session)
        } else {
            // 31 日以前のセッションが何らかの経路でナビに渡ってきた場合の保険。
            // 通常は handleSelect で gate に弾かれるためここには来ない。
            ProGateLockedView(feature: .unlimitedHistory) {
                paywall = PaywallContext(feature: .unlimitedHistory)
            }
        }
    }

    // MARK: - Derived

    private var visibleSessions: [WorkoutSession] {
        // 完了 / 中断問わず finishedAt が打たれたものを履歴対象とする(F-04)。
        // 実行中(finishedAt == nil)は履歴に出さない。
        let finished = allSessions.filter { $0.finishedAt != nil }
        if showAllHistory && dependency.proGate.isPro {
            return finished
        }
        let cutoff = HistoryCutoff.freeWindowStart()
        return finished.filter { $0.startedAt >= cutoff }
    }

    private var hasOlderSessions: Bool {
        let cutoff = HistoryCutoff.freeWindowStart()
        return allSessions.contains { $0.finishedAt != nil && $0.startedAt < cutoff }
    }

    // MARK: - Pro gates

    private func handleSelect(_ session: WorkoutSession) {
        if HistoryCutoff.isWithinFreeWindow(session.startedAt) {
            selectedSession = session
            return
        }
        PaywallTrigger.gate(
            .unlimitedHistory,
            proGate: dependency.proGate,
            paywall: $paywall
        ) {
            selectedSession = session
        }
    }

    private func handleShowAllRequested() {
        PaywallTrigger.gate(
            .unlimitedHistory,
            proGate: dependency.proGate,
            paywall: $paywall
        ) {
            showAllHistory = true
        }
    }

    private func handleAdvancedChartsRequested() {
        PaywallTrigger.gate(
            .advancedCharts,
            proGate: dependency.proGate,
            paywall: $paywall
        ) {
            // Pro 解放済み: HistoryChartsView 内部で詳細チャートを描画するための
            // フラグ更新は不要(isPro を直接見て分岐するため)。
            Logger.app.info("history: advanced charts unlocked")
        }
    }

    private func handleManualEntryRequested() {
        PaywallTrigger.gate(
            .manualEntry,
            proGate: dependency.proGate,
            paywall: $paywall
        ) {
            showingManualEntry = true
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
