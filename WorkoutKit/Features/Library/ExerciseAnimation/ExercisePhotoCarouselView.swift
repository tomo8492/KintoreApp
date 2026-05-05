// MARK: - ExercisePhotoCarouselView
// 5 種目分の Pexels フリー写真(CC0 相当・帰属任意)を自動切替カルーセルで表示。
// CLAUDE.md §-1 Lock により動画 mp4 は同梱不可だが、静止画 JPEG は OK。
//
// 写真は `WorkoutKit/Resources/Assets.xcassets/ExercisePhotos/<slug>-<n>.imageset/`
// に "ExercisePhotos" namespace 付きで配置。出典は THIRD_PARTY_NOTICES.md に
// 全件記載。`accessibilityReduceMotion` ON 時は自動切替を停止して 1 枚目で固定。

import SwiftUI

/// カルーセル対応スラグ → 写真ファイル名(ExercisePhotos namespace 内)。
enum ExercisePhotoSet: String, CaseIterable {
    case pushup
    case squat
    case plank
    case lunge
    case burpee

    /// seed の slug → set マッピング(ExerciseAnimationKind.from と同じ規約)。
    static func from(slug: String) -> ExercisePhotoSet? {
        switch slug {
        case "push-up": return .pushup
        case "air-squat": return .squat
        case "plank": return .plank
        case "reverse-lunge": return .lunge
        case "burpee": return .burpee
        default: return nil
        }
    }

    /// Asset Catalog の "ExercisePhotos/<name>" namespace に同梱した画像名一覧。
    /// 順序がそのままカルーセルの再生順になる。MANIFEST.json と同期すること。
    var assetNames: [String] {
        switch self {
        case .pushup:
            return ["push-up-1", "push-up-2", "push-up-3", "push-up-4", "push-up-5"]
        case .squat:
            return ["air-squat-1", "air-squat-2", "air-squat-3", "air-squat-4", "air-squat-5"]
        case .plank:
            return ["plank-1", "plank-2", "plank-4", "plank-5"]
        case .lunge:
            return ["reverse-lunge-1", "reverse-lunge-2", "reverse-lunge-3", "reverse-lunge-4"]
        case .burpee:
            return ["burpee-1"]
        }
    }

    /// VoiceOver 読み上げ用キー(既存 ExerciseAnimationView と共有)。
    var accessibilityKey: LocalizedStringKey {
        switch self {
        case .pushup: return "library.detail.animation.a11y.push-up"
        case .squat:  return "library.detail.animation.a11y.air-squat"
        case .plank:  return "library.detail.animation.a11y.plank"
        case .lunge:  return "library.detail.animation.a11y.reverse-lunge"
        case .burpee: return "library.detail.animation.a11y.burpee"
        }
    }
}

struct ExercisePhotoCarouselView: View {
    let set: ExercisePhotoSet

    /// 1枚あたりの表示時間(秒)。
    private let interval: TimeInterval = 2.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var timer: Timer?

    init?(slug: String) {
        guard let s = ExercisePhotoSet.from(slug: slug) else { return nil }
        self.set = s
    }

    init(set: ExercisePhotoSet) {
        self.set = set
    }

    var body: some View {
        let names = set.assetNames
        TabView(selection: $currentIndex) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Image("ExercisePhotos/\(name)", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: names.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .aspectRatio(1.6, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(set.accessibilityKey))
        .accessibilityValue(Text("library.detail.photo.index \(currentIndex + 1) \(names.count)"))
        .accessibilityAddTraits(.isImage)
        .onAppear { startAutoAdvance(count: names.count) }
        .onDisappear { stopAutoAdvance() }
        .onChange(of: reduceMotion) { _, _ in
            stopAutoAdvance()
            startAutoAdvance(count: names.count)
        }
    }

    private func startAutoAdvance(count: Int) {
        // 1枚しか無い、または Reduce Motion ON の場合は自動再生しない。
        guard count > 1, !reduceMotion else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentIndex = (currentIndex + 1) % count
                }
            }
        }
    }

    private func stopAutoAdvance() {
        timer?.invalidate()
        timer = nil
    }
}

#if DEBUG
#Preview("All photo carousels") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(ExercisePhotoSet.allCases, id: \.self) { s in
                ExercisePhotoCarouselView(set: s)
            }
        }
        .padding()
    }
}
#endif
