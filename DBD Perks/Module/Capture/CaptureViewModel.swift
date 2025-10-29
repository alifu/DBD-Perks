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

@Observable
class CaptureViewModel {
    
    var currentFrame: CGImage?
    private let cameraManager = CameraManager()
    var capturedImage: UIImage?
    var showingSheet = false
    
    init() {
        Task {
            await handleCameraPreviews()
        }
    }
    
    func handleCameraPreviews() async {
        for await image in cameraManager.previewStream {
            Task { @MainActor in
                currentFrame = image
            }
        }
    }
    
    func didClickShutter() {
        cameraManager.capturePhoto { image in
            self.capturedImage = image
            self.showingSheet.toggle()
        }
    }
}
