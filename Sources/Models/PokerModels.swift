import Foundation
import SwiftUI

enum StrategyProfile: String, CaseIterable, Identifiable, Codable {
    case yokosawa = "ヨコサワ標準 (100BB)"
    case gto100bb = "GTO Cash (100BB)"
    case highRake = "高レーキ 3Bet/Fold"
    case mtt25bb = "MTT トーナメント (25BB)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .yokosawa: return "ヨコサワ"
        case .gto100bb: return "GTO 100BB"
        case .highRake: return "高レーキ"
        case .mtt25bb: return "MTT 25BB"
        }
    }

    var descriptionText: String {
        switch self {
        case .yokosawa:
            return "ヨコサワハンドレンジ準拠。初心者〜中級者が迷わずプレイできる明確なベースライン。"
        case .gto100bb:
            return "GTO Wizard準拠の6-Max 100BBキャッシュ戦略。オープン位置別の防衛やポラライズ3-Bet、混合戦略(頻度)に対応。"
        case .highRake:
            return "アミューズメントや低レート向けのNo Flop No Drop対策。コールを極限まで減らし3-BetかFoldに寄せる戦略。"
        case .mtt25bb:
            return "トーナメント中盤(25BB・アンティ有)向け。ハイカード価値を重視し、3-Betオールイン(リスチール)を含めた構成。"
        }
    }
}

enum PokerPosition: String, CaseIterable, Identifiable, Codable {
    case utg = "UTG"
    case hj = "HJ"
    case co = "CO"
    case btn = "BTN"
    case sb = "SB"
    case bb = "BB"

    var id: String { rawValue }

    var orderIndex: Int {
        switch self {
        case .utg: return 0
        case .hj: return 1
        case .co: return 2
        case .btn: return 3
        case .sb: return 4
        case .bb: return 5
        }
    }

    /// Positions that can open before this position
    var validOpenerPositions: [PokerPosition] {
        PokerPosition.allCases.filter { $0.orderIndex < self.orderIndex }
    }
}

enum PreflopSituation: String, CaseIterable, Identifiable, Codable {
    case rfi = "RFI (オープン)"
    case vsOpen = "vs Open"
    case vs3Bet = "vs 3-Bet"

    var id: String { rawValue }

    var shortName: String { rawValue }
}

enum HandAction: String, CaseIterable, Identifiable, Codable {
    case allIn = "ALL-IN"
    case raise = "RAISE"
    case mixedRaiseCall = "MIX (R/C)"
    case mixedRaiseFold = "MIX (R/F)"
    case call = "CALL"
    case fold = "FOLD"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .allIn: return "オールイン (Push / 3Bet Jam)"
        case .raise: return "レイズ / 3-Bet / 4-Bet (100%)"
        case .mixedRaiseCall: return "混合戦略: レイズ 60% / コール 40%"
        case .mixedRaiseFold: return "混合戦略: レイズ 50% / フォールド 50%"
        case .call: return "コール (100%)"
        case .fold: return "フォールド (0%)"
        }
    }

    var shortBadge: String {
        switch self {
        case .allIn: return "ALL-IN"
        case .raise: return "RAISE"
        case .mixedRaiseCall: return "MIX R/C"
        case .mixedRaiseFold: return "MIX R/F"
        case .call: return "CALL"
        case .fold: return "FOLD"
        }
    }

    /// Frequency breakdown (Raise%, Call%, Fold%)
    var frequencies: (raise: Int, call: Int, fold: Int) {
        switch self {
        case .allIn, .raise: return (100, 0, 0)
        case .mixedRaiseCall: return (60, 40, 0)
        case .mixedRaiseFold: return (50, 0, 50)
        case .call: return (0, 100, 0)
        case .fold: return (0, 0, 100)
        }
    }

    var color: Color {
        switch self {
        case .allIn: return Color(red: 0.58, green: 0.16, blue: 0.82)
        case .raise: return Color(red: 0.85, green: 0.22, blue: 0.24)
        case .mixedRaiseCall: return Color(red: 0.92, green: 0.52, blue: 0.14)
        case .mixedRaiseFold: return Color(red: 0.86, green: 0.36, blue: 0.52)
        case .call: return Color(red: 0.16, green: 0.65, blue: 0.36)
        case .fold: return Color(.systemGray4)
        }
    }

    var textColor: Color {
        switch self {
        case .fold: return .primary
        default: return .white
        }
    }

    /// Returns concrete recommended action given a 1..100 RNG roll
    func resolveWithRNG(_ roll: Int) -> HandAction {
        let freq = frequencies
        if roll <= freq.raise {
            return self == .allIn ? .allIn : .raise
        } else if roll <= (freq.raise + freq.call) {
            return .call
        } else {
            return .fold
        }
    }
}

enum CardRank: Int, CaseIterable, Identifiable, Comparable {
    case ace = 14, king = 13, queen = 12, jack = 11, ten = 10
    case nine = 9, eight = 8, seven = 7, six = 6, five = 5, four = 4, three = 3, two = 2

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        case .ten: return "T"
        case .nine: return "9"
        case .eight: return "8"
        case .seven: return "7"
        case .six: return "6"
        case .five: return "5"
        case .four: return "4"
        case .three: return "3"
        case .two: return "2"
        }
    }

    static func < (lhs: CardRank, rhs: CardRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct HandMatrixHelper {
    static let allRanks: [CardRank] = CardRank.allCases

    static func handCode(row: Int, col: Int) -> String {
        let r1 = allRanks[row]
        let r2 = allRanks[col]
        if row == col {
            return "\(r1.symbol)\(r2.symbol)"
        } else if row < col {
            return "\(r1.symbol)\(r2.symbol)s"
        } else {
            return "\(r2.symbol)\(r1.symbol)o"
        }
    }

    static func formatHand(rank1: CardRank, rank2: CardRank, isSuited: Bool) -> String {
        if rank1 == rank2 {
            return "\(rank1.symbol)\(rank2.symbol)"
        }
        let high = max(rank1, rank2)
        let low = min(rank1, rank2)
        return "\(high.symbol)\(low.symbol)\(isSuited ? "s" : "o")"
    }

    static func combinationsCount(for handCode: String) -> Int {
        if handCode.count == 2 { return 6 }
        return handCode.hasSuffix("s") ? 4 : 12
    }
}

enum YokosawaColorTier: String, CaseIterable, Identifiable {
    case tier1Red = "赤 (最強プレミアム)"
    case tier2Yellow = "黄 (強いハンド)"
    case tier3Green = "緑 (標準オープン)"
    case tier4Blue = "青 (レイト向け)"
    case tier5Purple = "紫 (BTN/SBスチール)"
    case outOfRange = "レンジ外 (基本フォールド)"

    var id: String { rawValue }

    var badgeColor: Color {
        switch self {
        case .tier1Red: return .red
        case .tier2Yellow: return .orange
        case .tier3Green: return .green
        case .tier4Blue: return .blue
        case .tier5Purple: return .purple
        case .outOfRange: return .gray
        }
    }
}
