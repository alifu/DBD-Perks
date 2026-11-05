//
//  LevelStretching.swift
//  DBD Perks
//

import UIKit
import CoreImage

/// Brightens a crop whose levels do not use the full range, like the dimmed icon of a perk that is
/// currently inactive (it keeps its shape but looks half as bright as the icons the model was trained on).
enum LevelStretching {
    /// Luminance percentiles that count as "black" and "white" of the crop; ignores a few stray pixels.
    static let lowPercentile = 0.02
    static let highPercentile = 0.98
    /// Crops that already span more than this much of the range are left alone.
    static let maximumSpanToStretch = 0.8
    /// Flat crops (a solid colour) have nothing to stretch and would only amplify noise.
    static let minimumSpan = 0.12
    private static let sampleSide = 32

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// nil when the crop already has full contrast or has no contrast at all.
    static func stretched(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage, let levels = levels(of: cgImage),
              levels.span <= maximumSpanToStretch, levels.span >= minimumSpan else { return nil }

        let scale = 1 / levels.span
        let bias = -levels.low / levels.span
        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: scale, y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter?.setValue(CIVector(x: 0, y: scale, z: 0, w: 0), forKey: "inputGVector")
        filter?.setValue(CIVector(x: 0, y: 0, z: scale, w: 0), forKey: "inputBVector")
        filter?.setValue(CIVector(x: bias, y: bias, z: bias, w: 0), forKey: "inputBiasVector")
        guard let output = filter?.outputImage,
              let result = context.createCGImage(output, from: CIImage(cgImage: cgImage).extent) else { return nil }
        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    /// Dark and light end of the crop's luminance, each 0...1.
    static func levels(of image: CGImage) -> (low: Double, high: Double, span: Double)? {
        let side = sampleSide
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var luminance: [Double] = []
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[offset])
            let green = Double(pixels[offset + 1])
            let blue = Double(pixels[offset + 2])
            luminance.append((0.299 * red + 0.587 * green + 0.114 * blue) / 255)
        }
        luminance.sort()
        let last = Double(luminance.count - 1)
        let low: Double = luminance[Int(last * lowPercentile)]
        let high: Double = luminance[Int(last * highPercentile)]
        let span: Double = high - low
        return (low, high, span)
    }
}

/// Scores a crop as it is and, when it looks dim, also with its levels stretched; the more confident answer wins.
/// Bright icons never take the second pass, so they score exactly as before.
struct LevelAdaptiveScorer: SlotScoring {
    let base: SlotScoring

    func labelScores(for crop: UIImage) throws -> [String: Double] {
        let original = try base.labelScores(for: crop)
        guard let brightened = LevelStretching.stretched(crop) else { return original }
        let stretched = try base.labelScores(for: brightened)
        return GuideSlotSearch.confidence(stretched) > GuideSlotSearch.confidence(original) ? stretched : original
    }
}
