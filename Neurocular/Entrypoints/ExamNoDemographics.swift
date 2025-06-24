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

struct ExamNoDemographics: View {
    @State private var navigation_path = NavigationPath()
    @State private var storage_manager = StorageManager()
    
    var body: some View {
        let _ = Self._printChanges()
        NavigationStack(path: $navigation_path) {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // Skip demographics and go straight to test
                        navigation_path.append(TestDestination())
                    }) {
                        Image(systemName: "plus.square")
                        Text("New Recording")
                    }
                }.padding()
                
                if storage_manager.session_list.count == 0 {
                    Divider()
                    Spacer()
                    Text("No Recordings")
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    let id_list = storage_manager.session_list.map { session in
                        session.id
                    }
                    List {
                        Section(header: Text("Recordings")) {
                            ForEach(storage_manager.session_list) { session in
                                NavigationLink(
                                    value: SessionId(id: session.id)
                                ){
                                    SessionListItem(
                                        session: session
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: TestDestination.self) { _ in
                Test(
                    navigation_path: $navigation_path,
                    patient_info: nil,
                    storage_manager: $storage_manager
                )
            }
            .navigationDestination(for: SessionId.self) { session_id in
                SessionDetail(
                    session_id: session_id.id,
                    navigation_path: $navigation_path,
                    storage_manager: $storage_manager
                )
            }
        }
    }
}

#Preview {
    ExamNoDemographics()
}
