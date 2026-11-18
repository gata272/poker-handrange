import Foundation
import SwiftUI

@MainActor
final class RangeStore: ObservableObject {
    @Published var selectedProfile: StrategyProfile = .gto100bb
    @Published var customRanges: [String: [String: HandAction]] = [:]
    @Published var rngValue: Int = Int.random(in: 1...100)

    // Dynamic Stack & Table Environment Parameters
    @Published var effectiveStackBB: Double = 100.0
    @Published var hasAnte: Bool = false
    @Published var openRaiseSizeBB: Double = 2.5
    @Published var isStackAdjustmentEnabled: Bool = true

    private let storageFileName = "custom_poker_ranges_v3.json"

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

    /// Base chart action without dynamic stack override
    func baseAction(
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

    /// Dynamic stack-aware action & sizing recommendation
    func evaluateDynamicAdvice(
        for handCode: String,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) -> DynamicAdviceResult {
        let stack = Int(effectiveStackBB.rounded())
        let base = baseAction(for: handCode, position: position, situation: situation, opener: opener)

        guard isStackAdjustmentEnabled else {
            return DynamicAdviceResult(
                action: base,
                sizingText: defaultSizingText(for: base, situation: situation, stack: stack),
                reasonText: "ベースレンジ表通りの判定（スタック自動補正オフ）",
                stackZoneLabel: "\(stack)BB (固定)"
            )
        }

        // 1. Short Stack Mode (<= 15 BB): Nash Push / Fold or 3-Bet Jam
        if stack <= 15 {
            let maxPush = maxPushBB(for: handCode, position: position) + (hasAnte ? 2 : 0)
            switch situation {
            case .rfi:
                if maxPush >= stack {
                    return DynamicAdviceResult(
                        action: .allIn,
                        sizingText: "オールイン (\(stack)BB Push)",
                        reasonText: "\(stack)BB以下のショートスタック域。Nash均衡上限(\(maxPush)BB)内のため直接Pushが+EVです。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                } else {
                    return DynamicAdviceResult(
                        action: .fold,
                        sizingText: "フォールド",
                        reasonText: "\(stack)BBでのPush上限(\(maxPush)BB)未満のためフォールド推奨です。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                }
            case .vsOpen:
                let jamThreshold = max(6, maxPush - 2)
                if jamThreshold >= stack || PresetRangeBuilder.tier1Red.contains(handCode) || PresetRangeBuilder.tier2Yellow.contains(handCode) {
                    return DynamicAdviceResult(
                        action: .allIn,
                        sizingText: "3-Bet オールイン (\(stack)BB)",
                        reasonText: "\(stack)BBではコールで止めるとSPRが小さすぎるため、強いハンドは直接オールインします。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                } else {
                    return DynamicAdviceResult(
                        action: .fold,
                        sizingText: "フォールド",
                        reasonText: "\(stack)BBではインプライドオッズが足りないため、コールせずフォールドします。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                }
            case .vs3Bet:
                if PresetRangeBuilder.tier1Red.contains(handCode) || ["TT", "99", "AQs", "AQo", "AJs", "KQs"].contains(handCode) {
                    return DynamicAdviceResult(
                        action: .allIn,
                        sizingText: "4-Bet オールイン (\(stack)BB)",
                        reasonText: "\(stack)BBでは3-Betに対してコミットしているためオールインします。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                } else {
                    return DynamicAdviceResult(
                        action: .fold,
                        sizingText: "フォールド",
                        reasonText: "ショートスタックでの3-Betに対して勝率が不足しているためフォールドします。",
                        stackZoneLabel: "ショート (\(stack)BB)"
                    )
                }
            }
        }

        // 2. Reshove / Mid-Short Stack Mode (16 BB ... 28 BB)
        if stack <= 28 {
            switch situation {
            case .rfi:
                // Small pairs & low suited connectors lose value at 20BB from early/mid positions
                if (position == .utg || position == .hj) && (HandMatrixHelper.isSmallPocketPair(handCode) || HandMatrixHelper.isLowSuitedConnector(handCode)) {
                    return DynamicAdviceResult(
                        action: .fold,
                        sizingText: "フォールド",
                        reasonText: "\(stack)BBではセットマインやストレート狙いのインプライドオッズが不足するため、序盤ポジションからはフォールドします。",
                        stackZoneLabel: "ミドルショート (\(stack)BB)"
                    )
                }
                if hasAnte && (position == .co || position == .btn || position == .sb) && base == .fold && HandMatrixHelper.isHighCardBroadWay(handCode) {
                    return DynamicAdviceResult(
                        action: .raise,
                        sizingText: "2.0BB ミニマムレイズ",
                        reasonText: "アンティ有り・\(stack)BBのため、ハイカード系で積極的にスチールを狙います。",
                        stackZoneLabel: "ミドルショート (\(stack)BB)"
                    )
                }
                let act = base == .allIn ? .raise : base
                return DynamicAdviceResult(
                    action: act,
                    sizingText: act == .fold ? "フォールド" : "2.0BB〜2.2BB オープン",
                    reasonText: "\(stack)BBではオープンサイズを2.0〜2.2BBに抑えてリスクを管理します。",
                    stackZoneLabel: "ミドルショート (\(stack)BB)"
                )

            case .vsOpen:
                // At 16-28BB: 3-Bet becomes 3-Bet All-In (Re-steal), speculative calls become folds
                if HandMatrixHelper.isSmallPocketPair(handCode) && handCode != "66" && handCode != "55" {
                    if position != .bb {
                        return DynamicAdviceResult(
                            action: .fold,
                            sizingText: "フォールド (セットマイン不可)",
                            reasonText: "\(stack)BBではセットを引いても相手のスタックが浅く回収できないため、小ペアのコールは避けます。",
                            stackZoneLabel: "ミドルショート (\(stack)BB)"
                        )
                    }
                }
                if base == .raise || base == .mixedRaiseCall || base == .mixedRaiseFold || base == .allIn {
                    if ["AA", "KK"].contains(handCode) && stack >= 24 {
                        return DynamicAdviceResult(
                            action: .raise,
                            sizingText: String(format: "%.1fBB 3-Bet", openRaiseSizeBB * 2.6),
                            reasonText: "プレミアムハンドのため、相手を降ろしすぎない小サイズ3-Betも有効です。",
                            stackZoneLabel: "ミドルショート (\(stack)BB)"
                        )
                    }
                    return DynamicAdviceResult(
                        action: .allIn,
                        sizingText: "3-Bet オールイン (\(stack)BB リスチール)",
                        reasonText: "\(stack)BBでの3-Betはサイズ的にコミットするため、直接オールイン(リスチール)してフォールドエクイティを最大化します。",
                        stackZoneLabel: "ミドルショート (\(stack)BB)"
                    )
                }
                if base == .call && HandMatrixHelper.isLowSuitedConnector(handCode) && position != .bb {
                    return DynamicAdviceResult(
                        action: .fold,
                        sizingText: "フォールド",
                        reasonText: "\(stack)BBではスーテッドコネクターのインプライドオッズが不足するためフォールド寄りになります。",
                        stackZoneLabel: "ミドルショート (\(stack)BB)"
                    )
                }
                return DynamicAdviceResult(
                    action: base,
                    sizingText: defaultSizingText(for: base, situation: situation, stack: stack),
                    reasonText: "\(stack)BBスタックに応じたディフェンス判定です。",
                    stackZoneLabel: "ミドルショート (\(stack)BB)"
                )

            case .vs3Bet:
                if base == .raise || base == .mixedRaiseCall || base == .allIn {
                    return DynamicAdviceResult(
                        action: .allIn,
                        sizingText: "4-Bet オールイン (\(stack)BB)",
                        reasonText: "\(stack)BBで3-Betを受けた場合、継続する強いハンドは4-Betオールインにします。",
                        stackZoneLabel: "ミドルショート (\(stack)BB)"
                    )
                }
                return DynamicAdviceResult(
                    action: .fold,
                    sizingText: "フォールド",
                    reasonText: "\(stack)BBで3-BetにコールするとフロップのSPRが1未満になるため、オールインできないハンドはフォールドします。",
                    stackZoneLabel: "ミドルショート (\(stack)BB)"
                )
            }
        }

        // 3. Medium Stack Mode (29 BB ... 55 BB)
        if stack <= 55 {
            if situation == .vs3Bet && (HandMatrixHelper.isSmallPocketPair(handCode) || HandMatrixHelper.isLowSuitedConnector(handCode)) {
                return DynamicAdviceResult(
                    action: .fold,
                    sizingText: "フォールド (スタック浅め)",
                    reasonText: "\(stack)BBでは3-Betポットでのインプライドオッズが足りないため、投機的ハンドはフォールドします。",
                    stackZoneLabel: "ミドル (\(stack)BB)"
                )
            }
            if situation == .vsOpen && openRaiseSizeBB >= 3.5 && base == .call && !PresetRangeBuilder.tier2Yellow.contains(handCode) {
                return DynamicAdviceResult(
                    action: .fold,
                    sizingText: "フォールド (大サイズオープン対策)",
                    reasonText: "相手のオープンサイズが\(String(format: "%.1f", openRaiseSizeBB))BBと大きく、\(stack)BBではオッズが合わないためタイトにフォールドします。",
                    stackZoneLabel: "ミドル (\(stack)BB)"
                )
            }
            let normalized = base == .allIn ? .raise : base
            return DynamicAdviceResult(
                action: normalized,
                sizingText: defaultSizingText(for: normalized, situation: situation, stack: stack),
                reasonText: "ミドルスタック(\(stack)BB)向けの標準アクションです。",
                stackZoneLabel: "ミドル (\(stack)BB)"
            )
        }

        // 4. Deep Stack Mode (>= 130 BB)
        if stack >= 130 {
            if situation == .vsOpen && (position == .btn || position == .co || position == .bb) {
                if HandMatrixHelper.isSmallPocketPair(handCode) || HandMatrixHelper.isLowSuitedConnector(handCode) {
                    return DynamicAdviceResult(
                        action: .call,
                        sizingText: String(format: "%.1fBB コール (ディープ・インプライドオッズ◎)", openRaiseSizeBB),
                        reasonText: "\(stack)BBのディープスタックではセットやストレート完成時の見返り(インプライドオッズ)が極めて高いため、積極的にコールできます。",
                        stackZoneLabel: "ディープ (\(stack)BB)"
                    )
                }
                if HandMatrixHelper.isSuitedAceOrWheel(handCode) && base == .fold {
                    return DynamicAdviceResult(
                        action: .mixedRaiseCall,
                        sizingText: String(format: "3-Bet (%.1fBB) または コール", openRaiseSizeBB * 3.2),
                        reasonText: "\(stack)BBのディープ環境ではナッツフラッシュドローやホイールを作れるAxsの価値が大幅に上がります。",
                        stackZoneLabel: "ディープ (\(stack)BB)"
                    )
                }
            }
            let normalized = base == .allIn ? .raise : base
            return DynamicAdviceResult(
                action: normalized,
                sizingText: defaultSizingText(for: normalized, situation: situation, stack: stack),
                reasonText: "ディープスタック(\(stack)BB)環境。ナッツを作れるスーテッドやペアの価値が高まります。",
                stackZoneLabel: "ディープ (\(stack)BB)"
            )
        }

        // 5. Standard 100BB Stack (56 BB ... 129 BB)
        if situation == .vsOpen && openRaiseSizeBB >= 4.0 && base == .call && PresetRangeBuilder.tier4Blue.contains(handCode) {
            return DynamicAdviceResult(
                action: .fold,
                sizingText: "フォールド (相手オープン大)",
                reasonText: "相手のオープンが\(String(format: "%.1f", openRaiseSizeBB))BBと大きいため、下位コールレンジをフォールドに回します。",
                stackZoneLabel: "スタンダード (\(stack)BB)"
            )
        }

        let normalized = base == .allIn ? .raise : base
        return DynamicAdviceResult(
            action: normalized,
            sizingText: defaultSizingText(for: normalized, situation: situation, stack: stack),
            reasonText: "\(selectedProfile.shortTitle)（\(stack)BB）の標準推奨アクションです。",
            stackZoneLabel: "スタンダード (\(stack)BB)"
        )
    }

    func action(
        for handCode: String,
        profile: StrategyProfile? = nil,
        position: PokerPosition,
        situation: PreflopSituation,
        opener: PokerPosition? = nil
    ) -> HandAction {
        if profile == nil && isStackAdjustmentEnabled {
            return evaluateDynamicAdvice(for: handCode, position: position, situation: situation, opener: opener).action
        }
        return baseAction(for: handCode, profile: profile, position: position, situation: situation, opener: opener)
    }

    private func defaultSizingText(for action: HandAction, situation: PreflopSituation, stack: Int) -> String {
        switch action {
        case .allIn:
            return "オールイン (\(stack)BB)"
        case .raise, .mixedRaiseCall, .mixedRaiseFold:
            switch situation {
            case .rfi:
                let rfiSize = stack <= 40 ? 2.2 : openRaiseSizeBB
                return String(format: "%.1fBB オープンレイズ", rfiSize)
            case .vsOpen:
                let mult = 3.0
                return String(format: "%.1fBB 3-Bet (IP 3倍 / OOP 3.5〜4倍)", openRaiseSizeBB * mult)
            case .vs3Bet:
                return String(format: "%.1fBB 4-Bet (約2.2〜2.5倍)", openRaiseSizeBB * 7.5)
            }
        case .call:
            switch situation {
            case .rfi: return "リンプせずレイズ推奨"
            case .vsOpen: return String(format: "%.1fBB コール", openRaiseSizeBB)
            case .vs3Bet: return "3-Betにコール"
            }
        case .fold:
            return "フォールド"
        }
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
        let current = baseAction(for: handCode, position: position, situation: situation, opener: opener)
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

    func maxPushBB(for handCode: String, position: PokerPosition) -> Int {
        NashPushFoldTable.maxBB(for: handCode, position: position)
    }

    func resetToYokosawaPreset() {
        resetAllProfilesToDefault()
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
            let sb3Bet = isLateOpener
                ? ["TT", "99", "88", "AQs", "AJs", "ATs", "A5s", "A4s", "KQs", "KJs", "KTs", "QJs", "QTs", "JTs", "AQo", "AJo", "KQo"]
                : ["TT", "99", "AQs", "AJs", "KQs", "A5s", "AQo"]
            for h in sb3Bet { table[h] = .raise }
            for h in ["77", "66", "T9s", "98s"] { table[h] = .mixedRaiseFold }
        } else if hero == .bb {
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
