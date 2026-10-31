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
    case single
    case diamond
    case row
    /// One add-on tile, scanned with the add-on model.
    case addon

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .single: return PerkSlotLayout.single.title
        case .diamond: return PerkSlotLayout.diamond.title
        case .row: return PerkSlotLayout.row.title
        case .addon: return PerkSlotLayout.addon.title
        }
    }

    var guideLayout: PerkSlotLayout? {
        switch self {
        case .auto: return nil
        case .single: return .single
        case .diamond: return .diamond
        case .row: return .row
        case .addon: return .addon
        }
    }

    /// Modes the picker offers: Add-on only appears when the add-on model is part of the build.
    static var selectable: [CaptureMode] {
        allCases.filter { $0 != .addon || CoreMLAddonScorer.isModelBundled() }
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
    /// The mode the shown photo was taken in; the result sheet depends on it, not on later picker changes.
    private(set) var capturedMode: CaptureMode = .auto
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
        capturedMode = mode
        showingSheet = true
    }
    
    /// Cuts the photo into the (at most four) perk slots that were visible in the guide, framed like the training crops.
    func crops(from photo: UIImage, layout: PerkSlotLayout) -> [UIImage] {
        layout.slots(in: previewSize).compactMap {
            photo.cropped(toViewRect: $0.classifierCropRect, viewSize: previewSize)
        }
    }
    
    func loadSimulatorImage() {
        currentFrame = self.simulatorImage?.cgImage
    }
}
