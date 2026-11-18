import SwiftUI
import UIKit

struct QuickAdvisorView: View {
    @EnvironmentObject var store: RangeStore

    @State private var selectedPosition: PokerPosition = .btn
    @State private var selectedSituation: PreflopSituation = .rfi
    @State private var selectedOpener: PokerPosition = .utg
    @State private var firstRank: CardRank = .ace
    @State private var secondRank: CardRank = .king
    @State private var isSuited: Bool = true

    private var isPair: Bool { firstRank == secondRank }

    private var currentHandCode: String {
        HandMatrixHelper.formatHand(rank1: firstRank, rank2: secondRank, isSuited: isSuited)
    }

    private var activeOpener: PokerPosition? {
        guard selectedSituation == .vsOpen, !selectedPosition.validOpenerPositions.isEmpty else {
            return nil
        }
        return selectedOpener
    }

    private var recommendedAction: HandAction {
        store.action(
            for: currentHandCode,
            position: selectedPosition,
            situation: selectedSituation,
            opener: activeOpener
        )
    }

    private var rngResolvedAction: HandAction {
        recommendedAction.resolveWithRNG(store.rngValue)
    }

    private var handTier: YokosawaColorTier {
        store.yokosawaTier(for: currentHandCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // 0. Strategy Profile Bar
                    Picker("戦略プロファイル", selection: $store.selectedProfile) {
                        ForEach(StrategyProfile.allCases) { prof in
                            Text(prof.shortTitle).tag(prof)
                        }
                    }
                    .pickerStyle(.segmented)

                    // 1. Recommended Action Banner + GTO RNG
                    actionResultCard

                    // 2. Hero Position Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. 自分のポジション (Hero)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(PokerPosition.allCases) { pos in
                                Button {
                                    triggerHaptic()
                                    selectedPosition = pos
                                    if let firstValid = pos.validOpenerPositions.first,
                                       !pos.validOpenerPositions.contains(selectedOpener) {
                                        selectedOpener = firstValid
                                    }
                                } label: {
                                    Text(pos.rawValue)
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedPosition == pos
                                                ? Color.accentColor
                                                : Color(.secondarySystemBackground)
                                        )
                                        .foregroundColor(selectedPosition == pos ? .white : .primary)
                                        .cornerRadius(9)
                                }
                            }
                        }
                    }

                    // 3. Situation Selector & Opener Position (when vs Open)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2. 現在の状況 (アクション)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Picker("状況", selection: $selectedSituation) {
                            ForEach(PreflopSituation.allCases) { sit in
                                Text(sit.shortName).tag(sit)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedSituation == .vsOpen && !selectedPosition.validOpenerPositions.isEmpty {
                            HStack(spacing: 6) {
                                Text("誰がオープン:")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                ForEach(selectedPosition.validOpenerPositions) { op in
                                    Button {
                                        triggerHaptic()
                                        selectedOpener = op
                                    } label: {
                                        Text("vs \(op.rawValue)")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                selectedOpener == op
                                                    ? Color.orange
                                                    : Color(.secondarySystemBackground)
                                            )
                                            .foregroundColor(selectedOpener == op ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // 4. Two-Tap Card Rank Picker
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("3. 配られたハンドを選択")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            if !isPair {
                                Picker("スート", selection: $isSuited) {
                                    Text("スーテッド (s)").tag(true)
                                    Text("オフスート (o)").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                            } else {
                                Text("ポケットペア")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }
                        }

                        rankRow(title: "1枚目", selection: $firstRank)
                        rankRow(title: "2枚目", selection: $secondRank)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .padding()
            }
            .navigationTitle("プリフロップ判定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var actionResultCard: some View {
        let freq = recommendedAction.frequencies
        let maxBB = store.maxPushBB(for: currentHandCode, position: selectedPosition)

        return VStack(spacing: 10) {
            HStack {
                Text("\(store.selectedProfile.shortTitle) • \(selectedPosition.rawValue) / \(selectedSituation.shortName)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(6)

                Spacer()

                Text(handTier.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(6)
            }

            HStack(alignment: .center, spacing: 14) {
                Text(currentHandCode)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendedAction.shortBadge)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text(recommendedAction.displayLabel)
                        .font(.caption.bold())
                        .opacity(0.92)
                }
                Spacer()
            }

            // GTO Frequency Bar + RNG Roll Button
            HStack(spacing: 10) {
                Text("R:\(freq.raise)% C:\(freq.call)% F:\(freq.fold)%")
                    .font(.caption2.monospaced().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(6)

                Text("Push上限: \(maxBB)BB")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(6)

                Spacer()

                Button {
                    triggerHaptic()
                    store.rollRNG()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                        Text("乱数 \(store.rngValue) → \(rngResolvedAction.shortBadge)")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.24))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(recommendedAction.color)
        .foregroundColor(recommendedAction.textColor)
        .cornerRadius(18)
        .shadow(color: recommendedAction.color.opacity(0.32), radius: 8, y: 4)
    }

    private func rankRow(title: String, selection: Binding<CardRank>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(CardRank.allCases) { rank in
                    Button {
                        triggerHaptic()
                        selection.wrappedValue = rank
                    } label: {
                        Text(rank.symbol)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                selection.wrappedValue == rank
                                    ? Color.accentColor
                                    : Color(.systemBackground)
                            )
                            .foregroundColor(selection.wrappedValue == rank ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
