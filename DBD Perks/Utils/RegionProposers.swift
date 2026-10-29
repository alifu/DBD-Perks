//
//  RegionProposers.swift
//  DBD Perks
//

import CoreGraphics
import Vision
import os

/// Suggests where a perk frame might be. Rects are in pixels of the given image (top-left origin);
/// each one should bound a whole diamond frame, so its side is the diamond's diagonal.
protocol RegionProposing: Sendable {
    func proposals(in image: CGImage) -> [CGRect]
}

/// Vision rectangle detector. A diamond is a square rotated by 45°, which the detector reports as a quad
/// whose bounding box is the whole frame. Time and space O(P) in the number of pixels.
struct VisionRectangleProposer: RegionProposing {
    static let minimumAspectRatio: Float = 0.7
    static let minimumSize: Float = 0.03
    static let minimumConfidence: Float = 0.1
    static let maximumObservations = 48
    static let quadratureTolerance: Float = 45
    private static let maximumWidthFraction: CGFloat = 0.45

    private let logger = Logger(subsystem: "DBD Perks", category: "RegionProposers")

    func proposals(in image: CGImage) -> [CGRect] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = Self.minimumAspectRatio
        request.maximumAspectRatio = 1
        request.minimumSize = Self.minimumSize
        request.minimumConfidence = Self.minimumConfidence
        request.maximumObservations = Self.maximumObservations
        request.quadratureTolerance = Self.quadratureTolerance

        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            logger.error("Rectangle detection failed: \(error.localizedDescription)")
            return []
        }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        return (request.results ?? []).map { observation in
            let box = observation.boundingBox   // normalized, bottom-left origin
            return CGRect(x: box.minX * width, y: (1 - box.maxY) * height, width: box.width * width, height: box.height * height)
        }
        .filter { $0.width <= width * Self.maximumWidthFraction }
    }
}

/// Vision contour tracing of bright shapes on darker ground: the white glyph inside each frame, and the frame's
/// own light outline. Each shape's bounding box is proposed twice, once as a frame and once enlarged for glyphs.
/// Time O(P) for tracing plus O(K log K) for K contours.
struct VisionContourProposer: RegionProposing {
    static let contrastAdjustment: Float = 2
    static let maximumImageDimension = 512
    static let widthFractionRange: ClosedRange<CGFloat> = 0.025...0.35
    static let aspectRatioRange: ClosedRange<CGFloat> = 0.5...2
    static let maximumShapes = 40
    /// Glyph art spans roughly 0.45-0.8 of its frame, so a glyph box is enlarged to a frame by about this factor.
    static let glyphToFrameFactor: CGFloat = 1.6
    private static let duplicateOverlap: CGFloat = 0.85

    private let logger = Logger(subsystem: "DBD Perks", category: "RegionProposers")

    func proposals(in image: CGImage) -> [CGRect] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = Self.contrastAdjustment
        request.detectsDarkOnLight = false
        request.maximumImageDimension = Self.maximumImageDimension
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            logger.error("Contour detection failed: \(error.localizedDescription)")
            return []
        }
        guard let observation = request.results?.first else { return [] }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        var boxes: [CGRect] = []
        for contour in Self.flatten(observation.topLevelContours) {
            let box = contour.normalizedPath.boundingBoxOfPath
            let pixelBox = CGRect(x: box.minX * width, y: (1 - box.maxY) * height, width: box.width * width, height: box.height * height)
            let widthFraction = pixelBox.width / width
            let aspect = pixelBox.width / max(pixelBox.height, 1)
            guard Self.widthFractionRange.contains(widthFraction), Self.aspectRatioRange.contains(aspect) else { continue }
            boxes.append(pixelBox)
        }
        boxes.sort { $0.width * $0.height > $1.width * $1.height }

        return Self.distinct(boxes).prefix(Self.maximumShapes).flatMap { box in
            [box, Self.enlarged(box, by: Self.glyphToFrameFactor)]
        }
    }

    static func flatten(_ contours: [VNContour]) -> [VNContour] {
        contours.flatMap { [$0] + flatten($0.childContours) }
    }

    static func enlarged(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        let side = max(rect.width, rect.height) * factor
        return CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    }

    /// Drops boxes that mostly repeat one already kept (outer and inner outline of the same shape).
    static func distinct(_ boxes: [CGRect]) -> [CGRect] {
        var kept: [CGRect] = []
        for box in boxes {
            let repeated = kept.contains { other in
                let overlap = other.intersection(box)
                return !overlap.isNull && overlap.width * overlap.height / max(min(other.width * other.height, box.width * box.height), 1) > duplicateOverlap
            }
            if !repeated { kept.append(box) }
        }
        return kept
    }
}

/// Fallback: square windows at a few sizes laid on a grid, to be judged by the classifier.
/// Count = sum over sizes of (W / (s·stride)) · (H / (s·stride)), a few hundred for a 1024 px photo.
struct GridProposer: RegionProposing {
    static let widthFractions: [CGFloat] = [0.09, 0.13, 0.19, 0.27]
    static let strideFraction: CGFloat = 0.75

    func proposals(in image: CGImage) -> [CGRect] {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        return Self.widthFractions.flatMap { fraction -> [CGRect] in
            let side = width * fraction
            guard side < height else { return [] }
            let step = side * Self.strideFraction
            return stride(from: 0, through: height - side, by: step).flatMap { y in
                stride(from: 0, through: width - side, by: step).map { x in
                    CGRect(x: x, y: y, width: side, height: side)
                }
            }
        }
    }
}
