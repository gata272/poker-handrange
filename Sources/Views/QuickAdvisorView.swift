import SwiftUI
import UIKit

struct QuickAdvisorView: View {
    @EnvironmentObject var store: RangeStore

    @State private var selectedPosition: PokerPosition = .btn
    @State private var selectedSituation: PreflopSituation = .rfi
    @State private var firstRank: CardRank = .ace
    @State private var secondRank: CardRank = .king
    @State private var isSuited: Bool = true

    private var isPair: Bool {
        firstRank == secondRank
    }

    private var currentHandCode: String {
        HandMatrixHelper.formatHand(rank1: firstRank, rank2: secondRank, isSuited: isSuited)
    }

    private var recommendedAction: HandAction {
        store.action(for: currentHandCode, position: selectedPosition, situation: selectedSituation)
    }

    private var handTier: YokosawaColorTier {
        store.yokosawaTier(for: currentHandCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Recommended Action Banner (Instant Decision Card)
                    actionResultCard

                    // 2. Position Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 自分のポジション")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(PokerPosition.allCases) { pos in
                                Button {
                                    triggerHaptic()
                                    selectedPosition = pos
                                } label: {
                                    Text(pos.rawValue)
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedPosition == pos
                                                ? Color.accentColor
                                                : Color(.secondarySystemBackground)
                                        )
                                        .foregroundColor(selectedPosition == pos ? .white : .primary)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }

                    // 3. Situation Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2. 現在の状況 (アクション)")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        Picker("状況", selection: $selectedSituation) {
                            ForEach(PreflopSituation.allCases) { sit in
                                Text(sit.shortName).tag(sit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedSituation) { _ in
                            triggerHaptic()
                        }
                    }

                    // 4. Two-Tap Card Rank Picker
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("3. 配られたハンドを選択")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            if !isPair {
                                Picker("スート", selection: $isSuited) {
                                    Text("スーテッド (s)").tag(true)
                                    Text("オフスート (o)").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 210)
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
                    .padding()
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
        VStack(spacing: 10) {
            HStack {
                Text("\(selectedPosition.rawValue) / \(selectedSituation.shortName)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)

                Spacer()

                Text(handTier.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
            }

            HStack(alignment: .center, spacing: 16) {
                Text(currentHandCode)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.18))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendedAction.shortBadge)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text(recommendedAction.displayLabel)
                        .font(.subheadline.bold())
                        .opacity(0.92)
                }
                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(recommendedAction.color)
        .foregroundColor(recommendedAction.textColor)
        .cornerRadius(18)
        .shadow(color: recommendedAction.color.opacity(0.35), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.15), value: currentHandCode)
        .animation(.easeInOut(duration: 0.15), value: recommendedAction)
    }

    private func rankRow(title: String, selection: Binding<CardRank>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(CardRank.allCases) { rank in
                    Button {
                        triggerHaptic()
                        selection.wrappedValue = rank
                    } label: {
                        Text(rank.symbol)
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
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
