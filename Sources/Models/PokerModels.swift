import Foundation
import SwiftUI

enum PokerPosition: String, CaseIterable, Identifiable, Codable {
    case utg = "UTG"
    case hj = "HJ"
    case co = "CO"
    case btn = "BTN"
    case sb = "SB"
    case bb = "BB"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .utg: return "UTG (アンダー・ザ・ガン)"
        case .hj: return "HJ (ハイジャック)"
        case .co: return "CO (カットオフ)"
        case .btn: return "BTN (ボタン)"
        case .sb: return "SB (スモールブラインド)"
        case .bb: return "BB (ビッグブラインド)"
        }
    }
}

enum PreflopSituation: String, CaseIterable, Identifiable, Codable {
    case rfi = "オープン (誰も参加していない)"
    case vsOpen = "vs オープン (レイズが入った)"
    case vs3Bet = "vs 3ベット (リレイズされた)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .rfi: return "RFI (オープン)"
        case .vsOpen: return "vs Open"
        case .vs3Bet: return "vs 3-Bet"
        }
    }
}

enum HandAction: String, CaseIterable, Identifiable, Codable {
    case raise = "RAISE"
    case call = "CALL"
    case fold = "FOLD"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .raise: return "レイズ / 3-Bet / 4-Bet"
        case .call: return "コール"
        case .fold: return "フォールド"
        }
    }

    var shortBadge: String {
        switch self {
        case .raise: return "RAISE"
        case .call: return "CALL"
        case .fold: return "FOLD"
        }
    }

    var color: Color {
        switch self {
        case .raise: return Color(red: 0.85, green: 0.22, blue: 0.24)
        case .call: return Color(red: 0.16, green: 0.65, blue: 0.36)
        case .fold: return Color(.systemGray4)
        }
    }

    var textColor: Color {
        switch self {
        case .raise, .call: return .white
        case .fold: return .primary
        }
    }
}

enum CardRank: Int, CaseIterable, Identifiable, Comparable {
    case ace = 14
    case king = 13
    case queen = 12
    case jack = 11
    case ten = 10
    case nine = 9
    case eight = 8
    case seven = 7
    case six = 6
    case five = 5
    case four = 4
    case three = 3
    case two = 2

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

    /// Returns canonical hand notation (e.g., "AKs", "AKo", "QQ") for row (0..12) and col (0..12)
    static func handCode(row: Int, col: Int) -> String {
        let r1 = allRanks[row]
        let r2 = allRanks[col]
        if row == col {
            return "\(r1.symbol)\(r2.symbol)"
        } else if row < col {
            // Upper right = Suited
            return "\(r1.symbol)\(r2.symbol)s"
        } else {
            // Lower left = Offsuit
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
        if handCode.count == 2 {
            return 6 // Pocket pair
        } else if handCode.hasSuffix("s") {
            return 4 // Suited
        } else {
            return 12 // Offsuit
        }
    }
}

/// Yokosawa-style Color Tier Classification (Red > Yellow > Green > Blue > Purple > Fold)
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
