import SwiftUI

struct PushFoldView: View {
    @EnvironmentObject var store: RangeStore
    @State private var selectedPosition: PokerPosition = .btn
    @State private var stackBB: Double = 10

    private let quickStacks: [Int] = [15, 12, 10, 8, 6]

    private var pushPercentage: Double {
        var pushCombos = 0.0
        for r in 0..<13 {
            for c in 0..<13 {
                let code = HandMatrixHelper.handCode(row: r, col: c)
                if store.maxPushBB(for: code, position: selectedPosition) >= Int(stackBB) {
                    pushCombos += Double(HandMatrixHelper.combinationsCount(for: code))
                }
            }
        }
        return (pushCombos / 1326.0) * 100.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach([PokerPosition.utg, .hj, .co, .btn, .sb]) { pos in
                        Button {
                            selectedPosition = pos
                        } label: {
                            Text(pos.rawValue)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedPosition == pos ? Color.purple : Color(.secondarySystemBackground))
                                .foregroundColor(selectedPosition == pos ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    HStack {
                        Text("残りスタック: \(Int(stackBB)) BB")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(String(format: "PUSH率: %.1f%%", pushPercentage))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.18))
                            .foregroundColor(.purple)
                            .cornerRadius(6)
                    }

                    HStack(spacing: 6) {
                        ForEach(quickStacks, id: \.self) { bb in
                            Button {
                                stackBB = Double(bb)
                            } label: {
                                Text("\(bb)BB")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Int(stackBB) == bb ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundColor(Int(stackBB) == bb ? .white : .primary)
                                    .cornerRadius(6)
                            }
                        }
                    }

                    Slider(value: $stackBB, in: 3...20, step: 1)
                }
                .padding(.horizontal)

                GeometryReader { geo in
                    let spacing: CGFloat = 2
                    let totalSpacing = spacing * 12
                    let cellSize = max(15, (geo.size.width - 16 - totalSpacing) / 13)

                    VStack(spacing: spacing) {
                        ForEach(0..<13, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<13, id: \.self) { col in
                                    let code = HandMatrixHelper.handCode(row: row, col: col)
                                    let maxBB = store.maxPushBB(for: code, position: selectedPosition)
                                    let isPush = maxBB >= Int(stackBB)

                                    VStack(spacing: 0) {
                                        Text(code)
                                            .font(.system(size: max(7, cellSize * 0.30), weight: .bold, design: .rounded))
                                        Text("\(maxBB)")
                                            .font(.system(size: max(6, cellSize * 0.24), weight: .medium, design: .monospaced))
                                            .opacity(0.85)
                                    }
                                    .frame(width: cellSize, height: cellSize)
                                    .background(isPush ? Color.purple : Color(.systemGray5))
                                    .foregroundColor(isPush ? .white : .secondary)
                                    .cornerRadius(3)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 8)
            .navigationTitle("Push / Fold (Nash均衡)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
