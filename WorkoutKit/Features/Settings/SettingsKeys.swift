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

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .kilograms: return "settings.weightUnit.kilograms"
        case .pounds:    return "settings.weightUnit.pounds"
        }
    }
}
