// MARK: - AnnotatedFormView
// 実写写真の上に「正しいフォームの要点」を吹き出し付き引き出し線で重ねるビュー。
// プランクなら "首を自然に / 背中をまっすぐに / 腹と尻に力 / 肘を肩の真下に" のような
// 行動指針(キュー)を 3〜5 個、写真の被写体に合わせた正規化座標(0..1)に配置する。
//
// データは `Resources/FormAnnotations/<slug>-annotations.json` に外出ししており、
// 種目を増やすときは JSON を一枚足すだけで AnnotatedFormView が自動で表示する。
// 文字列は `LocalizedStringKey` 経由で `Localizable.xcstrings` に解決する。
//
// CLAUDE.md NG リスト準拠: 動画 mp4 不可だが静止画 JPEG は OK。本ビューは写真のみ使用。

import SwiftUI
import OSLog

// MARK: - Data model

/// JSON で記述するアノテーション 1 件。
/// `position` / `labelAnchor` ともに 0..1 の正規化座標。`color` は
/// 表示色のカテゴリ識別子で、実色は `FormPhotoAnnotationColor` の case で定義する(JSON側に
/// 16進RGBを書かせない: ロケール/ダークモードで色を差し替えやすくするため)。
struct FormAnnotation: Codable, Identifiable, Equatable {
    /// JSON 内ユニーク ID(slug 内)。
    let id: String
    /// 写真上のドット位置(x, y は 0..1)。
    let position: NormalizedPoint
    /// 吹き出しの中心位置(x, y は 0..1)。引き出し線はドット → この点を結ぶ。
    let labelAnchor: NormalizedPoint
    /// 吹き出しに表示する文言の Localizable キー。
    let labelKey: String
    /// 配色カテゴリ。
    let color: FormPhotoAnnotationColor

    enum CodingKeys: String, CodingKey {
        case id, position, labelAnchor, labelKey, color
    }
}

struct NormalizedPoint: Codable, Equatable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// 配色カテゴリ。実色は `FormPhotoAnnotationColor.tint` で SwiftUI Color に解決する。
/// JSON で 16進カラーをべた書きさせない方針。Light/Dark で同色だが、必要なら拡張する。
enum FormPhotoAnnotationColor: String, Codable, CaseIterable {
    case primary    // 主要キュー(オレンジ系=AccentColor)
    case info       // 補助情報(青系)
    case warning    // 注意(赤系)
    case neutral    // 中立(緑系、姿勢ガイド)

    var tint: Color {
        switch self {
        case .primary: return AppColor.accent
        // DesignTokens.AppColor に info/blue 系のセマンティックトークンが
        // 存在しないため、ここのみリテラルの青を維持する。新規トークンを
        // 追加する場合は DesignTokens.swift 側に一元化すること。
        case .info:    return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .warning: return AppColor.destructive
        case .neutral: return AppColor.success
        }
    }
}

/// 1 枚の写真(=1 フェーズ)を表すフレーム。
/// 例: スクワットの「スタート(立位)」「ボトム(しゃがみきり)」をそれぞれ 1 フレームとして持つ。
struct FormAnnotationFrame: Codable, Identifiable, Equatable {
    /// フレーム ID(slug 内ユニーク)。
    let id: String
    /// フェーズ名の Localizable キー(例: `form.phase.start` / `form.phase.bottom`)。
    let phaseLabelKey: String
    /// 紐付ける写真の Asset 名(`ExercisePhotos/<assetName>`)。
    let assetName: String
    /// 写真のアスペクト比(width / height)。レイアウト計算に使う。
    let aspect: Double
    let annotations: [FormAnnotation]

    enum CodingKeys: String, CodingKey {
        case id, phaseLabelKey, assetName, aspect, annotations
    }
}

/// `<slug>-annotations.json` のルート。
/// v1(レガシー)は `assetName` / `aspect` / `annotations` をルート直下に持つ単一フレーム形式。
/// v2 は `frames` 配列で複数フェーズ(スタート/ボトム等)を保持する。
/// デコード時にレガシー形式を検出したら `frames` 1 件(`phaseLabelKey = "form.phase.start"`)に
/// 変換して読み込むため、呼び出し側は常に `frames` だけを見ればよい。
struct FormAnnotationSet: Equatable {
    let slug: String
    let frames: [FormAnnotationFrame]
}

extension FormAnnotationSet: Codable {
    private enum CodingKeys: String, CodingKey {
        case slug, frames
        // レガシー(v1)フィールド。
        case assetName, aspect, annotations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slug = try container.decode(String.self, forKey: .slug)

        if let frames = try container.decodeIfPresent([FormAnnotationFrame].self, forKey: .frames) {
            self.slug = slug
            self.frames = frames
        } else {
            // レガシー形式: ルート直下の assetName/aspect/annotations を単一フレームへ移送。
            let assetName = try container.decode(String.self, forKey: .assetName)
            let aspect = try container.decode(Double.self, forKey: .aspect)
            let annotations = try container.decode([FormAnnotation].self, forKey: .annotations)
            self.slug = slug
            self.frames = [
                FormAnnotationFrame(
                    id: "\(slug)-legacy",
                    phaseLabelKey: "form.phase.start",
                    assetName: assetName,
                    aspect: aspect,
                    annotations: annotations
                )
            ]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slug, forKey: .slug)
        try container.encode(frames, forKey: .frames)
    }
}

// MARK: - Loader

enum FormAnnotationLoader {
    /// `<slug>-annotations.json` をメインバンドルから読み込む。
    /// 失敗時は nil(=従来表示にフォールバック)。
    static func load(slug: String, bundle: Bundle = .main) -> FormAnnotationSet? {
        let resource = "\(slug)-annotations"
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(FormAnnotationSet.self, from: data)
        } catch {
            Logger.app.error("Failed to load form annotations \(resource, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

// MARK: - View

/// 写真 + 吹き出しアノテーションのコンテナ。
/// `slug` から JSON を読み、見つからなければ何も描かない(=呼び出し側で if-let)。
/// `frames` が複数ある場合はセグメント付きピッカーでフェーズ(スタート/ボトム等)を切り替えられる。
struct AnnotatedFormView: View {
    // `set` という名前は computed property の setter キーワードと衝突する
    // (アクセサ内で行頭に置くとコンパイルエラー)ため annotationSet とする。
    let annotationSet: FormAnnotationSet

    @State private var selectedFrameID: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `slug` から初期化。対応 JSON が無い、またはフレームが 0 件の場合は nil を返すフェイルセーフ。
    init?(slug: String, bundle: Bundle = .main) {
        guard let s = FormAnnotationLoader.load(slug: slug, bundle: bundle),
              let firstFrame = s.frames.first else { return nil }
        self.annotationSet = s
        _selectedFrameID = State(initialValue: firstFrame.id)
    }

    init?(set: FormAnnotationSet) {
        guard let firstFrame = set.frames.first else { return nil }
        self.annotationSet = set
        _selectedFrameID = State(initialValue: firstFrame.id)
    }

    /// 現在選択中のフレーム。見つからない場合は先頭フレームにフォールバック。
    private var currentFrame: FormAnnotationFrame {
        annotationSet.frames.first { $0.id == selectedFrameID } ?? annotationSet.frames[0]
    }

    var body: some View {
        VStack(spacing: 8) {
            if annotationSet.frames.count > 1 {
                Picker(selection: $selectedFrameID) {
                    ForEach(annotationSet.frames) { frame in
                        Text(LocalizedStringKey(frame.phaseLabelKey)).tag(frame.id)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Image("ExercisePhotos/\(currentFrame.assetName)", bundle: .main)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id(currentFrame.id)
                        .transition(.opacity)

                    // 引き出し線 → ドット → ラベル を annotation ごとに描画。
                    // 線が円の上に乗らないよう、線→ドット→ラベル の順で重ねる。
                    // 線・ドットは純粋な装飾(情報はラベルの AnnotationCard 側にのみ
                    // ある)なので VoiceOver からは隠し、カードだけが読み上げられるようにする。
                    ForEach(currentFrame.annotations) { ann in
                        AnnotationLeaderLine(
                            from: ann.position.cgPoint,
                            to: ann.labelAnchor.cgPoint,
                            size: proxy.size,
                            color: ann.color.tint
                        )
                        .accessibilityHidden(true)
                    }
                    ForEach(currentFrame.annotations) { ann in
                        AnnotationDot(
                            position: ann.position.cgPoint,
                            size: proxy.size,
                            color: ann.color.tint
                        )
                        .accessibilityHidden(true)
                    }
                    ForEach(currentFrame.annotations) { ann in
                        AnnotationCard(
                            text: LocalizedStringKey(ann.labelKey),
                            anchor: ann.labelAnchor.cgPoint,
                            size: proxy.size,
                            color: ann.color.tint
                        )
                        .accessibilityLabel(Text(LocalizedStringKey(ann.labelKey)))
                    }
                }
                // reduce motion がオンの場合は即切り替え、オフならクロスフェード。
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedFrameID)
            }
            .aspectRatio(currentFrame.aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            // 人体図(AnnotatedBodyDiagramView)と同格の大型イラストカードなので
            // DesignTokens の "大型カード" 定義に合わせ AppRadius.hero を使う。
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
            // PremiumCardStyle.swift の "quiet luxury" 装飾(ヘアライン境界線 +
            // 外側シャドウ)を直下の BodySectionView/BodyDiagramView と同格で適用する。
            // premiumDiagramCard() 自体は padding を持たない(呼び出し側の裁量)ため、
            // 上の .clipShape で写真をぴったりトリムした後にこのまま重ねるだけで
            // 写真は edge-to-edge を保ったまま境界線・影だけが追加される
            // (新しい色・半径は増やさず、既存トークン AppRadius.hero を再利用)。
            .premiumDiagramCard(cornerRadius: AppRadius.hero)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Subviews

/// ドット(円形マーカー)。
private struct AnnotationDot: View {
    let position: CGPoint
    let size: CGSize
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            .position(x: position.x * size.width, y: position.y * size.height)
    }
}

/// ドット → ラベル を結ぶ細い引き出し線。
private struct AnnotationLeaderLine: View {
    let from: CGPoint
    let to: CGPoint
    let size: CGSize
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: from.x * size.width, y: from.y * size.height))
            path.addLine(to: CGPoint(x: to.x * size.width, y: to.y * size.height))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
    }
}

/// 吹き出し本体(角丸 + 影 + 色付き左ボーダー)。
///
/// 見切れ防止: アンカーはカードの「希望中心」でしかなく、カードの実サイズを
/// 計測した上で矩形全体が写真内(margin 4pt)に収まるよう中心を自動シフトする。
/// 端寄りアンカー(x=0.9 等)でもカード半分がはみ出さない。
/// tools/check_form_annotations.py が同じロジックで重なり・見切れを静的検査する
/// (レイアウト定数を変えるときは両方を更新すること)。
private struct AnnotationCard: View {
    let text: LocalizedStringKey
    let anchor: CGPoint
    let size: CGSize
    let color: Color

    /// 計測したカードの実サイズ。初回レイアウト後に確定する。
    @State private var cardSize: CGSize = .zero

    private static let margin: CGFloat = 4

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                    .stroke(color, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            // 横幅の上限を写真幅の 45% に縮め、長い文言は折り返す。
            .frame(maxWidth: size.width * 0.45, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            // 高密度オーバーレイのため拡大上限を設ける(本文のステップ解説は
            // 無制限のまま)。写真上に複数カードを重ねる都合上、文字を無制限に
            // 拡大すると tools/check_form_annotations.py が守るクランプ幅を
            // 超えてカード同士が重なる・見切れるため、意図的な例外として
            // ここだけ .large を上限にする。
            .dynamicTypeSize(...DynamicTypeSize.large)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                cardSize = newSize
            }
            .position(clampedCenter())
    }

    /// カード矩形が写真内に完全に収まるよう中心座標をクランプする。
    /// サイズ計測前(cardSize == .zero)は従来どおり 4pt クランプで近似。
    private func clampedCenter() -> CGPoint {
        let halfW = max(cardSize.width / 2, 0) + Self.margin
        let halfH = max(cardSize.height / 2, 0) + Self.margin
        let x = clamp(anchor.x * size.width,
                      lower: min(halfW, size.width / 2),
                      upper: max(size.width - halfW, size.width / 2))
        let y = clamp(anchor.y * size.height,
                      lower: min(halfH, size.height / 2),
                      upper: max(size.height - halfH, size.height / 2))
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Plank annotations") {
    if let set = FormAnnotationLoader.load(slug: "plank"), let view = AnnotatedFormView(set: set) {
        view
            .padding()
    } else {
        Text("plank-annotations.json not bundled in preview")
    }
}

#Preview("Reverse lunge (2 frames)") {
    if let set = FormAnnotationLoader.load(slug: "reverse-lunge"), let view = AnnotatedFormView(set: set) {
        view
            .padding()
    } else {
        Text("reverse-lunge-annotations.json not bundled in preview")
    }
}
#endif
