//
//  CameraView.swift
//  DBD Perks
//
//  Created by Alif on 29/10/25.
//

import SwiftUI

struct CameraView: View {
    
    @Binding var image: CGImage?
    @Binding var viewSize: CGSize
    /// nil in auto mode: nothing to line up.
    let layout: PerkSlotLayout?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                        .clipped()
                } else {
                    ContentUnavailableView("No camera feed", systemImage: "xmark.circle.fill")
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                }
                
                if let layout {
                    PerkSlotOverlay(slots: layout.slots(in: geometry.size))
                        .allowsHitTesting(false)
                }
            }
            .onAppear { viewSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in viewSize = newSize }
        }
        .ignoresSafeArea()
    }
}

/// Dims everything except the four perk diamonds and outlines each one.
struct PerkSlotOverlay: View {
    let slots: [PerkSlot]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .mask {
                    Rectangle()
                        .overlay {
                            ForEach(slots.indices, id: \.self) { index in
                                slotShape(slots[index])
                                    .frame(width: slots[index].diagonal, height: slots[index].diagonal)
                                    .position(slots[index].center)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                }
            
            ForEach(slots.indices, id: \.self) { index in
                slotShape(slots[index])
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: slots[index].diagonal, height: slots[index].diagonal)
                    .position(slots[index].center)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .overlay {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                            .position(x: slots[index].center.x,
                                      y: slots[index].center.y - slots[index].diagonal / 2 - 10)
                    }
            }
        }
    }
}

extension PerkSlotOverlay {
    private func slotShape(_ slot: PerkSlot) -> AnyShape {
        slot.shape == .square ? AnyShape(RoundedRectangle(cornerRadius: 8)) : AnyShape(DiamondShape())
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CameraView(image: .constant(CGImage.mock()), viewSize: .constant(.zero), layout: .diamond)
}
