//
//  DevEntrypoing.swift
//  Neurocular
//
//  Created by Max Taggart on 5/26/25.
//

import SwiftUI

// Spatial Data Overlay
//struct DevEntrypoint: View {
//    let spatial_emitter: SpatialDataEmitter = SpatialDataEmitter()
//    @State private var latest_frame: SpatialFrameData = .NoFaceDetected
//    
//    var body: some View {
//        SpatialDataOverlay(frame_data: $latest_frame).task {
//            for await frame_data in await spatial_emitter.stream {
//                latest_frame = frame_data
//            }
//        }
//    }
//}

struct DevEntrypoint: View {
    let spatial_emitter: SpatialDataEmitter = SpatialDataEmitter()
    @State private var latest_frame: SpatialFrameData = .NoFaceDetected
    
    var body: some View {
        Test()
    }
}

#Preview {
    DevEntrypoint()
}
