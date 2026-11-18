import SwiftUI
import UIKit

struct PokerToolsView: View {
    @EnvironmentObject var store: RangeStore

    @State private var potSize: Double = 100
    @State private var betSize: Double = 50
    @State private var showResetConfirm = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var statusBanner: String? = nil

    private var requiredEquity: Double {
        guard (potSize + betSize * 2) > 0 else { return 0 }
        return (betSize / (potSize + betSize * 2)) * 100.0
    }

    private var mdfPercentage: Double {
        guard (potSize + betSize) > 0 else { return 0 }
        return (potSize / (potSize + betSize)) * 100.0
    }

    private var sprValue: Double {
        guard potSize > 0 else { return 0 }
        return 100.0 / potSize
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. Pot Odds & MDF Quick Calculator
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("ポット額: \(Int(potSize)) BB")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("相手のベット: \(Int(betSize)) BB")
                                .font(.subheadline.bold())
                        }

                        HStack(spacing: 6) {
                            presetRatioButton(label: "1/3 Pot", ratio: 0.33)
                            presetRatioButton(label: "1/2 Pot", ratio: 0.50)
                            presetRatioButton(label: "2/3 Pot", ratio: 0.67)
                            presetRatioButton(label: "Pot (100%)", ratio: 1.00)
                            presetRatioButton(label: "1.5x Pot", ratio: 1.50)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("必要勝率 (Pot Odds)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", requiredEquity))
                                    .font(.title2.bold())
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("最小防衛頻度 (MDF)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", mdfPercentage))
                                    .font(.title2.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("ポットオッズ & MDF 計算機")
                } footer: {
                    Text("相手のベットサイズをタップするだけで、コールに必要な勝率(Required Equity)とGTO上の最小ディフェンス頻度(MDF)を即座に計算します。")
                }

                // 2. Strategy Profiles Description
                Section {
                    ForEach(StrategyProfile.allCases) { prof in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(prof.rawValue)
                                    .font(.subheadline.bold())
                                if store.selectedProfile == prof {
                                    Spacer()
                                    Text("選択中")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }
                            Text(prof.descriptionText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectedProfile = prof
                        }
                    }
                } header: {
                    Text("搭載レンジプロファイル (タップで切替)")
                }

                // 3. Backup & Reset
                Section {
                    Button {
                        UIPasteboard.general.string = store.exportJSONString()
                        showBanner("全レンジ設定(JSON)をコピーしました")
                    } label: {
                        Label("カスタムレンジをJSONでコピー", systemImage: "doc.on.doc")
                    }

                    Button {
                        importText = UIPasteboard.general.string ?? ""
                        showImportSheet = true
                    } label: {
                        Label("JSONからレンジを読み込む", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("全プロファイルを初期値にリセット", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("データ管理・バックアップ")
                }

                if let msg = statusBanner {
                    Section {
                        Text(msg)
                            .foregroundColor(.green)
                            .font(.subheadline.bold())
                    }
                }
            }
            .navigationTitle("計算ツール・設定")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "すべてのプロファイルのレンジを初期値に戻しますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセットする", role: .destructive) {
                    store.resetAllProfilesToDefault()
                    showBanner("初期プリセットにリセットしました")
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showImportSheet) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("エクスポートしたJSONテキストを貼り付けてください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $importText)
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    .padding()
                    .navigationTitle("JSONインポート")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showImportSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("読み込む") {
                                if store.importJSONString(importText) {
                                    showBanner("レンジデータを読み込みました")
                                } else {
                                    showBanner("JSONの形式が正しくありません")
                                }
                                showImportSheet = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func presetRatioButton(label: String, ratio: Double) -> some View {
        Button {
            potSize = 100
            betSize = (100.0 * ratio).rounded()
        } label: {
            Text(label)
                .font(.caption2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func showBanner(_ text: String) {
        statusBanner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if statusBanner == text {
                statusBanner = nil
            }
        }
    }
}
