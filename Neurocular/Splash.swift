//
//  ContentView.swift
//  Neurocular
//
//  Created by Max Taggart on 5/5/25.
//

import SwiftUI
import Foundation

struct Splash: View {
    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 300, height: 300)
                .offset(x: 0, y: -50)
        }
        .padding()
    }
}

#Preview {
    Splash()
}
