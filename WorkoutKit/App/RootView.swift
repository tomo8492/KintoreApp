// MARK: - RootView
// CLAUDE.md §-1.15 / §5 準拠。
// iPhone(compact)は TabView、iPad(regular)は NavigationSplitView に分岐する。
// 各 Feature の本体は P1 以降で差し込むため、ここではタブ枠だけ用意する。

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isBuilderPresented = false

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

            libraryPlaceholder
                .tabItem { Label("Library", systemImage: "books.vertical") }

            historyPlaceholder
                .tabItem { Label("History", systemImage: "calendar") }

            settingsPlaceholder
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    // MARK: - iPad (regular)

    private var iPadRoot: some View {
        NavigationSplitView {
            List {
                NavigationLink("Today")    { todayPlaceholder }
                NavigationLink("Library")  { libraryPlaceholder }
                NavigationLink("History")  { historyPlaceholder }
                NavigationLink("Settings") { settingsPlaceholder }
            }
            .navigationTitle("WorkoutKit")
        } detail: {
            todayPlaceholder
        }
    }

    // MARK: - Placeholders(P1 以降で実装)

    /// Today タブの入口。Builder ウィザードを fullScreenCover で開く CTA を出す。
    /// - iPhone/iPad とも fullScreenCover で BuilderView を独立して表示することで、
    ///   iPad 側で RootView の NavigationSplitView と BuilderView の NavigationSplitView
    ///   が二重にネストするのを避ける。
    private var todayPlaceholder: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("today.heading")
                .font(.title2.bold())
            Text("today.subheading")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                isBuilderPresented = true
            } label: {
                Text("today.action.start-builder")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .fullScreenCover(isPresented: $isBuilderPresented) {
            BuilderView()
        }
    }

    private var libraryPlaceholder: some View {
        ContentUnavailableView(
            "Library",
            systemImage: "books.vertical",
            description: Text("種目DB 一覧は Phase P3 で実装します。")
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
