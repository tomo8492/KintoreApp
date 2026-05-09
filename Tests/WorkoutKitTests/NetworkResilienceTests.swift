// MARK: - NetworkResilienceTests
// CLAUDE.md §11.4 「ネットワーク通信は禁止(StoreKit + YouTube Deep Link は例外)」
// 規約のスクリーニング。
//
// 1. StoreKit が網羅的にエラー伝搬する: cachedProduct なしで purchase()/restore()
//    を呼んでも crash せず AppError.purchaseFailed を投げる。
// 2. YouTube Deep Link 用に組み立てる URL が encoding を破らない。
// 3. ソース木に URLSession / dataTask / HTTPClient が無い(オフライン重視設計)。
//    Bundle 資源側でも本体ターゲットには現れないはずなので、構造的に固定する。
//
// CLAUDE.md NG リスト:
//   - print 禁止、強制アンラップ禁止、.shared 禁止
//   - ユーザー向け文字列は Localizable.xcstrings 経由
//
// 既存 StoreKitClientTests は SKTestSession で正常系 + 払戻を網羅している。
// 本ファイルは「StoreKit Configuration が無い / 商品が見つからない」という
// オフライン相当の境界条件に絞る。

import Foundation
import Testing
@testable import WorkoutKit

@Suite("NetworkResilience")
struct NetworkResilienceTests {

    // MARK: - StoreKit graceful degradation

    /// StoreKit Configuration が無い環境(= simctl 直接起動など、Scheme の
    /// StoreKit Configuration が読まれない)では Product.products(for:) が
    /// 空配列を返す。`purchase()` は cachedProduct を取れず
    /// AppError.purchaseFailed を throw する想定。crash や hang はしない。
    @Test("存在しない productID で purchase() を呼ぶと AppError.purchaseFailed を投げる")
    func purchaseWithoutValidProductThrows() async throws {
        let gate = await MainActor.run { ProFeatureGate() }
        let client = StoreKitClient(
            proGate: gate,
            productIDs: ["com.tomo.workoutkit.does-not-exist"]
        )

        // start() は失敗してもアプリを止めない契約。完了するだけ。
        await client.start()
        let cached = await client.cachedProduct
        #expect(cached == nil, "Pro product must not be cached when productID does not exist")

        // purchase() は AppError.purchaseFailed を投げる。
        await #expect(throws: AppError.self) {
            _ = try await client.purchase()
        }

        // proGate は触られていない。
        let isPro = await MainActor.run { gate.isPro }
        #expect(isPro == false)
    }

    // 注: 「未購入で restore しても error にならず isPro=false のまま」相当の検証は
    // StoreKitClientTests.restoreWithoutAnyPurchase が SKTestSession で網羅済み。
    // 当初 NetworkResilienceTests でも同等のケースを書いたが、AppStore.sync() が
    // SKTestSession 無しの環境では実 Apple サーバを叩こうとして hang する
    // ため、本ファイルでは redundant + 不安定として削除する。

    // MARK: - YouTube URL construction

    /// ExerciseDetailView.handleYouTubeTap は URLComponents で
    /// `https://www.youtube.com/results?search_query=...` を組み立てる。
    /// 日本語クエリやスペースを含む文字列でも encoding が破綻しないことを確認する。
    /// (URLComponents の queryItems は内部で percent-encoding を担う。)
    @Test("YouTube 検索 URL が日本語/スペース/記号で正しく percent-encode される")
    func youtubeURLEncodesQueryProperly() throws {
        let queries = [
            "barbell back squat",
            "バーベルバックスクワット",
            "deadlift / RDL",
            "push-up + clap",
            "  leading and trailing spaces  ",
        ]
        for q in queries {
            var components = URLComponents(string: "https://www.youtube.com/results")
            components?.queryItems = [URLQueryItem(name: "search_query", value: q)]
            let url = try #require(components?.url)
            #expect(url.scheme == "https")
            #expect(url.host == "www.youtube.com")
            #expect(url.path == "/results")
            // クエリは存在するし、生 'search_query=' は壊れていない。
            let queryString = try #require(url.query)
            #expect(queryString.hasPrefix("search_query="))
        }
    }

    // MARK: - Source-tree structural guard

    /// 本体ソースに URLSession / dataTask / URLProtocol / HTTPClient のような
    /// 自前ネットワーク呼び出しが入っていないこと(オフライン重視設計)を、
    /// テストランタイムから機械的に検証する。違反するファイルが見つかったら
    /// 例外を残してリリース前に必ず止まるようにする。
    @Test("WorkoutKit 本体ソースに URLSession 系の使用が無い(オフライン重視設計)")
    func appCodeHasNoURLSessionCalls() throws {
        let appURL = try sourceRoot()
        var offenders: [String] = []
        let needles = [
            "URLSession.shared",
            "URLSession(",
            ".dataTask(",
            "URLProtocol",
            "HTTPClient",
        ]

        forEachSwiftFile(under: appURL) { url, contents in
            for needle in needles where contents.contains(needle) {
                offenders.append("\(url.path): contains \(needle)")
            }
        }

        let summary = offenders.joined(separator: "\n  ")
        #expect(
            offenders.isEmpty,
            Comment(rawValue: "Network APIs found in app sources — offline-first design violated:\n  " + summary)
        )
    }

    // MARK: - Helpers

    /// テストバイナリ → 該当 .swiftmodule からリポジトリの WorkoutKit/ ディレクトリを推定する。
    /// (CLAUDE.md は Bundle 同梱のフィクスチャを推奨しているが、構造ガードのため
    /// 例外的にソースツリーへ向ける。)
    private func sourceRoot() throws -> URL {
        // テストランタイムの cwd は xctestrun 起動時に DerivedData 配下になる。
        // 安定して WorkoutKit ソースを指すために `#filePath` から逆算する。
        let here = URL(fileURLWithPath: #filePath)
        // Tests/WorkoutKitTests/NetworkResilienceTests.swift -> ../../WorkoutKit
        let app = here
            .deletingLastPathComponent() // WorkoutKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("WorkoutKit", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: app.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw AppError.dataCorruption("WorkoutKit/ directory not reachable from \(here.path)")
        }
        return app
    }

    private func forEachSwiftFile(
        under root: URL,
        _ visit: (URL, String) -> Void
    ) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            visit(url, contents)
        }
    }
}
