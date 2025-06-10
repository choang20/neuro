//
//  StorageManager.swift
//  Neurocular
//
//  Created by Max Taggart on 6/8/25.
//

import Foundation


struct Row: Codable {
    let transforms: Transforms
    let degrees_per_second: Int
}

struct Session: Codable, Identifiable {
    let id: String
    let demographics: PatientInfo
    let rows: [Row]
    let created: Date
    
    static func from_url(_ url: URL) -> Session {
        let file_contents = try! Data.init(contentsOf: url)
        return try! JSONDecoder().decode(Session.self, from: file_contents)
    }
}


@Observable
class StorageManager {
    var session_list: [Session] = []
    var data_dir = URL(string: "recordings/", relativeTo: URL.documentsDirectory)!
    
    init() {
        ensure_directory_exists(self.data_dir)
        self.session_list = get_all_sessions()
    }
    
    func add_session(_ session: Session) {
        var filename = "\(session.demographics.first_name)_\(session.demographics.last_name).json"
        var file_url = URL(string: filename, relativeTo: self.data_dir)!
        var counter = 0
        while file_exists(at_url: file_url) {
            counter += 1
            filename = "\(session.demographics.first_name)_\(session.demographics.last_name)_\(counter).json"
            file_url = URL(string: filename, relativeTo: self.data_dir)!
        }
        let json_encoded = try! JSONEncoder().encode(session)
        try! json_encoded.write(to: file_url)
        session_list = get_all_sessions()
    }
    
    func get_session_by_id(_ id: String) -> Session {
        session_list.first {candidate in candidate.id == id}!
    }
    
    func get_all_sessions() -> [Session] {
        return try! FileManager.default.contentsOfDirectory(
            at: data_dir,
            includingPropertiesForKeys: []
        )
        .map(Session.from_url)
        .sorted { a, b in
            // A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
            a.created > b.created
        }
    }
    
    private func file_exists(at_url url: URL) -> Bool {
        var is_dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &is_dir)
    }
    
    private func ensure_directory_exists(_ directory: URL) {
        var is_dir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &is_dir) {
            // The directory doesn't exist, create it
            try! FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } else {
            if !is_dir.boolValue {
                // There is some other object at this path, remove it and create the directory
                try! FileManager.default.removeItem(at: directory)
                ensure_directory_exists(directory)
            }
        }
    }
}
