import SwiftUI

@main
struct PokerRangeAssistantApp: App {
    @StateObject private var store = RangeStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
        }
    }
}
