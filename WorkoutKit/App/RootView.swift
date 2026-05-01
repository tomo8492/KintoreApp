// MARK: - RootView
// CLAUDE.md §-1.15 / §5 準拠。
// iPhone(compact)は TabView、iPad(regular)は NavigationSplitView に分岐する。
// 各 Feature の本体は P1 以降で差し込むため、ここではタブ枠だけ用意する。

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            iPadRoot
        } else {
            iPhoneRoot
        }
    }

    // MARK: - iPhone (compact)

    private var iPhoneRoot: some View {
        TabView {
            todayPlaceholder
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

            ExerciseListView()
                .tabItem { Label("Library", systemImage: "books.vertical") }

            historyPlaceholder
                .tabItem { Label("History", systemImage: "calendar") }

            settingsPlaceholder
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    // MARK: - iPad (regular)
    // iPad では Library 自身が NavigationSplitView を使うため、
    // Root は TabView でタブ切替のみ担当する(NavigationSplitView の入れ子を避ける)。

    private var iPadRoot: some View {
        TabView {
            todayPlaceholder
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

            ExerciseListView()
                .tabItem { Label("Library", systemImage: "books.vertical") }

            historyPlaceholder
                .tabItem { Label("History", systemImage: "calendar") }

            settingsPlaceholder
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    // MARK: - Placeholders(P1 以降で実装)

    private var todayPlaceholder: some View {
        ContentUnavailableView(
            "Today",
            systemImage: "figure.strengthtraining.traditional",
            description: Text("Builder ウィザードは Phase P1 で実装します。")
        )
    }

    private var historyPlaceholder: some View {
        ContentUnavailableView(
            "History",
            systemImage: "calendar",
            description: Text("履歴・進捗は Phase P3 で実装します。")
        )
    }

    private var settingsPlaceholder: some View {
        ContentUnavailableView(
            "Settings",
            systemImage: "gearshape",
            description: Text("設定は Phase P4 で実装します。")
        )
    }
}

#Preview {
    RootView()
}
