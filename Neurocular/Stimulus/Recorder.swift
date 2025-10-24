//
//  Recorder.swift
//  Neurocular
//
//  Created by Max Taggart on 6/28/25.
//

import Foundation
import Combine
import UIKit



enum RecordingStatus {
    case Ready
    case Recording
    case Saving
    case Finished(Result<ExamId, Error>)
}

@Observable
class TestRecorder {
    var status: RecordingStatus = .Ready
    private var patient_info: PatientInfo?
    private var dot_position_publisher: AnyPublisher<TimestampedValue<CGPoint>, Never>
    private var dot_speed_publisher: AnyPublisher<TimestampedValue<CGFloat>, Never>
    private var spatial_face_publisher: AnyPublisher<FrameFaceData, Never>
    private var storage_manager: StorageManager
    private var positions: [TimestampedValue<Point>] = []
    private var speeds: [TimestampedValue<Double>] = []
    private var transforms: [SpatialTransforms] = []
    private var cancellables =  Set<AnyCancellable>()
    
    init(
        patient_info: PatientInfo?,
        dot_position_publisher: AnyPublisher<TimestampedValue<CGPoint>, Never>,
        dot_speed_publisher: AnyPublisher<TimestampedValue<CGFloat>, Never>,
        spatial_face_publisher: AnyPublisher<FrameFaceData, Never>,
        storage_manager: StorageManager
    ) {
        self.patient_info = patient_info
        self.dot_position_publisher = dot_position_publisher
        self.dot_speed_publisher = dot_speed_publisher
        self.spatial_face_publisher = spatial_face_publisher
        self.storage_manager = storage_manager
    }
    
    /**
     Note that the dot position, the dot speed, and the spatial frame data should all be published at the
     same rate, i.e. 60hz. But, in reality, they may not be published at exactly that rate, and they
     certainly aren't published at exactly the same time. So the recorder records the streams separately
     and relies on the FrameInterpolator to create a single, interpolated timeline where target position
     and speed are interpolated at the spatial frame timestamps.
     
     The recording ends when the `dot_speed_publisher` completes, indicating that the test has
     finished.
     */
    func record() {
        // Ignore any data that comes from the publishers with a timestamp
        // before recording began (this will usually mean the publisher's
        // value was a default).
        let recording_started = Date()
        let exam_id = NSUUID().uuidString.lowercased()
    
        // Subscribe to updates and filter out values with timestamps less that `recording_started`.
        dot_position_publisher.sink {v in
            if v.timestamp < recording_started {
                return
            }
            self.positions.append(TimestampedValue(timestamp: v.timestamp, value: Point(x: v.value.x, y: v.value.y)))
        }.store(in: &cancellables)
        dot_speed_publisher.sink { completion in
            switch completion {
            case .failure(_):
                ()
            case .finished:
                self.status = .Saving
                self.storage_manager.add_exam(
                    metadata: ExamMetadata(
                        id: exam_id,
                        demographics: self.patient_info,
                        created: recording_started,
                        notes: ""
                    ),
                    frames: ExamFrames(
                        exam_id: exam_id,
                        spatial_transforms: self.transforms,
                        stimulus_positions: self.positions,
                        stimulus_speeds: self.speeds
                    )
                )
                self.status = .Finished(.success(exam_id))
            }
        } receiveValue: { v in
            if v.timestamp < recording_started {
                return
            }
            self.speeds.append(TimestampedValue(timestamp: v.timestamp, value: v.value))
        }.store(in: &cancellables)
        spatial_face_publisher.sink {face_data in
            if face_data.timestamp < recording_started {
                return
            }
            self.transforms.append(SpatialTransforms(transforms: face_data.transforms, wild_guess: face_data.wild_guess, timestamp: face_data.timestamp))
        }.store(in: &cancellables)
        self.status = .Recording
    }
}
