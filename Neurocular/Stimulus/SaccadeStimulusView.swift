//
//  SaccadeStimulusView.swift
//  Neurocular
//
//

import SwiftUI
import Combine

struct SaccadeStimulusView: View {
    let positionPublisher: AnyPublisher<TimestampedValue<CGPoint>, Never>
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.white)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .overlay {
                    let d = targetDotDiameterPixels()
                    ZStack {
                        Circle().fill(.red)
                        Circle().fill(.black).frame(width: d * 0.25, height: d * 0.25)
                    }
                    .frame(width: d, height: d)
                    .position(position)
                }
        }
        .onReceive(positionPublisher) { v in
            self.position = v.value
        }
    }
}


