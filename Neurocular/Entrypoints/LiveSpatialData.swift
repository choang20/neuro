//
//  LiveSpatialData.swift
//  Neurocular
//
//  Created by Max Taggart on 6/23/25.
//

import SwiftUI

struct LiveSpatialData: View {
    @State private var spatial_emitter: SpatialDataEmitter? = nil
    @State private var current_spatial_frame: SpatialFrameData? = nil
    
    
    var body: some View {
        if let emitter = spatial_emitter {
            if let current_spatial_frame = current_spatial_frame {
                VStack {
                    SpatialDataOverlay(frame_data: $current_spatial_frame)
                    Button{
                        self.spatial_emitter = nil
                    } label: {
                        Text("End Session")
                    }
                }
            } else {
                ProgressView()
            }
        } else {
            Button{
                spatial_emitter = SpatialDataEmitter()
                Task {
                    for await frame_data in await spatial_emitter!.stream {
                        current_spatial_frame = frame_data
                    }
                }
            } label: {
                Text("Begin Session")
            }
        }
    }
}

#Preview {
    LiveSpatialData()
}
