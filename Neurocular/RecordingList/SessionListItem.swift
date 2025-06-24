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
    struct MetadataDateFormatter {
        var formatter = DateFormatter()
        
        init() {
            self.formatter.dateStyle = .long
            self.formatter.timeStyle = .short
        }
    }
    
    let date_formatter = MetadataDateFormatter()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date_formatter.formatter.string(from: session.created))
                
                if session.notes.isEmpty {
                    Text("No notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(session.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

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
