// MARK: - ShuffleMode
// CLAUDE.md §1.1 F-01a / workout-cool Issue #93 準拠。
// 「再生成」ボタン1つで WorkoutGenerator.generate を呼び直す。
//
// 設計メモ:
// - View は @Bindable BuilderStore を直接参照(ViewModel 禁止規約)。
// - randomSeed は BuilderStore.defaultInput が nil で初期化するため、本ボタン経由の
//   再生成は SystemRandomNumberGenerator が使われる(= 毎回違う出力になる)。
// - 進行中は ProgressView を出してボタンを disabled に。

import SwiftUI
import SwiftData

struct ShuffleMode: View {
    @Bindable var store: BuilderStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button(action: regenerate) {
            HStack {
                if store.isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "shuffle")
                }
                Text("builder.step.result.action.shuffle")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.gray.opacity(0.12))
            .foregroundStyle(Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(store.isGenerating)
    }

    private func regenerate() {
        store.regenerate(in: modelContext)
    }
}

#Preview {
    ShuffleMode(store: BuilderStore())
        .modelContainer(for: Exercise.self, inMemory: true)
        .padding()
}
