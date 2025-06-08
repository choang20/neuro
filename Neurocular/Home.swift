//
//  Home.swift
//  Neurocular
//
//  Created by Max Taggart on 5/6/25.
//

import SwiftUI

struct Home: View {
    
    @State private var navigation_path = NavigationPath()
    @State private var recordings: [Int] = []
    
    var body: some View {
        NavigationStack(path: $navigation_path) {
            VStack {
                HStack {
                    Spacer()
                    NavigationLink(value: DemographicsNavInfo()) {
                        Image(systemName: "plus.square")
                        Text("New Recording")
                    }
                    .navigationDestination(for: DemographicsNavInfo.self) { _ in
                        Demographics(navigation_path: $navigation_path)
                    }
                }.padding()
                
                Divider()
                Spacer()
                Text("No Recordings")
                    .foregroundStyle(.gray)
                Spacer()
            }
        }
    }
}

#Preview {
    Home()
}
