// MARK: - ExerciseRowView
// CLAUDE.md §1.1 F-02。ExerciseListView のリスト行コンポーネント。
// 表示: 種目名 + 主部位ラベル + 器具アイコン群。
// 表示文字列はロケール依存(ja: nameJa、その他: nameEn)。

import SwiftUI

struct ExerciseRowView: View {
    let exercise: Exercise
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            mechanicsBadge
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(LibraryDisplay.muscleName(exercise.primaryMuscle))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !exercise.equipment.isEmpty {
                        equipmentIcons
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        locale.language.languageCode?.identifier == "ja"
            ? exercise.nameJa
            : exercise.nameEn
    }

    /// 器具を SF Symbol で並べる。最大3個まで。
    private var equipmentIcons: some View {
        HStack(spacing: 4) {
            ForEach(Array(exercise.equipment.prefix(3)), id: \.self) { eq in
                Image(systemName: LibraryDisplay.equipmentSymbol(eq))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(LibraryDisplay.equipmentName(eq)))
            }
            if exercise.equipment.count > 3 {
                Text("+\(exercise.equipment.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// COMPOUND / ISOLATION を一目で分かる小さなバッジに。
    @ViewBuilder
    private var mechanicsBadge: some View {
        switch exercise.mechanicsType {
        case .compound:
            Image(systemName: "circle.grid.2x2.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityLabel(Text("Compound"))
        case .isolation:
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
                .accessibilityLabel(Text("Isolation"))
        case .none:
            Image(systemName: "figure.cooldown")
                .foregroundStyle(.secondary)
                .font(.title3)
                .accessibilityHidden(true)
        }
    }
}
