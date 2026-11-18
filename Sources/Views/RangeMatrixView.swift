import SwiftUI

struct RangeMatrixView: View {
    @EnvironmentObject var store: RangeStore

    @State private var selectedPosition: PokerPosition = .btn
    @State private var selectedSituation: PreflopSituation = .rfi
    @State private var isEditMode: Bool = false
    @State private var selectedPaintAction: HandAction = .raise

    private var stats: (raisePct: Double, callPct: Double) {
        store.rangePercentage(position: selectedPosition, situation: selectedSituation)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Position Bar
                HStack(spacing: 4) {
                    ForEach(PokerPosition.allCases) { pos in
                        Button {
                            selectedPosition = pos
                        } label: {
                            Text(pos.rawValue)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    selectedPosition == pos
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundColor(selectedPosition == pos ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                // Situation Picker
                Picker("状況", selection: $selectedSituation) {
                    ForEach(PreflopSituation.allCases) { sit in
                        Text(sit.shortName).tag(sit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Stats & Legend Bar
                HStack(spacing: 12) {
                    legendBadge(color: HandAction.raise.color, text: String(format: "RAISE %.1f%%", stats.raisePct))
                    legendBadge(color: HandAction.call.color, text: String(format: "CALL %.1f%%", stats.callPct))
                    Spacer()
                    Toggle("編集", isOn: $isEditMode)
                        .labelsHidden()
                    Text(isEditMode ? "編集中" : "閲覧")
                        .font(.caption.bold())
                        .foregroundColor(isEditMode ? .orange : .secondary)
                }
                .padding(.horizontal)

                if isEditMode {
                    HStack(spacing: 8) {
                        Text("タップで塗る:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(HandAction.allCases) { act in
                            Button {
                                selectedPaintAction = act
                            } label: {
                                Text(act.shortBadge)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(act.color)
                                    .foregroundColor(act.textColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.primary, lineWidth: selectedPaintAction == act ? 2 : 0)
                                    )
                                    .cornerRadius(6)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // 13x13 Hand Matrix Grid
                GeometryReader { geo in
                    let spacing: CGFloat = 2
                    let totalSpacing = spacing * 12
                    let cellSize = max(16, (geo.size.width - 16 - totalSpacing) / 13)

                    VStack(spacing: spacing) {
                        ForEach(0..<13, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<13, id: \.self) { col in
                                    let code = HandMatrixHelper.handCode(row: row, col: col)
                                    let act = store.action(for: code, position: selectedPosition, situation: selectedSituation)

                                    Button {
                                        if isEditMode {
                                            store.setAction(selectedPaintAction, for: code, position: selectedPosition, situation: selectedSituation)
                                        } else {
                                            store.cycleAction(for: code, position: selectedPosition, situation: selectedSituation)
                                        }
                                    } label: {
                                        Text(code)
                                            .font(.system(size: max(8, cellSize * 0.34), weight: .bold, design: .rounded))
                                            .minimumScaleFactor(0.6)
                                            .lineLimit(1)
                                            .frame(width: cellSize, height: cellSize)
                                            .background(act.color)
                                            .foregroundColor(act.textColor)
                                            .cornerRadius(3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 8)
            .navigationTitle("13×13 レンジ表")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func legendBadge(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption.bold())
        }
    }
}
