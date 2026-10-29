//
//  PerkImageProcessorTests.swift
//  DBD PerksTests
//

import XCTest
import CoreVideo
import UIKit
@testable import DBD_Perks

@MainActor
final class PerkImageProcessorTests: XCTestCase {

    private func solidImage(_ color: UIColor, size: CGSize = CGSize(width: 400, height: 300)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func centerPixel(of buffer: CVPixelBuffer) -> (r: UInt8, g: UInt8, b: UInt8) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let offset = (CVPixelBufferGetHeight(buffer) / 2) * bytesPerRow + (CVPixelBufferGetWidth(buffer) / 2) * 4
        // 32ARGB layout: A, R, G, B
        return (base[offset + 1], base[offset + 2], base[offset + 3])
    }

    func testPreprocessReturnsModelInputSize() throws {
        let buffer = try XCTUnwrap(PerkImageProcessor().preprocess(solidImage(.red)))

        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 128)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), 128)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(buffer), kCVPixelFormatType_32ARGB)
    }

    func testPreprocessKeepsColorInsteadOfGrayscale() throws {
        let buffer = try XCTUnwrap(PerkImageProcessor().preprocess(solidImage(.red)))

        let pixel = centerPixel(of: buffer)

        XCTAssertGreaterThan(Int(pixel.r), Int(pixel.g) + 100)
        XCTAssertGreaterThan(Int(pixel.r), Int(pixel.b) + 100)
    }
}
