// MARK: - AboutView
// CLAUDE.md §-1.1 / Apple Guideline 1.4.1 準拠。
// アプリ情報・バージョン・医療助言ではない旨を明示する。
// 健康/フィットネス系アプリは医療免責の表示が審査で求められるため、必ず本文に含める。

import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                appHeader
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0))
            }

            Section {
                LabeledContent {
                    Text(versionString)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } label: {
                    Text("about.version")
                }
                LabeledContent {
                    Text(buildString)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } label: {
                    Text("about.build")
                }
            }

            Section {
                Text("about.medical.disclaimer.body")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("about.medical.disclaimer.title")
            }

            Section {
                Text("about.copyright")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var appHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(displayName)
                .font(.title2.bold())
            Text("about.tagline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bundle Info(force unwrap せず安全に取り出す)

    private var displayName: String {
        bundleString(forKey: "CFBundleDisplayName")
            ?? bundleString(forKey: "CFBundleName")
            ?? "WorkoutKit"
    }

    private var versionString: String {
        bundleString(forKey: "CFBundleShortVersionString") ?? "—"
    }

    private var buildString: String {
        bundleString(forKey: "CFBundleVersion") ?? "—"
    }

    private func bundleString(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
