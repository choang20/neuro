//
//  SmoothPursuitScreen.swift
//  Neurocular
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import Combine

struct SmoothPursuitScreen: View {
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
            // Use fixed pixel-per-second speeds (duplicate each for two excursions)
            let speedsPx: [CGFloat] = [200, 600, 1200]  // adjust as needed
            let travel = CGFloat(UIScreen.main.bounds.width - 40)

            for pxPerSec in speedsPx {
                let secondsPerExcursion = travel / pxPerSec
                // Three round trips (back-and-forth) at this speed → 3 × 2 excursions
                for _ in 0..<3 {
                    // send immediately so motion starts without delay
                    dot_speed_subject.send(TimestampedValue.from(pxPerSec))
                    try? await Task.sleep(for: .seconds(Double(secondsPerExcursion * 2)))
                }
            }

            dot_speed_subject.send(completion: .finished)
        }
    }

    var body: some View {
        TestScaffold(
            title: "smooth pursuit",
            instructionsText: "Do not wear glasses. Hold the phone at a comfortable reading distance. Don't move your head as you follow the red dot with your eyes. A yellow button will appear when the test is completed.",
            recordingStatus: recorder.status,
            makeStimulus: {
                BackAndForthStimulus(
                    dot_speed_publisher: dot_speed_subject.eraseToAnyPublisher(),
                    dot_position_subject: dot_position_subject
                )
                .onAppear {
                    if case .Ready = recorder.status {
                        recorder.record()
                    }
                }
            },
            startTest: { runProgram() },
            onFinish: {
                if case .Finished(.success(let id)) = recorder.status,
                   let _ = storage_manager.get_exam_metadata_by_id(id) {
                    navigation_path.append(ResultRoute(examId: id, kind: "smooth"))
                } else {
                    navigation_path.removeLast(navigation_path.count)
                }
            },
            layout: .stacked
        )
    }
}


