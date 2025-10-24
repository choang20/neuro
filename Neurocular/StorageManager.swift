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

typealias ExamId = String

struct Point: Codable, Equatable {
    let x: Double
    let y: Double
}

struct SpatialTransforms: Codable, Equatable {
    let transforms: Transforms
    let wild_guess: Bool
    let timestamp: Date
}

struct TimestampedValue<T>: Codable
    where T: Codable
{
    let timestamp: Date
    let value: T
    
    static func from(_ value: T) -> Self {
        return TimestampedValue (timestamp: Date(), value: value)
    }
}

/**
 The idea is to ensure that this data type is light weight and usable as a
 NavigationDestination's `value`, which means it needs to be Codable,
 Identifiable, and Hashable.
 */
struct ExamMetadata: Codable, Identifiable, Hashable {
    let id: ExamId
    let demographics: PatientInfo?
    let created: Date
    var notes: String
    
    static func from(url: URL) -> ExamMetadata {
        let file_contents = try! Data.init(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(ExamMetadata.self, from: file_contents)
    }

    func write(to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json_encoded = try! encoder.encode(self)
        try! json_encoded.write(to: url)
    }
    
    
    static func new() -> ExamMetadata {
        return ExamMetadata(
            id: UUID().uuidString,
            demographics: nil,
            created: Date(),
            notes: ""
        )
    }

    static func new(withDemographics demographics: PatientInfo) -> ExamMetadata {
        return ExamMetadata(
            id: UUID().uuidString,
            demographics: demographics,
            created: Date(),
            notes: ""
        )
    }
}

struct ExamFrames: Codable {
    let exam_id: ExamId
    let spatial_transforms: [SpatialTransforms]
    let stimulus_positions: [TimestampedValue<Point>]
    let stimulus_speeds: [TimestampedValue<Double>]
    
    static func from(url: URL) -> ExamFrames {
        let file_contents = try! Data.init(contentsOf: url)
        return try! JSONDecoder().decode(ExamFrames.self, from: file_contents)
    }

    func write(to url: URL) {
        let json_encoded = try! JSONEncoder().encode(self)
        try! json_encoded.write(to: url)
    }
}


@Observable
class StorageManager {
    var exams: [ExamMetadata] = []
    private var metadata_dir: URL!
    private var frames_dir: URL!
    
    init() {
        let base_dir = URL(string: "exams/", relativeTo: URL.documentsDirectory)!
        self.ensure_data_dirs(base_dir)
        self.exams = get_all_exams()
    }
    
    init(with_base_dir base_dir: URL) {
        self.ensure_data_dirs(base_dir)
        self.exams = get_all_exams()
    }
    
    func ensure_data_dirs(_ base_dir: URL) {
        self.metadata_dir = URL(string: "metadata/", relativeTo: base_dir)!
        self.frames_dir = URL(string: "frames/", relativeTo: base_dir)!
        ensure_directory_exists(self.metadata_dir)
        ensure_directory_exists(self.frames_dir)
    }
    
    func add_exam(metadata: ExamMetadata, frames: ExamFrames) {
        let filename = "\(metadata.id).json"
        let metadata_file_url = URL(string: filename, relativeTo: self.metadata_dir)!
        metadata.write(to: metadata_file_url)
        let frames_file_url = URL(string: filename, relativeTo: self.frames_dir)!
        frames.write(to: frames_file_url)
        exams = get_all_exams()
    }
    
    func update_exam(metadata: ExamMetadata) {
        let metadata_filename = "\(metadata.id).json"
        let metadata_file_url = URL(string: metadata_filename, relativeTo: self.metadata_dir)!
        metadata.write(to: metadata_file_url)
        exams = get_all_exams()
    }
    
    func get_exam_metadata_by_id(_ id: ExamId) -> ExamMetadata? {
        exams.first {candidate in candidate.id == id}
    }

    func get_exam_frames_by_id(_ id: ExamId) -> ExamFrames? {
        let frames_filename = "\(id).json"
        guard let frames_file_url = URL(string: frames_filename, relativeTo: self.frames_dir) else {
            return nil
        }
        return ExamFrames.from(url: frames_file_url)
    }
    
    func get_all_exams() -> [ExamMetadata] {
        return try! FileManager.default.contentsOfDirectory(
            at: self.metadata_dir,
            includingPropertiesForKeys: []
        )
        .map(ExamMetadata.from)
        .sorted { a, b in
            // A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
            a.created > b.created
        }
    }
    
    func delete_exam(id: ExamId){
        let filename = "\(id).json"
        let metadata_file_url = URL(string: filename, relativeTo: self.metadata_dir)!
        if file_exists(at_url: metadata_file_url) {
            try! FileManager.default.removeItem(at: metadata_file_url)
        }
        let frames_file_url = URL(string: filename, relativeTo: self.frames_dir)!
        if file_exists(at_url: frames_file_url) {
            try! FileManager.default.removeItem(at: frames_file_url)
        }
        exams = get_all_exams()
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
