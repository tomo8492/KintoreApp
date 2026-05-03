// MARK: - RootView
// CLAUDE.md §-1.15 / §5 準拠。
// iPhone(compact)は TabView、iPad(regular)も TabView を使う(Library が
// NavigationSplitView を内包するため二重ネストを避ける)。
// 各 Feature の本体は順次差し込み、E1 で Templates タブが追加された。

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
            todayTab
                .tabItem { Label("tab.today", systemImage: "figure.strengthtraining.traditional") }

            templatesTab
                .tabItem { Label("tab.templates", systemImage: "square.stack.3d.up") }

            ExerciseListView()
                .tabItem { Label("tab.library", systemImage: "books.vertical") }

            historyTab
                .tabItem { Label("tab.history", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
        }
    }

    // MARK: - iPad (regular)
    // iPad では Library 自身が NavigationSplitView を使うため、
    // Root は TabView でタブ切替のみ担当する(NavigationSplitView の入れ子を避ける)。

    private var iPadRoot: some View {
        TabView {
            todayTab
                .tabItem { Label("tab.today", systemImage: "figure.strengthtraining.traditional") }

            templatesTab
                .tabItem { Label("tab.templates", systemImage: "square.stack.3d.up") }

            ExerciseListView()
                .tabItem { Label("tab.library", systemImage: "books.vertical") }

            historyTab
                .tabItem { Label("tab.history", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
        }
    }

    // MARK: - Templates tab (E1 で実装)

    private var templatesTab: some View {
        NavigationStack {
            TemplatesView()
        }
    }

    // MARK: - Today

    /// Today タブの入口。Builder ウィザードを fullScreenCover で開く CTA を出す。
    /// - iPhone/iPad とも fullScreenCover で BuilderView を独立して表示することで、
    ///   iPad 側で RootView の NavigationSplitView と BuilderView の NavigationSplitView
    ///   が二重にネストするのを避ける。
    private var todayTab: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("today.heading")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("today.action.start-builder"))
            .accessibilityHint(Text("a11y.today.start-builder.hint"))
            .accessibilityAddTraits(.isButton)
        }
        .padding()
        .fullScreenCover(isPresented: $isBuilderPresented) {
            BuilderView()
        }
    }

    // MARK: - History / Settings

    private var historyTab: some View {
        HistoryView()
    }
}

#Preview {
    RootView()
}
