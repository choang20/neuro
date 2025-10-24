//
//  Home.swift
//  Neurocular
//
//  Created by Max Taggart on 5/6/25.
//

import SwiftUI

struct SessionId: Identifiable, Hashable {
    let id: String
}
struct DemographicsDestination: Hashable {}

struct Home: View {
    
    @State private var navigation_path = NavigationPath()
    @State private var recordings: [Int] = []
    @State private var storage_manager = StorageManager()
    
    var body: some View {
        NavigationStack(path: $navigation_path) {
            VStack {
                HStack {
                    Spacer()
                    NavigationLink(value: DemographicsDestination()) {
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
                        Section(header: Text("Exams")) {
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
            .navigationDestination(for: DemographicsDestination.self) { _ in
                Demographics(
                    navigation_path: $navigation_path,
                    storage_manager: $storage_manager
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
    Home()
}
