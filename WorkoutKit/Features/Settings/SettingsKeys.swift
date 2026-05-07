// MARK: - SettingsKeys
// CLAUDE.md §-1.4 / §11.4 準拠。
// @AppStorage で使うキーと、Settings で使う列挙体をまとめる。
// 文字列キーは UserDefaults に書き込まれるため一度確定したら勝手に変えない。

import SwiftUI

/// UserDefaults のキー(@AppStorage 用)。
enum SettingsKey {
    /// 重量単位。値は `WeightUnitPreference.rawValue` ("kilograms" / "pounds")。
    static let weightUnit = "settings.weightUnit"
    /// テーマ。値は `ThemePreference.rawValue` ("system" / "light" / "dark")。
    static let theme = "settings.theme"
    /// 履歴リストの並び順。値は `HistoryListView.SortOrder.rawValue`("newest" / "oldest")。
    /// セッション間で記憶する。Settings 画面には出さず、履歴画面の Picker からのみ更新。
    static let historySortOrder = "history.sortOrder"
}

/// アプリの外観。Settings で切替、Scene ルートに `.preferredColorScheme(_:)` で適用。
enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// SwiftUI に渡す `ColorScheme?`。`.system` は nil(端末設定に従う)。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .system: return "settings.theme.system"
        case .light:  return "settings.theme.light"
        case .dark:   return "settings.theme.dark"
        }
    }
}

extension WeightUnitPreference: Identifiable {
    var id: String { rawValue }

    /// VoiceOver / a11y description 用。長い形(「キログラム」「Kilograms」など)。
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .kilograms: return "settings.weightUnit.kilograms"
        case .pounds:    return "settings.weightUnit.pounds"
        }
    }

    /// Segmented Picker の visible label 用。短縮形「kg」「lbs」。
    /// iPhone SE (375pt 幅) や Dynamic Type 拡大時の overflow を避けるため、
    /// 視覚は常に 2–3 文字で固定する。VoiceOver は `localizedTitle` 経由で
    /// 「キログラム」「Kilograms」を読み上げる(SettingsView で
    /// `.accessibilityLabel` で上書き)。
    var localizedShortTitle: LocalizedStringKey {
        switch self {
        case .kilograms: return "settings.weightUnit.kilograms.short"
        case .pounds:    return "settings.weightUnit.pounds.short"
        }
    }
}
