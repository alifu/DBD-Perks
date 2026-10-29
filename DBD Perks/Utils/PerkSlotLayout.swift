//
//  PerkSlotLayout.swift
//  DBD Perks
//

import CoreGraphics

/// One perk position on screen. The in-game icon sits inside a diamond (a square rotated 45°),
/// so we crop the largest upright square that fits inside that diamond.
struct PerkSlot: Equatable {
    /// Side of the largest upright square that fits inside a diamond: half of its diagonal.
    static let cropFractionOfDiagonal: CGFloat = 0.5

    let center: CGPoint
    /// Corner-to-corner size of the diamond frame.
    let diagonal: CGFloat

    var cropRect: CGRect {
        let side = diagonal * Self.cropFractionOfDiagonal
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}

/// How the four perks are arranged on screen. Both layouts produce at most `PerkSlotLayout.maxSlots` slots.
enum PerkSlotLayout: String, CaseIterable, Identifiable {
    static let maxSlots = 4

    case diamond
    case row

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diamond: return "Diamond"
        case .row: return "Row"
        }
    }

    private static let diamondWidthFraction: CGFloat = 0.3
    private static let rowWidthFraction: CGFloat = 0.22
    private static let spacingFactor: CGFloat = 1.05

    func slots(in size: CGSize) -> [PerkSlot] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        switch self {
        case .diamond:
            let diagonal = size.width * Self.diamondWidthFraction
            let offset = diagonal / 2 * Self.spacingFactor
            return [
                CGPoint(x: 0, y: -offset),
                CGPoint(x: -offset, y: 0),
                CGPoint(x: offset, y: 0),
                CGPoint(x: 0, y: offset)
            ].map { PerkSlot(center: CGPoint(x: center.x + $0.x, y: center.y + $0.y), diagonal: diagonal) }
        case .row:
            let diagonal = size.width * Self.rowWidthFraction
            let step = diagonal * Self.spacingFactor
            return (0..<Self.maxSlots).map { index in
                let x = center.x + (CGFloat(index) - CGFloat(Self.maxSlots - 1) / 2) * step
                return PerkSlot(center: CGPoint(x: x, y: center.y), diagonal: diagonal)
            }
        }
    }
}
