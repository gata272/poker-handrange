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

    private let quickStacks: [Double] = [10, 15, 25, 40, 100, 150]
    private let openSizes: [Double] = [2.0, 2.5, 3.0, 4.0]

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

    private var advice: DynamicAdviceResult {
        store.evaluateDynamicAdvice(
            for: currentHandCode,
            position: selectedPosition,
            situation: selectedSituation,
            opener: activeOpener
        )
    }

    private var rngResolvedAction: HandAction {
        advice.action.resolveWithRNG(store.rngValue)
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

                    // 1. Recommended Action Banner + Sizing + Stack Reason
                    actionResultCard

                    // 2. Stack Size & Table Environment Controls
                    stackControlSection

                    // 3. Hero Position Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("2. 自分のポジション (Hero)")
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

                    // 4. Situation Selector & Opener Position / Sizing
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. 現在の状況 (アクション)")
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

                    // 5. Two-Tap Card Rank Picker
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("4. 配られたハンドを選択")
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

    private var stackControlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("1. 実効スタック: \(Int(store.effectiveStackBB)) BB")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("アンティ有", isOn: $store.hasAnte)
                    .font(.caption2.bold())
                    .fixedSize()
            }

            // Quick Stack Preset Buttons
            HStack(spacing: 5) {
                ForEach(quickStacks, id: \.self) { bb in
                    Button {
                        triggerHaptic()
                        store.effectiveStackBB = bb
                    } label: {
                        Text("\(Int(bb))BB")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Int(store.effectiveStackBB) == Int(bb)
                                    ? Color.purple
                                    : Color(.systemBackground)
                            )
                            .foregroundColor(Int(store.effectiveStackBB) == Int(bb) ? .white : .primary)
                            .cornerRadius(7)
                    }
                }
            }

            HStack(spacing: 10) {
                Slider(value: $store.effectiveStackBB, in: 5...200, step: 1)
                Text("Open額:")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Picker("Open額", selection: $store.openRaiseSizeBB) {
                    ForEach(openSizes, id: \.self) { sz in
                        Text(String(format: "%.1fBB", sz)).tag(sz)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var actionResultCard: some View {
        let act = advice.action
        let freq = act.frequencies
        let maxBB = store.maxPushBB(for: currentHandCode, position: selectedPosition)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(advice.stackZoneLabel) • \(selectedPosition.rawValue) / \(selectedSituation.shortName)")
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
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(act.shortBadge)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text("推奨サイズ: \(advice.sizingText)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                Spacer()
            }

            // Dynamic Stack Reason Text
            Text(advice.reasonText)
                .font(.caption2)
                .opacity(0.95)
                .fixedSize(horizontal: false, vertical: true)

            // GTO Frequency Bar + RNG Roll Button
            HStack(spacing: 8) {
                Text("R:\(freq.raise)% C:\(freq.call)% F:\(freq.fold)%")
                    .font(.caption2.monospaced().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(6)

                Text("Nash上限: \(maxBB)BB")
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
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(act.color)
        .foregroundColor(act.textColor)
        .cornerRadius(18)
        .shadow(color: act.color.opacity(0.32), radius: 8, y: 4)
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
