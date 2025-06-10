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
                
                if storage_manager.session_list.count == 0 {
                    Divider()
                    Spacer()
                    Text("No Recordings")
                        .foregroundStyle(.gray)
                    Spacer()
                } else {
                    List {
                        Section(header: Text("Recordings")) {
                            ForEach(storage_manager.session_list) { session in
                                NavigationLink(
                                    value: SessionId(id: session.id)
                                ){
                                    SessionListItem(
                                        session: session,
                                        storage_manager: storage_manager
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
                    storage_manager: storage_manager
                )
            }
            .navigationDestination(for: SessionId.self) { session_id in
                SessionDetail(
                    session: storage_manager.get_session_by_id(session_id.id),
//                            storage_manager: storage_manager,
                    navigation_path: $navigation_path)
            }
        }
    }
}



#Preview {
    Home()
}
