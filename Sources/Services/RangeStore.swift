import Foundation
import SwiftUI

@MainActor
final class RangeStore: ObservableObject {
    @Published var selectedProfile: StrategyProfile = .gto100bb
    /// Key format: "\(profile.rawValue)|\(heroPos.rawValue)|\(situation.rawValue)|\(villainPos?.rawValue ?? "ANY")"
    @Published var customRanges: [String: [String: HandAction]] = [:]
    @Published var rngValue: Int = Int.random(in: 1...100)

    private let storageFileName = "custom_poker_ranges_v2.json"

    init() {
        loadRanges()
        if customRanges.isEmpty {
            resetAllProfilesToDefault()
        }
    }

    func rollRNG() {
        rngValue = Int.random(in: 1...100)
    }

    func makeKey(
        profile: StrategyProfile,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) -> String {
        let openerTag: String
        if situation == .vsOpen, let op = opener, op.orderIndex < position.orderIndex {
            openerTag = op.rawValue
        } else {
            openerTag = "ANY"
        }
        return "\(profile.rawValue)|\(position.rawValue)|\(situation.rawValue)|\(openerTag)"
    }

    func action(
        for handCode: String,
        profile: StrategyProfile? = nil,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) -> HandAction {
        let prof = profile ?? selectedProfile
        let exactKey = makeKey(profile: prof, position: position, situation: situation, opener: opener)
        if let table = customRanges[exactKey], let act = table[handCode] {
            return act
        }
        let fallbackKey = makeKey(profile: prof, position: position, situation: situation, opener: nil)
        return customRanges[fallbackKey]?[handCode] ?? .fold
    }

    func setAction(
        _ action: HandAction,
        for handCode: String,
        profile: StrategyProfile? = nil,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) {
        let prof = profile ?? selectedProfile
        let k = makeKey(profile: prof, position: position, situation: situation, opener: opener)
        var table = customRanges[k] ?? [:]
        if action == .fold {
            table.removeValue(forKey: handCode)
        } else {
            table[handCode] = action
        }
        customRanges[k] = table
        saveRanges()
    }

    func cycleAction(
        for handCode: String,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) {
        let current = action(for: handCode, position: position, situation: situation, opener: opener)
        let order: [HandAction] = [.fold, .raise, .mixedRaiseCall, .call, .allIn]
        let nextIndex = ((order.firstIndex(of: current) ?? 0) + 1) % order.count
        setAction(order[nextIndex], for: handCode, position: position, situation: situation, opener: opener)
    }

    func yokosawaTier(for handCode: String) -> YokosawaColorTier {
        if PresetRangeBuilder.tier1Red.contains(handCode) { return .tier1Red }
        if PresetRangeBuilder.tier2Yellow.contains(handCode) { return .tier2Yellow }
        if PresetRangeBuilder.tier3Green.contains(handCode) { return .tier3Green }
        if PresetRangeBuilder.tier4Blue.contains(handCode) { return .tier4Blue }
        if PresetRangeBuilder.tier5Purple.contains(handCode) { return .tier5Purple }
        return .outOfRange
    }

    func rangePercentage(
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) -> (raisePct: Double, callPct: Double) {
        let totalCombos = 1326.0
        var raiseCombos = 0.0
        var callCombos = 0.0

        for r in 0..<13 {
            for c in 0..<13 {
                let code = HandMatrixHelper.handCode(row: r, col: c)
                let act = action(for: code, position: position, situation: situation, opener: opener)
                let combos = Double(HandMatrixHelper.combinationsCount(for: code))
                let freq = act.frequencies
                raiseCombos += combos * (Double(freq.raise) / 100.0)
                callCombos += combos * (Double(freq.call) / 100.0)
            }
        }
        return ((raiseCombos / totalCombos) * 100.0, (callCombos / totalCombos) * 100.0)
    }

    /// Nash Push/Fold threshold (Max BB stack where pushing is +EV)
    func maxPushBB(for handCode: String, position: PokerPosition) -> Int {
        NashPushFoldTable.maxBB(for: handCode, position: position)
    }

    func resetAllProfilesToDefault() {
        customRanges = PresetRangeBuilder.buildAllProfiles()
        saveRanges()
    }

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

// MARK: - Preset Builder (Yokosawa, GTO 100BB, High Rake, MTT 25BB)
struct PresetRangeBuilder {
    static let tier1Red: Set<String> = ["AA", "KK", "QQ", "JJ", "AKs", "AKo"]
    static let tier2Yellow: Set<String> = [
        "TT", "99", "88", "77",
        "AQs", "AJs", "ATs", "KQs", "KJs", "QJs", "JTs", "AQo"
    ]
    static let tier3Green: Set<String> = [
        "66", "55",
        "A9s", "A8s", "A7s", "A5s", "A4s",
        "KTs", "QTs", "T9s", "98s", "87s", "AJo", "KQo"
    ]
    static let tier4Blue: Set<String> = [
        "44", "33", "22",
        "A6s", "A3s", "A2s",
        "K9s", "K8s", "Q9s", "J9s", "76s", "65s", "54s",
        "ATo", "KJo", "QJo", "JTo"
    ]
    static let tier5Purple: Set<String> = [
        "K7s", "K6s", "K5s", "K4s", "K3s", "K2s",
        "Q8s", "Q7s", "Q6s", "J8s", "J7s", "T8s", "T7s", "97s", "86s", "75s", "64s", "53s",
        "A9o", "A8o", "A7o", "A5o", "KTo", "K9o", "QTo", "Q9o", "J9o", "T9o"
    ]

    static func buildAllProfiles() -> [String: [String: HandAction]] {
        var result: [String: [String: HandAction]] = [:]

        let utgBase = tier1Red.union(tier2Yellow)
        let hjBase = utgBase.union(tier3Green)
        let coBase = hjBase.union(tier4Blue)
        let btnBase = coBase.union(tier5Purple)

        for profile in StrategyProfile.allCases {
            // 1. RFI Ranges
            for pos in PokerPosition.allCases {
                var table: [String: HandAction] = [:]
                switch pos {
                case .utg:
                    for h in utgBase { table[h] = .raise }
                    if profile == .gto100bb {
                        for h in ["66", "A9s", "A5s", "KTs", "QTs", "T9s"] { table[h] = .mixedRaiseFold }
                    }
                case .hj:
                    for h in hjBase { table[h] = .raise }
                    if profile == .gto100bb {
                        for h in ["44", "A6s", "A3s", "K9s", "AJo", "KQo"] { table[h] = .mixedRaiseFold }
                    }
                case .co:
                    for h in coBase { table[h] = .raise }
                    if profile == .gto100bb {
                        for h in ["K7s", "K6s", "Q8s", "J8s", "T8s", "A9o", "KTo"] { table[h] = .mixedRaiseFold }
                    }
                case .btn, .sb:
                    for h in btnBase { table[h] = .raise }
                    if profile == .mtt25bb && pos == .sb {
                        for h in ["22", "33", "44", "55", "A2s", "A3s", "A4s", "A5s", "A7o", "A8o", "A9o", "K9s", "Q9s", "J9s"] {
                            table[h] = .allIn
                        }
                    }
                case .bb:
                    for h in coBase { table[h] = .raise }
                }
                result["\(profile.rawValue)|\(pos.rawValue)|\(PreflopSituation.rfi.rawValue)|ANY"] = table
            }

            // 2. vs Open Ranges (Opener-Aware for GTO, General fallback for others)
            for hero in PokerPosition.allCases {
                let openers: [PokerPosition?] = [nil] + hero.validOpenerPositions.map { Optional($0) }
                for opener in openers {
                    var table: [String: HandAction] = [:]
                    let isLateOpener = (opener == .co || opener == .btn || opener == .sb)

                    switch profile {
                    case .yokosawa:
                        populateYokosawaVsOpen(&table, hero: hero, isLateOpener: isLateOpener)
                    case .gto100bb:
                        populateGTOVsOpen(&table, hero: hero, isLateOpener: isLateOpener)
                    case .highRake:
                        populateHighRakeVsOpen(&table, hero: hero, isLateOpener: isLateOpener)
                    case .mtt25bb:
                        populateMTT25BBVsOpen(&table, hero: hero, isLateOpener: isLateOpener)
                    }

                    let opTag = opener?.rawValue ?? "ANY"
                    result["\(profile.rawValue)|\(hero.rawValue)|\(PreflopSituation.vsOpen.rawValue)|\(opTag)"] = table
                }
            }

            // 3. vs 3-Bet Ranges
            for pos in PokerPosition.allCases {
                var table: [String: HandAction] = [:]
                switch profile {
                case .yokosawa:
                    for h in ["AA", "KK", "QQ", "AKs", "AKo", "A5s"] { table[h] = .raise }
                    for h in ["JJ", "TT", "99", "AQs", "AJs", "KQs", "QJs", "JTs", "AQo"] { table[h] = .call }
                case .gto100bb:
                    for h in ["AA", "KK", "QQ", "AKs", "AKo"] { table[h] = .raise }
                    for h in ["JJ", "AQs", "A5s", "A4s", "KQs"] { table[h] = .mixedRaiseCall }
                    for h in ["TT", "99", "88", "AJs", "ATs", "KJs", "QJs", "JTs", "T9s", "98s", "AQo"] { table[h] = .call }
                case .highRake:
                    for h in ["AA", "KK", "QQ", "AKs", "AKo", "A5s", "A4s"] { table[h] = .raise }
                    for h in ["JJ", "TT", "AQs", "KQs"] { table[h] = .call }
                case .mtt25bb:
                    for h in ["AA", "KK", "QQ", "JJ", "TT", "99", "AKs", "AQs", "AJs", "A5s", "AKo", "AQo"] {
                        table[h] = .allIn
                    }
                    for h in ["KQs", "QJs", "JTs"] { table[h] = .call }
                }
                result["\(profile.rawValue)|\(pos.rawValue)|\(PreflopSituation.vs3Bet.rawValue)|ANY"] = table
            }
        }
        return result
    }

    private static func populateYokosawaVsOpen(_ table: inout [String: HandAction], hero: PokerPosition, isLateOpener: Bool) {
        for h in tier1Red.union(["AQs", "A5s"]) { table[h] = .raise }
        if isLateOpener {
            for h in ["TT", "AJs", "KQs", "AQo", "A4s"] { table[h] = .raise }
        }
        let calls = isLateOpener
            ? tier2Yellow.union(tier3Green)
            : ["TT", "99", "88", "77", "AJs", "ATs", "KQs", "KJs", "QJs", "JTs", "AQo"]
        for h in calls where table[h] == nil {
            table[h] = .call
        }
        if hero == .bb {
            for h in tier4Blue where table[h] == nil { table[h] = .call }
        }
    }

    private static func populateGTOVsOpen(_ table: inout [String: HandAction], hero: PokerPosition, isLateOpener: Bool) {
        for h in tier1Red { table[h] = .raise }
        if hero == .sb {
            // SB Linear 3-Bet Strategy
            let sb3Bet = isLateOpener
                ? ["TT", "99", "88", "AQs", "AJs", "ATs", "A5s", "A4s", "KQs", "KJs", "KTs", "QJs", "QTs", "JTs", "AQo", "AJo", "KQo"]
                : ["TT", "99", "AQs", "AJs", "KQs", "A5s", "AQo"]
            for h in sb3Bet { table[h] = .raise }
            for h in ["77", "66", "T9s", "98s"] { table[h] = .mixedRaiseFold }
        } else if hero == .bb {
            // BB Polarized 3-Bet + Wide Defense
            let bb3Bet = isLateOpener
                ? ["TT", "99", "AQs", "AJs", "KQs", "KJs", "QJs", "JTs", "A5s", "A4s", "A3s", "K9s", "Q9s", "87s", "76s", "65s", "54s", "AQo"]
                : ["AQs", "A5s", "A4s", "KQs", "76s", "65s"]
            for h in bb3Bet { table[h] = .raise }
            for h in ["TT", "99", "AJs", "ATs", "KJs", "QJs", "JTs"] where table[h] == nil {
                table[h] = .mixedRaiseCall
            }
            let bbCalls = isLateOpener
                ? tier2Yellow.union(tier3Green).union(tier4Blue).union(tier5Purple)
                : tier2Yellow.union(tier3Green).union(["44", "33", "22", "A6s", "A3s", "A2s", "76s", "65s", "54s"])
            for h in bbCalls where table[h] == nil {
                table[h] = .call
            }
        } else {
            // IP / MP vs Open
            for h in ["AQs", "AJs", "KQs", "AQo"] { table[h] = .raise }
            for h in ["TT", "99", "A5s", "A4s", "KJs", "QJs", "JTs", "76s", "65s"] {
                table[h] = isLateOpener ? .raise : .mixedRaiseCall
            }
            for h in ["88", "77", "66", "55", "ATs", "KTs", "QTs", "T9s", "98s", "87s"] where table[h] == nil {
                table[h] = .call
            }
        }
    }

    private static func populateHighRakeVsOpen(_ table: inout [String: HandAction], hero: PokerPosition, isLateOpener: Bool) {
        // High Rake: Aggressive 3-Bet or Fold (minimal flatting)
        let aggressive3Bet = isLateOpener
            ? tier1Red.union(tier2Yellow).union(["A9s", "A8s", "A5s", "A4s", "KTs", "QTs", "T9s", "98s", "AJo", "KQo"])
            : tier1Red.union(["TT", "99", "AQs", "AJs", "KQs", "A5s", "A4s", "AQo"])
        for h in aggressive3Bet { table[h] = .raise }
        if hero == .btn || hero == .bb {
            for h in ["88", "77", "66", "AJs", "ATs", "KJs", "QJs", "JTs"] where table[h] == nil {
                table[h] = .call
            }
        }
    }

    private static func populateMTT25BBVsOpen(_ table: inout [String: HandAction], hero: PokerPosition, isLateOpener: Bool) {
        // MTT 25BB: Re-steal 3-Bet Jam (All-In) + tight call
        for h in ["AA", "KK", "QQ"] { table[h] = .raise }
        let jamHands = isLateOpener
            ? ["JJ", "TT", "99", "88", "77", "66", "55", "AKs", "AQs", "AJs", "ATs", "A9s", "A8s", "A5s", "A4s", "KQs", "KJs", "QJs", "JTs", "AKo", "AQo", "AJo", "KQo"]
            : ["JJ", "TT", "99", "88", "AKs", "AQs", "AJs", "A5s", "KQs", "AKo", "AQo"]
        for h in jamHands { table[h] = .allIn }
        if hero == .bb || hero == .btn {
            for h in ["KTs", "QTs", "JTs", "T9s", "98s", "87s", "76s", "44", "33", "22"] where table[h] == nil {
                table[h] = .call
            }
        }
    }
}

// MARK: - Short Stack Nash Equilibrium Push/Fold Table (Max BB up to 20BB)
struct NashPushFoldTable {
    static func maxBB(for handCode: String, position: PokerPosition) -> Int {
        let baseScore = handStrengthScore(for: handCode)
        let posMultiplier: Double
        switch position {
        case .utg: posMultiplier = 0.60
        case .hj:  posMultiplier = 0.75
        case .co:  posMultiplier = 0.95
        case .btn: posMultiplier = 1.25
        case .sb:  posMultiplier = 1.45
        case .bb:  posMultiplier = 1.00
        }
        let rawBB = Int((baseScore * posMultiplier).rounded())
        return min(20, max(0, rawBB))
    }

    private static func handStrengthScore(for handCode: String) -> Double {
        if PresetRangeBuilder.tier1Red.contains(handCode) { return 20.0 }
        if PresetRangeBuilder.tier2Yellow.contains(handCode) { return 18.0 }
        if ["66", "55", "44", "33", "22"].contains(handCode) { return 16.0 }
        if PresetRangeBuilder.tier3Green.contains(handCode) { return 15.0 }
        if PresetRangeBuilder.tier4Blue.contains(handCode) { return 11.5 }
        if PresetRangeBuilder.tier5Purple.contains(handCode) { return 8.0 }
        if handCode.hasPrefix("A") || handCode.hasPrefix("K") && handCode.hasSuffix("s") { return 6.5 }
        if handCode.hasSuffix("s") { return 4.5 }
        return 2.5
    }
}
