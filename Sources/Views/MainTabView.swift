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
                    Label("レンジ表・GTO", systemImage: "square.grid.3x3.fill")
                }

            PushFoldView()
                .tabItem {
                    Label("Push/Fold", systemImage: "flame.fill")
                }

            PokerToolsView()
                .tabItem {
                    Label("オッズ計算・設定", systemImage: "function")
                }
        }
    }
}
