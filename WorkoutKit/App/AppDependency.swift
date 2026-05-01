// MARK: - AppDependency
// CLAUDE.md §4.1 準拠。Singleton(.shared) を禁じる代わりの DI ルート。
// View には @Environment / @Bindable で注入する。

import Foundation
import SwiftUI

/// アプリ全体の依存をまとめる。`@Observable` ではなく struct にして
/// 軽量に値渡しできる形にしておく(ストアは内側で MainActor 隔離)。
struct AppDependency {
    var proGate: ProFeatureGate
}

// MARK: - SwiftUI Environment 拡張
// `@Environment(\.appDependency)` で View から取り出せるようにする。

private struct AppDependencyKey: EnvironmentKey {
    @MainActor
    static var defaultValue: AppDependency {
        AppDependency(proGate: ProFeatureGate())
    }
}

extension EnvironmentValues {
    var appDependency: AppDependency {
        get { self[AppDependencyKey.self] }
        set { self[AppDependencyKey.self] = newValue }
    }
}
