// MARK: - WorkoutKitUITestsPlaceholder
// CLAUDE.md §9 準拠。UI テストは Phase P3 以降で本格実装する。
// 本ファイルはターゲットを成立させるための空ケース。
//
// XCUITest は依然 XCTest 上に乗っているため、ここだけは XCTest を使う(§11.4 NG リストの除外対象)。

import XCTest

final class WorkoutKitUITestsPlaceholder: XCTestCase {
    /// 起動だけ確認するスモーク。クラッシュ検出が目的。
    /// Phase P3 以降で Builder ウィザードのフロー検証に置き換える。
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }
}
