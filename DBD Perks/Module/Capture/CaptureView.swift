//
//  CaptureView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI

struct CaptureView: View {
    
    @State private var viewModel = CaptureViewModel()
    
    var body: some View {
        ZStack {
            CameraView(image: $viewModel.currentFrame)
            
            if viewModel.currentFrame != nil {
                VStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.didClickShutter()
                    }) {
                        ZStack {
                            Color.white
                            
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.black)
                                .padding(24)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .padding(.vertical, 32)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSheet) {
            PredictionView(capturedImage: viewModel.capturedImage)
        }
    }
    
    // Helper to stream CGImage into Binding
    private var cameraImageBinding: Binding<CGImage?> {
        Binding(
            get: { nil },
            set: { _ in }
        )
    }
}

struct CapturedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    CaptureView()
}
