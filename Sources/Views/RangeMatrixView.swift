import SwiftUI

struct RangeMatrixView: View {
    @EnvironmentObject var store: RangeStore

    @State private var selectedPosition: PokerPosition = .btn
    @State private var selectedSituation: PreflopSituation = .rfi
    @State private var selectedOpener: PokerPosition = .utg
    @State private var isEditMode: Bool = false
    @State private var selectedPaintAction: HandAction = .raise

    private var activeOpener: PokerPosition? {
        guard selectedSituation == .vsOpen, !selectedPosition.validOpenerPositions.isEmpty else {
            return nil
        }
        return selectedOpener
    }

    private var stats: (raisePct: Double, callPct: Double) {
        store.rangePercentage(position: selectedPosition, situation: selectedSituation, opener: activeOpener)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Strategy Profile Selector
                Picker("戦略", selection: $store.selectedProfile) {
                    ForEach(StrategyProfile.allCases) { prof in
                        Text(prof.shortTitle).tag(prof)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Hero Position Bar
                HStack(spacing: 4) {
                    ForEach(PokerPosition.allCases) { pos in
                        Button {
                            selectedPosition = pos
                            if let firstValid = pos.validOpenerPositions.first,
                               !pos.validOpenerPositions.contains(selectedOpener) {
                                selectedOpener = firstValid
                            }
                        } label: {
                            Text(pos.rawValue)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    selectedPosition == pos
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundColor(selectedPosition == pos ? .white : .primary)
                                .cornerRadius(7)
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

                if selectedSituation == .vsOpen && !selectedPosition.validOpenerPositions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Opener:")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            ForEach(selectedPosition.validOpenerPositions) { op in
                                Button {
                                    selectedOpener = op
                                } label: {
                                    Text("vs \(op.rawValue)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(selectedOpener == op ? Color.orange : Color(.secondarySystemBackground))
                                        .foregroundColor(selectedOpener == op ? .white : .primary)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Stats & Edit Toggle Bar
                HStack(spacing: 10) {
                    legendBadge(color: HandAction.raise.color, text: String(format: "RAISE %.1f%%", stats.raisePct))
                    legendBadge(color: HandAction.call.color, text: String(format: "CALL %.1f%%", stats.callPct))
                    Spacer()
                    Toggle("編集", isOn: $isEditMode)
                        .labelsHidden()
                    Text(isEditMode ? "編集中" : "閲覧")
                        .font(.caption2.bold())
                        .foregroundColor(isEditMode ? .orange : .secondary)
                }
                .padding(.horizontal)

                if isEditMode {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(HandAction.allCases) { act in
                                Button {
                                    selectedPaintAction = act
                                } label: {
                                    Text(act.shortBadge)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
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
                        }
                        .padding(.horizontal)
                    }
                }

                // 13x13 Hand Matrix Grid
                GeometryReader { geo in
                    let spacing: CGFloat = 2
                    let totalSpacing = spacing * 12
                    let cellSize = max(15, (geo.size.width - 16 - totalSpacing) / 13)

                    VStack(spacing: spacing) {
                        ForEach(0..<13, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<13, id: \.self) { col in
                                    let code = HandMatrixHelper.handCode(row: row, col: col)
                                    let act = store.action(
                                        for: code,
                                        position: selectedPosition,
                                        situation: selectedSituation,
                                        opener: activeOpener
                                    )

                                    Button {
                                        if isEditMode {
                                            store.setAction(
                                                selectedPaintAction,
                                                for: code,
                                                position: selectedPosition,
                                                situation: selectedSituation,
                                                opener: activeOpener
                                            )
                                        } else {
                                            store.cycleAction(
                                                for: code,
                                                position: selectedPosition,
                                                situation: selectedSituation,
                                                opener: activeOpener
                                            )
                                        }
                                    } label: {
                                        Text(code)
                                            .font(.system(size: max(8, cellSize * 0.34), weight: .bold, design: .rounded))
                                            .minimumScaleFactor(0.55)
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
            .padding(.top, 6)
            .navigationTitle("13×13 レンジ表")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func legendBadge(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.caption2.bold())
        }
    }
}
