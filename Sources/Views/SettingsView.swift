import SwiftUI

// 旧バージョンのSettingsView.swiftが残っていてもビルドエラーにならないための互換View
struct SettingsView: View {
    var body: some View {
        PokerToolsView()
    }
}
