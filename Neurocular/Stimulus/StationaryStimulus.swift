//
//  StationaryStimulus.swift
//  Neurocular
//
//  Created by Max Taggart on 8/19/25.
//

import SwiftUI

struct StationaryStimulus: View {
    let diameter: CGFloat = targetDotDiameterPixels()
    var body: some View {
        VStack {
            Rectangle()
                .fill(.white)
                .frame(maxWidth: .infinity, maxHeight: 800)
                .overlay {
                    VStack {
                        Spacer()
                        ZStack {
                            Circle().fill(.red)
                            Circle().fill(.black).frame(width: diameter * 0.25, height: diameter * 0.25)
                        }
                        .frame(width: diameter, height: diameter)
                            .padding(.bottom)
                            .padding(.top)
                        Text("Recording is active.")
                            .padding(.top)
                        Spacer()
                        Spacer()
                    }
                }
        }
    }
}

#Preview {
    StationaryStimulus()
}
