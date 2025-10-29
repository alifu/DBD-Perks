//
//  CameraManager.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import Foundation
import AVFoundation
import UIKit

final class CameraManager: NSObject {
    
    private let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let photoCaptureOutput = AVCapturePhotoOutput()
    private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
    private var sessionQueue = DispatchQueue(label: "video.preview.session")
    private var addToPreviewStream: ((CGImage) -> Void)?
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    lazy var previewStream: AsyncStream<CGImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { cgImage in
                continuation.yield(cgImage)
            }
        }
    }()
    
    override init() {
        super.init()
        
        Task {
            await configureSession()
            await startSession()
        }
    }
    
    private func configureSession() async {
        guard await isAuthorized,
              let systemPreferredCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera)
        else { return }
        
        captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        guard captureSession.canAddInput(deviceInput) else {
            print("Unable to add device input to capture session.")
            return
        }
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        
        // Add photo output for still capture
        if captureSession.canAddOutput(photoCaptureOutput) {
            captureSession.addOutput(photoCaptureOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                // For iOS 17 and newer
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90 // 90° = portrait
                }
            } else if connection.isVideoOrientationSupported {
                // For iOS 16 and older
                connection.videoOrientation = .portrait
            }
        }
    }
    
    private func startSession() async {
        /// Checking authorization
        guard await isAuthorized else { return }
        /// Start the capture session flow of data
        captureSession.startRunning()
    }
    
    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            // Determine if the user previously authorized camera access.
            var isAuthorized = status == .authorized
            
            // If the system hasn't determined the user's authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
}

// MARK: - Capture Photo
extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            self.photoCaptureCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoCaptureOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("⚠️ Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              var image = UIImage(data: data) else {
            print("⚠️ Could not create UIImage from photo data.")
            return
        }
        
        // Ensure image is in the correct orientation
        image = image.fixedOrientation()
        
        // Crop to center 128×128
        let overlaySize = CGSize(width: 128, height: 128)
        let previewSize = UIScreen.main.bounds.size
        let cropped = image.centerCropped(to: overlaySize, sizeInView: previewSize)
        
        Task { @MainActor in
            self.photoCaptureCompletion?(cropped)
        }
    }
}

// MARK: - Live Preview Delegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let currentFrame = sampleBuffer.cgImage else { return }
        addToPreviewStream?(currentFrame)
    }
}
