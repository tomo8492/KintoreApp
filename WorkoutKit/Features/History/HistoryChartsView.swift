// MARK: - HistoryChartsView
// CLAUDE.md §1.1 F-04 / §-1.14 / §11.4 準拠。
// Swift Charts による進捗可視化。
// - 無料: 直近 30 日の週次ボリューム(部位グループ別の積み上げ棒)
// - Pro:  詳細チャート(月次推移 + 部位別ヒートマップ)→ ProFeature.advancedCharts でゲート
// - 起動直後の Paywall は出さず、「詳細チャートを開く」ボタン経由でのみゲート要求を出す

import SwiftUI
import Charts

struct HistoryChartsView: View {
    let sessions: [WorkoutSession]
    let isPro: Bool
    let onAdvancedRequested: () -> Void

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    private var weightUnit: WeightUnitPreference {
        WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                weeklySection
                advancedSection
            }
            .padding()
        }
    }

    // MARK: - Weekly (free)

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "history.charts.weekly.title",
                subtitle: "history.charts.weekly.subtitle"
            )
            if weeklyPoints.isEmpty {
                emptyState
            } else {
                totalVolumeStat
                weeklyChart
                legend
            }
        }
    }

    /// この画面で最も重要な数値(直近 30 日の総ボリューム)を大きく見せる。
    /// 個々のバーの数値には statNumber() を付けない(§7 で「1画面につき主役数値は1つ」)。
    private var totalVolumeStat: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(totalVolumeLabel)
                .statNumber()
            Text("history.chart.axis.volume")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var totalVolumeLabel: String {
        let total = weeklyPoints.reduce(0.0) { $0 + $1.volumeKg }
        return UnitsFormatter.formatWeight(total, preference: weightUnit)
    }

    private var weeklyChart: some View {
        Chart(weeklyPoints) { point in
            BarMark(
                x: .value("history.chart.axis.week", point.weekStart, unit: .weekOfYear),
                y: .value("history.chart.axis.volume", point.volumeKg)
            )
            .foregroundStyle(by: .value("history.chart.legend.muscle", point.muscleGroup.localizedTitle))
            // Charts API の BarMark.cornerRadius(_:) パラメータ(AppRadius 対象外、意図的に維持)。
            .cornerRadius(2)
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(Muscle.Group.allCases, id: \.self) { group in
                HStack(spacing: 4) {
                    Circle()
                        .frame(width: 8, height: 8)
                    Text(group.localizedTitle)
                        .font(.caption)
                }
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Advanced (Pro)

    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "history.charts.advanced.title",
                subtitle: "history.charts.advanced.subtitle"
            )
            if isPro {
                // 目玉機能の週間筋肉ヒートマップを Pro セクションの先頭に置く
                // (§5-1 表の「進捗グラフ」= Premium。既存の isPro ゲートをそのまま使う)。
                WeeklyMuscleHeatmapView(sessions: sessions)
                MonthlyVolumeChart(points: monthlyPoints)
                MuscleHeatmapChart(matrix: heatmap)
            } else {
                lockedAdvancedCard
            }
        }
    }

    private var lockedAdvancedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("history.charts.advanced.locked.title", systemImage: "lock.fill")
                .font(.headline)
            Text("history.charts.advanced.locked.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                onAdvancedRequested()
            } label: {
                Text("history.charts.advanced.unlock")
            }
            .buttonStyle(.primaryCTA)
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
    }

    // MARK: - Common bits

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        Text("history.charts.empty")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }

    // MARK: - Aggregation

    /// 週次・部位グループ別のボリューム。Chart で stack 表示する。
    fileprivate var weeklyPoints: [WeeklyVolumePoint] {
        WeeklyVolumePoint.aggregate(sessions: sessions)
    }

    /// 月次・全体ボリューム(Pro)。
    fileprivate var monthlyPoints: [MonthlyVolumePoint] {
        MonthlyVolumePoint.aggregate(sessions: sessions)
    }

    /// 部位 × 週 のヒートマップ用 2 次元集計(Pro)。
    fileprivate var heatmap: MuscleHeatmapMatrix {
        MuscleHeatmapMatrix.aggregate(sessions: sessions)
    }
}

// MARK: - MonthlyVolumeChart

private struct MonthlyVolumeChart: View {
    let points: [MonthlyVolumePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("history.charts.monthly.title")
                .font(.subheadline.weight(.semibold))
            if points.isEmpty {
                Text("history.charts.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("history.chart.axis.month", point.monthStart, unit: .month),
                        y: .value("history.chart.axis.volume", point.volumeKg)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("history.chart.axis.month", point.monthStart, unit: .month),
                        y: .value("history.chart.axis.volume", point.volumeKg)
                    )
                }
                .frame(height: 200)
            }
        }
    }
}

// MARK: - MuscleHeatmapChart

private struct MuscleHeatmapChart: View {
    let matrix: MuscleHeatmapMatrix

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("history.charts.heatmap.title")
                .font(.subheadline.weight(.semibold))
            if matrix.cells.isEmpty {
                Text("history.charts.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(matrix.cells) { cell in
                    RectangleMark(
                        x: .value("history.chart.axis.week", cell.weekStart, unit: .weekOfYear),
                        y: .value("history.chart.axis.muscle", cell.muscle.rawValue)
                    )
                    .foregroundStyle(by: .value("history.chart.axis.volume", cell.volumeKg))
                }
                .chartForegroundStyleScale(range: Gradient(colors: [.blue.opacity(0.15), .accentColor]))
                .frame(height: 240)
            }
        }
    }
}

#Preview("Free") {
    HistoryChartsView(sessions: [], isPro: false, onAdvancedRequested: {})
}

#Preview("Pro") {
    HistoryChartsView(sessions: [], isPro: true, onAdvancedRequested: {})
}
