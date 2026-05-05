// MARK: - ExerciseDetailView
// CLAUDE.md §1.1 F-02。種目DBの詳細画面。
// description は HTMLSanitizer + HTMLDescriptionView(タスク C4 実装済み)で
// AttributedString として安全にレンダリングする。
// YouTube ボタンは ProFeatureGate.check(.videoLink) で Pro ゲート(§-1.14 / §11.4)。

import SwiftUI
import OSLog

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.appDependency) private var dependency

    @State private var showPaywall: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                annotatedFormSection
                targetMusclesSection
                if !cautions.isEmpty {
                    cautionsSection
                }
                steps
                muscleBadges
                if !exercise.equipment.isEmpty {
                    equipmentBadges
                }
                youtubeButton
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showPaywall) {
            ProPaywallPlaceholder(feature: .videoLink)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(LibraryDisplay.typeName(exercise.type))
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15), in: .capsule)

                if let mech = exercise.mechanicsType {
                    Text(LibraryDisplay.mechanicsName(mech))
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: .capsule)
                }
            }

            if !introduction.isEmpty {
                Text(introduction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Annotated form photo (F-02)

    /// 写真+吹き出しアノテーションのセクション。JSON が無い種目では何も描かない。
    /// 5 種目(push-up / air-squat / plank / reverse-lunge / burpee)のみ対応。
    @ViewBuilder
    private var annotatedFormSection: some View {
        if let formView = AnnotatedFormView(slug: exercise.slug) {
            VStack(alignment: .leading, spacing: 8) {
                Text("library.detail.form-cues")
                    .font(.headline)
                formView
            }
        }
    }

    // MARK: - Target muscles diagram (F-02)

    /// 「鍛える筋肉」セクション。primary を強くハイライト、secondary を薄くハイライト。
    /// CompactBodyDiagramView が表示専用なので、本 View は単に section header と組み合わせる。
    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.target-muscles")
                .font(.headline)

            CompactBodyDiagramView(
                primaryMuscles: Set([exercise.primaryMuscle]),
                secondaryMuscles: Set(exercise.secondaryMuscles)
            )
            .frame(maxHeight: 220)
        }
    }

    // MARK: - Description / Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.steps").font(.headline)

            if !descriptionHTML.isEmpty {
                // HTMLSanitizer 経由で <script> 等を除去 → AttributedString に変換して描画。
                // 失敗時は HTMLDescriptionView 内でプレーンテキストにフォールバックされる。
                HTMLDescriptionView(html: descriptionHTML)
                    .font(.body)
            }

            let stepList = stepTexts
            if !stepList.isEmpty {
                ForEach(Array(stepList.enumerated()), id: \.offset) { idx, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 24, alignment: .trailing)
                        Text(line)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var cautionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text("library.detail.cautions")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(cautions.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.orange)
                            .padding(.top, 7)
                        Text(line)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Muscle / Equipment badges

    private var muscleBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.primary-muscle").font(.headline)
            badge(LibraryDisplay.muscleName(exercise.primaryMuscle), tint: .accentColor)

            if !exercise.secondaryMuscles.isEmpty {
                Text("library.detail.secondary-muscles").font(.headline).padding(.top, 8)
                FlowLayoutWrap {
                    ForEach(exercise.secondaryMuscles, id: \.self) { m in
                        badge(LibraryDisplay.muscleName(m), tint: .secondary)
                    }
                }
            }
        }
    }

    private var equipmentBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.equipment").font(.headline)
            FlowLayoutWrap {
                ForEach(exercise.equipment, id: \.self) { eq in
                    Label {
                        Text(LibraryDisplay.equipmentName(eq))
                    } icon: {
                        Image(systemName: LibraryDisplay.equipmentSymbol(eq))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15), in: .capsule)
                }
            }
        }
    }

    private func badge(_ key: LocalizedStringKey, tint: Color) -> some View {
        Text(key)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint == .secondary ? Color.primary : .white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint == .secondary
                        ? AnyShapeStyle(Color.secondary.opacity(0.15))
                        : AnyShapeStyle(tint),
                        in: .capsule)
    }

    // MARK: - YouTube (Pro)

    @ViewBuilder
    private var youtubeButton: some View {
        if let query = exercise.youtubeSearchQuery, !query.isEmpty {
            let isUnlocked = dependency.proGate.check(.videoLink)
            Button {
                handleYouTubeTap(query: query)
            } label: {
                Label {
                    Text("library.detail.youtube")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: isUnlocked
                          ? "play.rectangle.fill"
                          : "lock.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel(Text("library.detail.youtube"))
            .accessibilityHint(Text(isUnlocked
                                    ? "a11y.library.youtube.unlocked.hint"
                                    : "a11y.library.youtube.locked.hint"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private func handleYouTubeTap(query: String) {
        guard dependency.proGate.check(.videoLink) else {
            showPaywall = true
            return
        }
        // CLAUDE.md NG リスト: ネットワーク通信は禁止だが「YouTube アプリへの
        // Deep Link は例外」。https URL を openURL に渡せば、YouTube アプリが
        // 入っていればアプリで開かれ、無ければ Safari で開かれる。
        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let url = components?.url else {
            Logger.app.error("Failed to build YouTube URL for query: \(query, privacy: .public)")
            return
        }
        openURL(url)
    }

    // MARK: - Localized accessors

    private var isJapanese: Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    private var displayName: String {
        isJapanese ? exercise.nameJa : exercise.nameEn
    }

    private var introduction: String {
        isJapanese ? exercise.introductionJa : exercise.introductionEn
    }

    private var descriptionHTML: String {
        isJapanese ? exercise.descriptionJa : exercise.descriptionEn
    }

    private var stepTexts: [String] {
        let raw = isJapanese ? exercise.stepTextJaRaw : exercise.stepTextEnRaw
        return Self.decodeStringArray(raw)
    }

    private var cautions: [String] {
        let raw = isJapanese ? exercise.cautionsJa : exercise.cautionsEn
        return raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Static helpers

    private static func decodeStringArray(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }
}

// FlowLayoutWrap は WorkoutKit/Shared/FlowLayoutWrap.swift に分離。
// ProPaywallPlaceholder は WorkoutKit/Features/Paywall/ProPaywallPlaceholder.swift に分離。
