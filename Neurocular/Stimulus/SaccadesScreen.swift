//
//  SaccadesScreen.swift
//  Neurocular
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import Combine

struct SaccadesScreen: View {
    @Binding var navigation_path: NavigationPath
    @Binding var storage_manager: StorageManager

    @State private var face_detector: FaceDetector
    @State private var recorder: TestRecorder
    private let spatial_emitter = SpatialDataEmitter()

    private let dot_speed_subject = PassthroughSubject<TimestampedValue<CGFloat>, Never>()
    private let dot_position_subject = PassthroughSubject<TimestampedValue<CGPoint>, Never>()

    init(navigation_path: Binding<NavigationPath>, storage_manager: Binding<StorageManager>) {
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager
        let fd = FaceDetector(spatial_publisher: spatial_emitter.subject.eraseToAnyPublisher())
        self._face_detector = State(initialValue: fd)
        self._recorder = State(initialValue: TestRecorder(
            patient_info: nil,
            dot_position_publisher: dot_position_subject.eraseToAnyPublisher(),
            dot_speed_publisher: dot_speed_subject.eraseToAnyPublisher(),
            spatial_face_publisher: fd.face_detected_frame_subject.eraseToAnyPublisher(),
            storage_manager: storage_manager.wrappedValue
        ))
    }

    private func runProgram() {
        Task {
            // Drive three speed blocks at 5/15/30 deg/s using moving stimulus
            var lastInches: Float = 20
            let speedsDeg: [Float] = [5, 15, 30]
            let ppi: Float = 460
            let travel = Float(UIScreen.main.bounds.width - 40)

            let cancel = spatial_emitter.subject.sink { frame in
                if case .FaceDetected(let f) = frame {
                    lastInches = calculate_distance_from_screen(from_transforms: f.transforms)
                }
            }

            for deg in speedsDeg {
                let pxPerSec = max(1, ppi * lastInches * tan(Float.pi / 180.0) * deg)
                let secondsPerExcursion = travel / pxPerSec
                // Two round trips per block
                for _ in 0..<2 {
                    dot_speed_subject.send(TimestampedValue.from(CGFloat(pxPerSec)))
                    try? await Task.sleep(for: .seconds(Double(secondsPerExcursion * 2)))
                }
            }

            dot_speed_subject.send(completion: .finished)
            cancel.cancel()
        }
    }

    var body: some View {
        TestScaffold(
            title: "saccades",
            instructionsText: "Do not wear glasses. A red dot will appear at random locations on the screen. Don't move your head as you look at the red dot with your eyes. A yellow button will appear when the test is completed.",
            recordingStatus: recorder.status,
            makeStimulus: {
                BackAndForthStimulus(
                    dot_speed_publisher: dot_speed_subject.eraseToAnyPublisher(),
                    dot_position_subject: dot_position_subject
                )
                    .onAppear {
                        // Start recording when stimulus appears
                        recorder.record()
                    }
            },
            startTest: { runProgram() },
            onFinish: {
                if case .Finished(.success(let id)) = recorder.status,
                   let _ = storage_manager.get_exam_metadata_by_id(id) {
                    navigation_path.append(ResultRoute(examId: id, kind: "saccades"))
                } else {
                    navigation_path.removeLast(navigation_path.count)
                }
            },
            layout: .stacked
        )
    }
}


