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
                    Circle()
                        .fill(.red)
                        .frame(width: 40, height: 40)
                        .position(position)
                }
        }
        .onReceive(positionPublisher) { v in
            self.position = v.value
        }
    }
}


