//
//  CropGeometry.swift
//  DBD Perks
//

import CoreGraphics

enum CropGeometry {
    /// Converts a rect drawn over a `.scaledToFill` preview into pixel coordinates of the photo.
    /// Returns nil when the rect lies completely outside the photo.
    static func imageRect(forViewRect viewRect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect? {
        guard viewSize.width > 0, viewSize.height > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }

        // scaledToFill: the photo is scaled until both dimensions cover the view, then centered.
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let offsetX = (imageSize.width * scale - viewSize.width) / 2
        let offsetY = (imageSize.height * scale - viewSize.height) / 2

        let rect = CGRect(
            x: (viewRect.minX + offsetX) / scale,
            y: (viewRect.minY + offsetY) / scale,
            width: viewRect.width / scale,
            height: viewRect.height / scale
        )
        let clipped = rect.intersection(CGRect(origin: .zero, size: imageSize))
        return clipped.isNull || clipped.isEmpty ? nil : clipped.integral
    }
}
