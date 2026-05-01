// MARK: - UnitsFormatter
// CLAUDE.md §-1.4 準拠。
// 保存は常に kg / m / UTC。表示変換はここでだけ行う(View 層から呼ぶ)。
// Settings の lbs 切替を反映するため、ユーザー設定を引数で受け取る形にする。

import Foundation

enum WeightUnitPreference: String, Codable, CaseIterable, Sendable {
    case kilograms
    case pounds
}

enum UnitsFormatter {
    private static let lbsPerKg: Double = 2.2046226218

    // MARK: - Weight

    /// 内部単位 kg を、ユーザー設定に応じた表示文字列に変換する。
    /// - Parameters:
    ///   - kilograms: 保存時の値(kg、§-1.4 内部単位)
    ///   - preference: ユーザー設定(.kilograms / .pounds)
    ///   - locale: 数値書式に使うロケール(既定はシステム)
    static func formatWeight(
        _ kilograms: Double,
        preference: WeightUnitPreference,
        locale: Locale = .current
    ) -> String {
        switch preference {
        case .kilograms:
            return formatNumber(kilograms, fractionDigits: 1, locale: locale) + " kg"
        case .pounds:
            let pounds = kilograms * lbsPerKg
            return formatNumber(pounds, fractionDigits: 1, locale: locale) + " lb"
        }
    }

    /// ユーザー入力(表示単位)を内部単位 kg に正規化する。保存前に必ず通すこと。
    static func toKilograms(_ value: Double, from preference: WeightUnitPreference) -> Double {
        switch preference {
        case .kilograms: return value
        case .pounds:    return value / lbsPerKg
        }
    }

    // MARK: - Duration

    /// 秒を `mm:ss` または `h:mm:ss` に整形(タイマー表示用)。
    static func formatDuration(seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Date

    /// 履歴一覧用の日付文字列(システムロケール)。
    static func formatHistoryDate(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Private

    private static func formatNumber(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
