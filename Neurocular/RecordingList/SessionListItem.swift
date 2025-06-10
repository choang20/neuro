//
//  RecordingListItem.swift
//  emphairmint
//
//  Created by Max Taggart on 2/23/25.
//

import SwiftUI
import AVFoundation

struct SessionListItem: View {
    let session: Session
    let storage_manager: StorageManager
    struct MetadataDateFormatter {
        var formatter = DateFormatter()
        
        init() {
            self.formatter.dateStyle = .long
            self.formatter.timeStyle = .short
        }
    }
    
    let date_formatter = MetadataDateFormatter()
    var body: some View {
//        if app_config.print_changes {let _ = Self._printChanges()}
        HStack {
            VStack(alignment: .leading) {
                Text(date_formatter.formatter.string(from: session.created))
                Text("\(session.demographics.first_name) \(session.demographics.last_name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(session.id.prefix(8))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


//#Preview {
//    let storage_manager = StorageManager.for_preview()
//    RecordingListItem(
//        recording_metadata: TestMetadata(
//            id: "8f22b27f-02db-4cd0-963f-da98e9207732",
//            created: Date(),
//            created_by: "max.taggart@gmail.com",
//            metadata_synced: true,
//            video_synced: true,
//            transforms_synced: true
//        ),
//        storage_manager: storage_manager
//    )
//}
