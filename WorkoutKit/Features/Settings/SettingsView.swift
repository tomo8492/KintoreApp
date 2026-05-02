// MARK: - SettingsView
// CLAUDE.md §1.1 / §-1.4 / §10.4 / §11.4 準拠。
// - 単位切替は @AppStorage(SettingsKey.weightUnit) に保存し UnitsFormatter から参照される
// - テーマは Scene ルートに `.preferredColorScheme(_:)` で適用(WorkoutKitApp 側で読む)
// - 言語切替は iOS Settings の per-app Language を開く方式(iOS 13+ 標準)
// - Restore Purchase は AppDependency.purchaseRestorer 経由で StoreKitClient(F1)に到達
// - Privacy Policy / Terms は Bundle.main の Info.plist キー(xcconfig 経由)から取得

import SwiftUI
import UIKit
import OSLog

@MainActor
struct SettingsView: View {
    @Environment(\.appDependency) private var dependency
    @Environment(\.openURL) private var openURL

    @AppStorage(SettingsKey.weightUnit) private var weightUnitRaw: String = WeightUnitPreference.kilograms.rawValue
    @AppStorage(SettingsKey.theme)      private var themeRaw: String = ThemePreference.system.rawValue

    @State private var restoreState: RestoreState = .idle

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                languageSection
                purchasesSection
                aboutSection
                legalSection
            }
            .navigationTitle("settings.title")
            .alert(
                restoreState.alertTitle,
                isPresented: alertBinding,
                presenting: restoreState
            ) { _ in
                Button("common.ok", role: .cancel) { restoreState = .idle }
            } message: { state in
                if let message = state.alertMessage {
                    Text(message)
                }
            }
        }
    }

    // MARK: - Sections

    private var displaySection: some View {
        Section {
            Picker(selection: weightUnitBinding) {
                ForEach(WeightUnitPreference.allCases) { unit in
                    Text(unit.localizedTitle).tag(unit)
                }
            } label: {
                Label("settings.weightUnit", systemImage: "scalemass")
            }

            Picker(selection: themeBinding) {
                ForEach(ThemePreference.allCases) { theme in
                    Text(theme.localizedTitle).tag(theme)
                }
            } label: {
                Label("settings.theme", systemImage: "paintbrush")
            }
        } header: {
            Text("settings.section.display")
        } footer: {
            Text("settings.weightUnit.footer")
        }
    }

    private var languageSection: some View {
        Section {
            Button {
                openAppSettings()
            } label: {
                Label("settings.language.openSettings", systemImage: "globe")
            }
        } header: {
            Text("settings.section.language")
        } footer: {
            Text("settings.language.footer")
        }
    }

    private var purchasesSection: some View {
        Section {
            HStack {
                Label("settings.purchases.status", systemImage: "checkmark.seal")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(dependency.proGate.isPro ? "settings.purchases.status.pro" : "settings.purchases.status.free")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("settings.purchases.status"))
            .accessibilityValue(Text(dependency.proGate.isPro
                                     ? "settings.purchases.status.pro"
                                     : "settings.purchases.status.free"))

            Button {
                Task { await runRestore() }
            } label: {
                HStack {
                    Label("settings.purchases.restore", systemImage: "arrow.clockwise")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    if restoreState.isRestoring {
                        ProgressView()
                    }
                }
            }
            .disabled(restoreState.isRestoring)
            .accessibilityLabel(Text("settings.purchases.restore"))
            .accessibilityHint(Text("a11y.settings.restore.hint"))
            .accessibilityAddTraits(.isButton)
        } header: {
            Text("settings.section.purchases")
        } footer: {
            Text("settings.purchases.footer")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label("settings.about", systemImage: "info.circle")
            }
        } header: {
            Text("settings.section.about")
        }
    }

    private var legalSection: some View {
        Section {
            if let url = SettingsLinks.privacyPolicy {
                Link(destination: url) {
                    Label("settings.privacyPolicy", systemImage: "hand.raised")
                }
            }
            if let url = SettingsLinks.termsOfUse {
                Link(destination: url) {
                    Label("settings.termsOfUse", systemImage: "doc.text")
                }
            }
        } header: {
            Text("settings.section.legal")
        }
    }

    // MARK: - Bindings(@AppStorage<String> ↔ enum)

    private var weightUnitBinding: Binding<WeightUnitPreference> {
        Binding(
            get: { WeightUnitPreference(rawValue: weightUnitRaw) ?? .kilograms },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    private var themeBinding: Binding<ThemePreference> {
        Binding(
            get: { ThemePreference(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { restoreState.isAlertPresented },
            set: { presented in
                if !presented { restoreState = .idle }
            }
        )
    }

    // MARK: - Actions

    private func runRestore() async {
        restoreState = .restoring
        do {
            let restored = try await dependency.purchaseRestorer.restorePurchases()
            // ProFeatureGate は StoreKit のリスナー側で更新される想定。
            // ここではユーザーへのフィードバックのため、エンタイトルメントの有無 or 現在の isPro を見る。
            let isPro = dependency.proGate.isPro
            restoreState = (restored || isPro) ? .restored : .nothingToRestore
            Logger.app.info("restore purchases finished restored=\(restored, privacy: .public) isPro=\(isPro, privacy: .public)")
        } catch {
            Logger.app.error("restore purchases failed: \(error.localizedDescription, privacy: .public)")
            restoreState = .failure(error.localizedDescription)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Restore State

private enum RestoreState: Equatable {
    case idle
    case restoring
    case restored
    case nothingToRestore
    case failure(String)

    var isRestoring: Bool {
        if case .restoring = self { return true }
        return false
    }

    var isAlertPresented: Bool {
        switch self {
        case .restored, .nothingToRestore, .failure: return true
        case .idle, .restoring: return false
        }
    }

    var alertTitle: LocalizedStringKey {
        switch self {
        case .restored:         return "settings.purchases.alert.restored.title"
        case .nothingToRestore: return "settings.purchases.alert.nothing.title"
        case .failure:          return "settings.purchases.alert.failure.title"
        case .idle, .restoring: return ""
        }
    }

    var alertMessage: LocalizedStringKey? {
        switch self {
        case .restored:         return "settings.purchases.alert.restored.body"
        case .nothingToRestore: return "settings.purchases.alert.nothing.body"
        case .failure(let msg): return LocalizedStringKey(msg)
        case .idle, .restoring: return nil
        }
    }
}

// MARK: - External Links
// Privacy Policy / Terms of Use の URL は Info.plist(xcconfig 経由)で外部化する。
// CLAUDE.md §-1.7「Info.plist べた書き禁止」の最終的な根拠も xcconfig に置くことで満たす。

enum SettingsLinks {
    static var privacyPolicy: URL? {
        url(forInfoKey: "WKPrivacyPolicyURL")
    }

    static var termsOfUse: URL? {
        url(forInfoKey: "WKTermsOfUseURL")
    }

    private static func url(forInfoKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

#Preview {
    SettingsView()
}
