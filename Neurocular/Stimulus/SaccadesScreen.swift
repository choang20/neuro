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
            // Random positions along a horizontal line: 2 seconds x 8 times
            let y = UIScreen.main.bounds.height / 2
            let minX: CGFloat = 30
            let maxX: CGFloat = UIScreen.main.bounds.width - 30
            for _ in 0..<8 {
                let x = CGFloat.random(in: minX...maxX)
                dot_position_subject.send(TimestampedValue.from(CGPoint(x: x, y: y)))
                dot_speed_subject.send(TimestampedValue.from(0))
                try? await Task.sleep(for: .seconds(2))
            }
            dot_speed_subject.send(completion: .finished)
        }
    }

    var body: some View {
        TestScaffold(
            title: "saccades",
            instructionsText: "Do not wear glasses. A red dot will appear at random locations on the screen. Don't move your head as you look at the red dot with your eyes. A yellow button will appear when the test is completed.",
            recordingStatus: recorder.status,
            makeStimulus: {
                SaccadeStimulusView(positionPublisher: dot_position_subject.eraseToAnyPublisher())
                    .onAppear {
                        // Initialize at center and start recording (once)
                        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                        dot_position_subject.send(TimestampedValue.from(center))
                        dot_speed_subject.send(TimestampedValue.from(0))
                        if case .Ready = recorder.status {
                            recorder.record()
                        }
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


