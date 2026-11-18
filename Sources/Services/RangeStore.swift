import Foundation
import SwiftUI

@MainActor
final class RangeStore: ObservableObject {
    /// Key format: "\(position.rawValue)_\(situation.rawValue)" -> [HandCode: HandAction]
    @Published var customRanges: [String: [String: HandAction]] = [:]

    private let storageFileName = "custom_poker_ranges.json"

    init() {
        loadRanges()
        if customRanges.isEmpty {
            resetToYokosawaPreset()
        }
    }

    func key(position: PokerPosition, situation: PreflopSituation) -> String {
        "\(position.rawValue)_\(situation.rawValue)"
    }

    func action(for handCode: String, position: PokerPosition, situation: PreflopSituation) -> HandAction {
        let k = key(position: position, situation: situation)
        return customRanges[k]?[handCode] ?? .fold
    }

    func setAction(_ action: HandAction, for handCode: String, position: PokerPosition, situation: PreflopSituation) {
        let k = key(position: position, situation: situation)
        var table = customRanges[k] ?? [:]
        if action == .fold {
            table.removeValue(forKey: handCode)
        } else {
            table[handCode] = action
        }
        customRanges[k] = table
        saveRanges()
    }

    func cycleAction(for handCode: String, position: PokerPosition, situation: PreflopSituation) {
        let current = action(for: handCode, position: position, situation: situation)
        let next: HandAction
        switch current {
        case .fold: next = .raise
        case .raise: next = .call
        case .call: next = .fold
        }
        setAction(next, for: handCode, position: position, situation: situation)
    }

    func yokosawaTier(for handCode: String) -> YokosawaColorTier {
        if YokosawaPresetData.tier1Red.contains(handCode) { return .tier1Red }
        if YokosawaPresetData.tier2Yellow.contains(handCode) { return .tier2Yellow }
        if YokosawaPresetData.tier3Green.contains(handCode) { return .tier3Green }
        if YokosawaPresetData.tier4Blue.contains(handCode) { return .tier4Blue }
        if YokosawaPresetData.tier5Purple.contains(handCode) { return .tier5Purple }
        return .outOfRange
    }

    func rangePercentage(position: PokerPosition, situation: PreflopSituation) -> (raisePct: Double, callPct: Double) {
        let totalCombos = 1326.0
        var raiseCombos = 0.0
        var callCombos = 0.0
        let k = key(position: position, situation: situation)
        let table = customRanges[k] ?? [:]

        for (code, act) in table {
            let combos = Double(HandMatrixHelper.combinationsCount(for: code))
            if act == .raise { raiseCombos += combos }
            if act == .call { callCombos += combos }
        }
        return ((raiseCombos / totalCombos) * 100.0, (callCombos / totalCombos) * 100.0)
    }

    func resetToYokosawaPreset() {
        customRanges = YokosawaPresetData.buildDefaultRanges()
        saveRanges()
    }

    // MARK: - JSON Export / Import for Backup & Sharing
    func exportJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(customRanges),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    func importJSONString(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String: HandAction]].self, from: data) else {
            return false
        }
        customRanges = decoded
        saveRanges()
        return true
    }

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(storageFileName)
    }

    private func saveRanges() {
        guard let data = try? JSONEncoder().encode(customRanges) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func loadRanges() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: [String: HandAction]].self, from: data) else {
            return
        }
        customRanges = decoded
    }
}

/// 6-Max Cash / Ring Game Baseline modeled on Yokosawa Hand Range Tiers
struct YokosawaPresetData {
    // Tier 1 (赤): 最強プレミアム (全ポジションオープン & 3-Bet/4-Bet)
    static let tier1Red: Set<String> = [
        "AA", "KK", "QQ", "JJ", "AKs", "AKo"
    ]

    // Tier 2 (黄): UTGからオープン可能な強いハンド
    static let tier2Yellow: Set<String> = [
        "TT", "99", "88", "77",
        "AQs", "AJs", "ATs", "KQs", "KJs", "QJs", "JTs",
        "AQo"
    ]

    // Tier 3 (緑): HJ以降でオープン追加されるハンド
    static let tier3Green: Set<String> = [
        "66", "55",
        "A9s", "A8s", "A7s", "A5s", "A4s",
        "KTs", "QTs", "T9s", "98s", "87s",
        "AJo", "KQo"
    ]

    // Tier 4 (青): CO以降でオープン追加されるハンド
    static let tier4Blue: Set<String> = [
        "44", "33", "22",
        "A6s", "A3s", "A2s",
        "K9s", "K8s", "Q9s", "J9s", "76s", "65s", "54s",
        "ATo", "KJo", "QJo", "JTo"
    ]

    // Tier 5 (紫): BTN / SB スチール用ワイドレンジ
    static let tier5Purple: Set<String> = [
        "K7s", "K6s", "K5s", "K4s", "K3s", "K2s",
        "Q8s", "Q7s", "Q6s", "J8s", "J7s", "T8s", "T7s", "97s", "86s", "75s", "64s", "53s",
        "A9o", "A8o", "A7o", "A5o", "KTo", "K9o", "QTo", "Q9o", "J9o", "T9o"
    ]

    static func buildDefaultRanges() -> [String: [String: HandAction]] {
        var result: [String: [String: HandAction]] = [:]

        // 1. RFI (オープンレイズ)
        let utgRFI = tier1Red.union(tier2Yellow)
        let hjRFI = utgRFI.union(tier3Green)
        let coRFI = hjRFI.union(tier4Blue)
        let btnRFI = coRFI.union(tier5Purple)
        let sbRFI = coRFI.union(tier5Purple)

        result["\(PokerPosition.utg.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(utgRFI, .raise)
        result["\(PokerPosition.hj.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(hjRFI, .raise)
        result["\(PokerPosition.co.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(coRFI, .raise)
        result["\(PokerPosition.btn.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(btnRFI, .raise)
        result["\(PokerPosition.sb.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(sbRFI, .raise)
        // BB checks/raises vs limp (use BTN range as ISO-raise guide)
        result["\(PokerPosition.bb.rawValue)_\(PreflopSituation.rfi.rawValue)"] = mapAction(coRFI, .raise)

        // 2. vs Open (相手がオープンした時: 3-Bet or Call)
        for pos in PokerPosition.allCases {
            var table: [String: HandAction] = [:]
            switch pos {
            case .utg, .hj:
                // Tight 3-bet / flat
                for h in tier1Red.union(["AQs", "A5s"]) { table[h] = .raise }
                for h in ["TT", "99", "88", "AJs", "ATs", "KQs", "AQo"] { table[h] = .call }
            case .co, .btn:
                // IP 3-bet polar + solid call
                for h in tier1Red.union(["AQs", "AJs", "KQs", "A5s", "A4s", "AQo"]) { table[h] = .raise }
                for h in ["TT", "99", "88", "77", "66", "ATs", "KJs", "QJs", "JTs", "T9s", "98s", "AJo", "KQo"] {
                    table[h] = .call
                }
            case .sb:
                // SB 3-bet or fold strategy
                for h in tier1Red.union(["AQs", "AJs", "ATs", "KQs", "KJs", "QJs", "A5s", "AQo"]) {
                    table[h] = .raise
                }
                for h in ["TT", "99", "88"] {
                    table[h] = .call
                }
            case .bb:
                // BB wide defense (3-bet value/bluff + wide call)
                for h in tier1Red.union(["AQs", "AJs", "KQs", "A5s", "A4s", "K9s", "Q9s", "76s", "65s", "AQo"]) {
                    table[h] = .raise
                }
                let bbCalls = tier2Yellow.union(tier3Green).union(tier4Blue).subtracting(table.keys)
                for h in bbCalls {
                    table[h] = .call
                }
            }
            result["\(pos.rawValue)_\(PreflopSituation.vsOpen.rawValue)"] = table
        }

        // 3. vs 3-Bet (自分がオープンしてリレイズされた時: 4-Bet or Call)
        for pos in PokerPosition.allCases {
            var table: [String: HandAction] = [:]
            for h in ["AA", "KK", "QQ", "AKs", "AKo", "A5s"] {
                table[h] = .raise
            }
            for h in ["JJ", "TT", "99", "AQs", "AJs", "KQs", "QJs", "JTs", "AQo"] {
                table[h] = .call
            }
            result["\(pos.rawValue)_\(PreflopSituation.vs3Bet.rawValue)"] = table
        }

        return result
    }

    private static func mapAction(_ hands: Set<String>, _ action: HandAction) -> [String: HandAction] {
        var dict: [String: HandAction] = [:]
        for h in hands {
            dict[h] = action
        }
        return dict
    }
}
