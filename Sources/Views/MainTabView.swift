import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            QuickAdvisorView()
                .tabItem {
                    Label("即座に判定", systemImage: "suit.spade.fill")
                }

            RangeMatrixView()
                .tabItem {
                    Label("レンジ表・編集", systemImage: "square.grid.3x3.fill")
                }

            SettingsView()
                .tabItem {
                    Label("設定・データ", systemImage: "slider.horizontal.3")
                }
        }
    }
}
