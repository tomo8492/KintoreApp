// MARK: - Logging
// CLAUDE.md §-1.6 準拠。print 禁止、すべて OSLog Logger を経由する。
// subsystem は "com.tomo.workoutkit" で固定(Bundle ID と一致)。

import Foundation
import OSLog

extension Logger {
    private static let subsystem = "com.tomo.workoutkit"

    /// アプリ全般(起動、ライフサイクル、ナビゲーション)。
    static let app = Logger(subsystem: subsystem, category: "app")
    /// SwiftData / Repository 周り。
    static let data = Logger(subsystem: subsystem, category: "data")
    /// WorkoutGenerator の挙動。
    static let generator = Logger(subsystem: subsystem, category: "generator")
    /// CSV / JSON Importer の挙動。
    static let importer = Logger(subsystem: subsystem, category: "importer")
    /// StoreKit / 課金フロー。
    static let store = Logger(subsystem: subsystem, category: "store")
    /// Live Activity / Timer / Notification。
    static let session = Logger(subsystem: subsystem, category: "session")
}
