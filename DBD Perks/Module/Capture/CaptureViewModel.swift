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

@Observable
class CaptureViewModel {
    
    var currentFrame: CGImage?
    private let cameraManager = CameraManager()
    var capturedImage: UIImage?
    /// One crop per perk slot of the current layout, in slot order.
    var capturedCrops: [UIImage] = []
    var layout: PerkSlotLayout = .diamond
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
        capturedImage = self.simulatorImage
        capturedCrops = [simulatorImage].compactMap { $0 }
        showingSheet = !capturedCrops.isEmpty
#else
        cameraManager.capturePhoto { image in
            guard let image else { return }
            self.capturedImage = image
            self.capturedCrops = self.crops(from: image)
            self.showingSheet = !self.capturedCrops.isEmpty
        }
#endif
    }
    
    /// Cuts the photo into the (at most four) perk slots that were visible in the guide.
    func crops(from photo: UIImage) -> [UIImage] {
        layout.slots(in: previewSize).compactMap {
            photo.cropped(toViewRect: $0.cropRect, viewSize: previewSize)
        }
    }
    
    func loadSimulatorImage() {
        currentFrame = self.simulatorImage?.cgImage
    }
}
