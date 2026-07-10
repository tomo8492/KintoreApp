// MARK: - TodayDashboardView
// CLAUDE.md §7 デザイン原則 準拠。Today タブを「素の VStack + 1 CTA」から
// ダッシュボード構成(挨拶ヘッダー / ヒーロー CTA カード / 今週サマリーカード)に
// 差し替える。ロジック(Builder 起動・Paywall・タブ構成)は RootView 側に残し、
// 本 View は純粋に表示 + タップ通知(onStartBuilder)のみを担当する。
//
// - ストリング: 既存キーのみ再利用(today.heading / today.subheading /
//   today.action.start-builder / today.week.title / "today.week.sets %lld" /
//   "today.week.sessions %lld" / a11y.today.start-builder.hint)。
//   新規キーは Localizable.xcstrings に追加できないため増やさない。
// - データ取得: @Query で WorkoutSession を全件取得し、今週(weekOfYear)の
//   区間でフィルタする。History 系ビュー(HistoryView / HistoryAggregations)と
//   同じ HistoryCutoff.defaultCalendar (autoupdatingCurrent) を使い、
//   週境界の計算方法を揃える。

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct TodayDashboardView: View {
    /// Builder ウィザードを開くアクション。所有権は RootView 側の
    /// `@SceneStorage("root.isBuilderPresented")` にあるため、本 View は
    /// トリガーのみを通知する。
    let onStartBuilder: () -> Void

    /// 新しい順に全セッションを取得し、今週分は本 View 内でフィルタする。
    /// (HistoryView.allSessions と同じ「全件取得 → 表示側で窓を絞る」方針)
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greetingHeader
                heroCard
                weekSummaryCard
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(AppColor.background)
    }

    // MARK: - Greeting header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("today.heading")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.7)

            Text("today.subheading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero CTA card

    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            // 装飾用の見出し。ボタン側にも同じキーのラベルがあり VoiceOver が
            // 二重読み上げしてしまうため、この Text はアクセシビリティツリーから隠す。
            Text("today.action.start-builder")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .accessibilityHidden(true)

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onStartBuilder()
            } label: {
                Text("today.action.start-builder")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.invertedCTA)
            .accessibilityLabel(Text("today.action.start-builder"))
            .accessibilityHint(Text("a11y.today.start-builder.hint"))
            .accessibilityAddTraits(.isButton)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppColor.accent, AppColor.accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    // MARK: - This-week summary card

    private var weekSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("today.week.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            Text("today.week.sets \(weekCompletedSetCount)")
                .statNumber()
                .foregroundStyle(.primary)

            Text("today.week.sessions \(weekSessionCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColor.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    // MARK: - Week aggregation

    /// 今週(weekOfYear, autoupdatingCurrent)に開始し、かつ完了済みのセッション。
    private var weekSessions: [WorkoutSession] {
        let calendar = HistoryCutoff.defaultCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return allSessions.filter { session in
            session.finishedAt != nil && interval.contains(session.startedAt)
        }
    }

    private var weekSessionCount: Int {
        weekSessions.count
    }

    /// 今週の完了済みセッションに含まれる、完了済みセット(completedAt != nil)の合計数。
    private var weekCompletedSetCount: Int {
        weekSessions.reduce(0) { total, session in
            total + session.sets.filter { $0.completedAt != nil }.count
        }
    }
}
