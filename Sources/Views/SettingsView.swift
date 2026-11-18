import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var store: RangeStore
    @State private var showResetConfirm = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var statusBanner: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(YokosawaColorTier.allCases) { tier in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(tier.badgeColor)
                                .frame(width: 12, height: 12)
                            Text(tier.rawValue)
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("ヨコサワハンドレンジ 色分け基準")
                } footer: {
                    Text("初期状態では6-Maxリングゲームを基準としたヨコサワハンドレンジ準拠のプリセット（RFI / vs Open / vs 3-Bet）が設定されています。レンジ表画面から1マスずつ自由にカスタマイズ可能です。")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = store.exportJSONString()
                        showBanner("現在のレンジ設定(JSON)をコピーしました")
                    } label: {
                        Label("カスタムレンジをJSONでコピー", systemImage: "doc.on.doc")
                    }

                    Button {
                        importText = UIPasteboard.general.string ?? ""
                        showImportSheet = true
                    } label: {
                        Label("JSONからレンジを読み込む", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("バックアップ・共有")
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("ヨコサワハンドレンジ初期値にリセット", systemImage: "arrow.counterclockwise")
                    }
                }

                if let msg = statusBanner {
                    Section {
                        Text(msg)
                            .foregroundColor(.green)
                            .font(.subheadline.bold())
                    }
                }
            }
            .navigationTitle("設定・レンジ管理")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "すべてのポジションのレンジを初期値（ヨコサワハンドレンジ基準）に戻しますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセットする", role: .destructive) {
                    store.resetToYokosawaPreset()
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

    private func showBanner(_ text: String) {
        statusBanner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if statusBanner == text {
                statusBanner = nil
            }
        }
    }
}
