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
                targetMusclesSection
                if !descriptionHTML.isEmpty {
                    descriptionSection
                }
                StepsCardView(steps: stepLines)
                CommonMistakesCard(mistakes: commonMistakeLines)
                if !cautions.isEmpty {
                    cautionsSection
                }
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
            // P5 IAP の本実装(PaywallView)へ差し替え。
            // 旧 ProPaywallPlaceholder には購入導線が無く、Pro 化できなかった。
            PaywallView(reason: .videoLink)
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

    // MARK: - Target muscles diagram (F-02)

    /// 「鍛える筋肉」セクション。primary を強くハイライト、secondary を薄くハイライト。
    /// CompactBodyDiagramView が表示専用なので、本 View は単に section header と組み合わせる。
    private var targetMusclesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.target-muscles")
                .font(.headline)

            AnnotatedBodyDiagramView(
                primaryMuscles: Set([exercise.primaryMuscle]),
                secondaryMuscles: Set(exercise.secondaryMuscles),
                annotation: dependency.annotationLoader.load(slug: exercise.slug)
            )
        }
    }

    // MARK: - Description / Steps / Mistakes

    /// HTML description 単体のセクション。手順は StepsCardView に分離。
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // HTMLSanitizer 経由で <script> 等を除去 → AttributedString に変換して描画。
            // 失敗時は HTMLDescriptionView 内でプレーンテキストにフォールバックされる。
            HTMLDescriptionView(html: descriptionHTML)
                .font(.body)
        }
    }

    private var cautionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("library.detail.cautions", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(Array(cautions.enumerated()), id: \.offset) { _, line in
                Text("• \(line)")
                    .font(.body)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: .rect(cornerRadius: AppRadius.control))
    }

    // MARK: - Muscle / Equipment badges

    private var muscleBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("library.detail.primary-muscle").font(.headline)
            badge(LibraryDisplay.muscleName(exercise.primaryMuscle), tint: .accentColor)
            // 初心者向けに「その筋肉は何をする筋肉か」を一言添える。
            // キーは muscle.<rawValue>.description(他ワーカーが並行追加中)で、
            // rawValue を実行時に埋め込むため SessionView と同じ
            // String.LocalizationValue 経由のルックアップを使う。
            Text(primaryMuscleDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("library.detail.secondary-muscles").font(.headline).padding(.top, 8)
            if exercise.secondaryMuscles.isEmpty {
                // 104/345 種目は協働筋が無いが、セクション自体は残しつつ
                // 「協働筋なし」を明示する(見出しが唐突に消えるのを防ぐ)。
                Text("library.detail.secondary-muscles.none")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayoutWrap {
                    ForEach(exercise.secondaryMuscles, id: \.self) { m in
                        badge(LibraryDisplay.muscleName(m), tint: .secondary)
                    }
                }
            }
        }
    }

    /// 主動筋の初心者向け説明文。muscle.<rawValue>.description キーを
    /// 実行時に組み立てて解決する(SessionView.progressHeader と同じ手法)。
    private var primaryMuscleDescription: String {
        let key = "muscle.\(exercise.primaryMuscle.rawValue).description"
        return String(localized: String.LocalizationValue(key))
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
            .buttonStyle(.primaryCTA)
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

    private var stepLines: [String] {
        isJapanese ? exercise.stepsJa : exercise.stepsEn
    }

    private var commonMistakeLines: [String] {
        isJapanese ? exercise.commonMistakesJaList : exercise.commonMistakesEnList
    }

    private var cautions: [String] {
        let raw = isJapanese ? exercise.cautionsJa : exercise.cautionsEn
        return raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// FlowLayoutWrap は WorkoutKit/Shared/FlowLayoutWrap.swift に分離。
