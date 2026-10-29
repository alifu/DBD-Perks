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
            CameraView(image: $viewModel.currentFrame,
                       viewSize: $viewModel.previewSize,
                       layout: viewModel.layout)
            
            if viewModel.currentFrame != nil {
                VStack {
                    Picker("Layout", selection: $viewModel.layout) {
                        ForEach(PerkSlotLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
                    
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
            PredictionView(crops: viewModel.capturedCrops)
        }
    }
}

struct CapturedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    CaptureView()
}
