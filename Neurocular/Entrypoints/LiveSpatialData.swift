//
//  LiveSpatialData.swift
//  Neurocular
//
//  Created by Max Taggart on 6/23/25.
//

import SwiftUI

struct LiveSpatialData: View {
    @State private var spatial_emitter: SpatialDataEmitter? = nil
    
    
    var body: some View {
        if let emitter = self.spatial_emitter {
            VStack {
                SpatialDataOverlay(spatial_frame_publisher: emitter.subject.eraseToAnyPublisher())
                Button{
                    self.spatial_emitter = nil
                } label: {
                    Text("End Session")
                }
            }
        } else {
            Button{
                self.spatial_emitter = SpatialDataEmitter()
            } label: {
                Text("Begin Session")
            }
        }
    }
}

#Preview {
    LiveSpatialData()
}
