//
//  StationaryStimulus.swift
//  Neurocular
//
//  Created by Max Taggart on 8/19/25.
//

import SwiftUI

struct StationaryStimulus: View {
    let diameter: CGFloat = 30
    var body: some View {
        VStack {
            Rectangle()
                .fill(.white)
                .frame(maxWidth: .infinity, maxHeight: 800)
                .overlay {
                    VStack {
                        Spacer()
                        Circle()
                            .fill(.blue)
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
