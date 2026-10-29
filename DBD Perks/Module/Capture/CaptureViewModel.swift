//
//  CameraViewModel.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import Foundation
import CoreImage
import Observation
import UIKit
import SwiftUI

protocol CameraProvider {
    var previewStream: AsyncStream<CGImage> { get }
    func capturePhoto(completion: @escaping (UIImage?) -> Void)
}

/// How the perks get found: automatically anywhere in the photo, or by lining them up with a guide.
enum CaptureMode: Hashable, CaseIterable, Identifiable {
    case auto
    case diamond
    case row

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .diamond: return PerkSlotLayout.diamond.title
        case .row: return PerkSlotLayout.row.title
        }
    }

    var guideLayout: PerkSlotLayout? {
        switch self {
        case .auto: return nil
        case .diamond: return .diamond
        case .row: return .row
        }
    }
}

@Observable
class CaptureViewModel {
    
    var currentFrame: CGImage?
    private let cameraManager = CameraManager()
    var capturedImage: UIImage?
    /// One crop per perk slot of the current layout, in slot order.
    var capturedCrops: [UIImage] = []
    var mode: CaptureMode = .auto
    var previewSize: CGSize = .zero
    var showingSheet = false
    let simulatorImage = UIImage(named: "hex-no-one-escapes-death")
    
    init() {
#if targetEnvironment(simulator)
        loadSimulatorImage()
#else
        Task {
            await handleCameraPreviews()
        }
#endif
    }
    
    func handleCameraPreviews() async {
        for await image in cameraManager.previewStream {
            Task { @MainActor in
                currentFrame = image
            }
        }
    }
    
    func didClickShutter() {
#if targetEnvironment(simulator)
        guard let photo = simulatorImage else { return }
        present(photo: photo, crops: mode.guideLayout == nil ? [] : [photo])
#else
        cameraManager.capturePhoto { image in
            guard let image else { return }
            self.present(photo: image, crops: self.mode.guideLayout.map { self.crops(from: image, layout: $0) } ?? [])
        }
#endif
    }
    
    private func present(photo: UIImage, crops: [UIImage]) {
        capturedImage = photo
        capturedCrops = crops
        showingSheet = true
    }
    
    /// Cuts the photo into the (at most four) perk slots that were visible in the guide.
    func crops(from photo: UIImage, layout: PerkSlotLayout) -> [UIImage] {
        layout.slots(in: previewSize).compactMap {
            photo.cropped(toViewRect: $0.cropRect, viewSize: previewSize)
        }
    }
    
    func loadSimulatorImage() {
        currentFrame = self.simulatorImage?.cgImage
    }
}
