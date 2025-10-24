//
//  DevEntrypoing.swift
//  Neurocular
//
//  Created by Max Taggart on 5/26/25.
//

import SwiftUI

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
                
                if storage_manager.exams.count == 0 {
                    Divider()
                    Spacer()
                    Text("No Recordings")
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    List {
                        Section(header: Text("Recordings")) {
                            ForEach(storage_manager.exams) { exam_metadata in
                                NavigationLink(
                                    value: exam_metadata
                                ){
                                    SessionListItem(
                                        exam_metadata: exam_metadata
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: TestDestination.self) { _ in
                StationaryPhoneTest(
                    navigation_path: $navigation_path,
                    storage_manager: $storage_manager,
                    patient_info: nil
                )
            }
            .navigationDestination(for: ExamMetadata.self) { exam_metadata in
                SessionDetail(
                    exam_metadata: exam_metadata,
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
