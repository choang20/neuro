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
    let patient_info = PatientInfo(
        first_name: "Test", last_name: "Patient", birth_date: Date(), sex: .Male, race: .White, ethnicity: .NotHispanic
    )
    
    var body: some View {
        Test(
            navigation_path: .constant(NavigationPath()),
            patient_info: patient_info,
            storage_manager: StorageManager()
        )
    }
}

#Preview {
    DevEntrypoint()
}
