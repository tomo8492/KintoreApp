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
/// 表示色のカテゴリ識別子で、実色は `AnnotationColor` の case で定義する(JSON側に
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
    let color: AnnotationColor

    enum CodingKeys: String, CodingKey {
        case id, position, labelAnchor, labelKey, color
    }
}

struct NormalizedPoint: Codable, Equatable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// 配色カテゴリ。実色は `AnnotationColor.tint` で SwiftUI Color に解決する。
/// JSON で 16進カラーをべた書きさせない方針。Light/Dark で同色だが、必要なら拡張する。
enum AnnotationColor: String, Codable, CaseIterable {
    case primary    // 主要キュー(オレンジ系=AccentColor)
    case info       // 補助情報(青系)
    case warning    // 注意(赤系)
    case neutral    // 中立(緑系、姿勢ガイド)

    var tint: Color {
        switch self {
        case .primary: return Color.accentColor
        case .info:    return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .warning: return Color(red: 0.92, green: 0.30, blue: 0.27)
        case .neutral: return Color(red: 0.20, green: 0.65, blue: 0.45)
        }
    }
}

/// `<slug>-annotations.json` のルート。
struct FormAnnotationSet: Codable, Equatable {
    let slug: String
    /// 紐付ける写真の Asset 名(`ExercisePhotos/<assetName>`)。
    let assetName: String
    /// 写真のアスペクト比(width / height)。レイアウト計算に使う。
    let aspect: Double
    let annotations: [FormAnnotation]
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
struct AnnotatedFormView: View {
    let set: FormAnnotationSet

    @Environment(\.colorScheme) private var colorScheme

    /// `slug` から初期化。対応 JSON が無い場合は nil を返すフェイルセーフ。
    init?(slug: String, bundle: Bundle = .main) {
        guard let s = FormAnnotationLoader.load(slug: slug, bundle: bundle) else { return nil }
        self.set = s
    }

    init(set: FormAnnotationSet) {
        self.set = set
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image("ExercisePhotos/\(set.assetName)", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // 引き出し線 → ドット → ラベル を annotation ごとに描画。
                // 線が円の上に乗らないよう、線→ドット→ラベル の順で重ねる。
                ForEach(set.annotations) { ann in
                    AnnotationLeaderLine(
                        from: ann.position.cgPoint,
                        to: ann.labelAnchor.cgPoint,
                        size: proxy.size,
                        color: ann.color.tint
                    )
                }
                ForEach(set.annotations) { ann in
                    AnnotationDot(
                        position: ann.position.cgPoint,
                        size: proxy.size,
                        color: ann.color.tint
                    )
                }
                ForEach(set.annotations) { ann in
                    AnnotationCard(
                        text: LocalizedStringKey(ann.labelKey),
                        anchor: ann.labelAnchor.cgPoint,
                        size: proxy.size,
                        color: ann.color.tint
                    )
                    .accessibilityLabel(Text(LocalizedStringKey(ann.labelKey)))
                }
            }
        }
        .aspectRatio(set.aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
private struct AnnotationCard: View {
    let text: LocalizedStringKey
    let anchor: CGPoint
    let size: CGSize
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            // 横幅の上限を写真幅の 45% に縮め、長い文言は折り返す。
            .frame(maxWidth: size.width * 0.45, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .position(
                x: clamp(anchor.x * size.width, lower: 4, upper: size.width - 4),
                y: clamp(anchor.y * size.height, lower: 4, upper: size.height - 4)
            )
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Plank annotations") {
    if let set = FormAnnotationLoader.load(slug: "plank") {
        AnnotatedFormView(set: set)
            .padding()
    } else {
        Text("plank-annotations.json not bundled in preview")
    }
}
#endif
