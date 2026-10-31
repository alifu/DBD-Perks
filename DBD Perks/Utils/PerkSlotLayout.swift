//
//  PerkSlotLayout.swift
//  DBD Perks
//

import CoreGraphics

/// One perk position on screen. The in-game icon sits inside a diamond (a square rotated 45°),
/// so we crop the largest upright square that fits inside that diamond.
struct PerkSlot: Equatable {
    enum Shape: Equatable {
        case diamond
        case square
    }

    /// Add-on tiles are upright squares; the crop is a little larger than the tile, like the training crops.
    static let squareCropFactor: CGFloat = 1.15

    /// Side of the largest upright square that fits inside a diamond: half of its diagonal.
    static let cropFractionOfDiagonal: CGFloat = 0.5

    let center: CGPoint
    /// Corner-to-corner size of the diamond frame.
    let diagonal: CGFloat
    var shape: Shape = .diamond

    /// The square that fits inside the diamond (or the tile itself): what the guide shows as "inside".
    var cropRect: CGRect { squareRect(fractionOfDiagonal: shape == .square ? 1 : Self.cropFractionOfDiagonal) }

    /// The square handed to the classifier. Wider than `cropRect` because the model was trained on crops
    /// that include a little of the diamond's surroundings (same fraction `PerkLocator` verifies with).
    var classifierCropRect: CGRect {
        squareRect(fractionOfDiagonal: shape == .square ? Self.squareCropFactor : PerkLocator.cropFractions[0])
    }

    private func squareRect(fractionOfDiagonal: CGFloat) -> CGRect {
        let side = diagonal * fractionOfDiagonal
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}

/// How the perks are arranged on screen. Every layout produces at most `PerkSlotLayout.maxSlots` slots.
enum PerkSlotLayout: String, CaseIterable, Identifiable {
    static let maxSlots = 4

    case single
    case diamond
    case row
    /// One upright square tile: an add-on.
    case addon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "Single"
        case .diamond: return "Diamond"
        case .row: return "Row"
        case .addon: return "Add-on"
        }
    }

    private static let diamondWidthFraction: CGFloat = 0.3
    private static let singleWidthFraction: CGFloat = 0.5
    private static let rowWidthFraction: CGFloat = 0.22
    private static let addonWidthFraction: CGFloat = 0.4
    private static let spacingFactor: CGFloat = 1.05

    func slots(in size: CGSize) -> [PerkSlot] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        switch self {
        case .single:
            return [PerkSlot(center: center, diagonal: size.width * Self.singleWidthFraction)]
        case .addon:
            return [PerkSlot(center: center, diagonal: size.width * Self.addonWidthFraction, shape: .square)]
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
