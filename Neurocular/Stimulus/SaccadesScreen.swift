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
            // Deterministic step sequence in degrees relative to screen center
            let sequenceDeg: [Double] = [
                0, 10, 0, -10, 0, 10, 0, -10, 0
            ]
            let holdSeconds: Double = 2.0
            let centerY = UIScreen.main.bounds.midY
            for ang in sequenceDeg {
                let x = degreesToScreenX(ang)
                let pt = CGPoint(x: x, y: centerY)
                dot_position_subject.send(TimestampedValue.from(pt))
                dot_speed_subject.send(TimestampedValue.from(0))
                try? await Task.sleep(for: .seconds(holdSeconds))
            }
            dot_speed_subject.send(completion: .finished)
        }
    }

    // Convert desired horizontal visual angle (deg) to screen X (points)
    private func degreesToScreenX(_ deg: Double) -> CGFloat {
        let midX = Double(UIScreen.main.bounds.midX)
        let ppi = 460.0 // estimated
        let scale = Double(UIScreen.main.scale) // points→pixels
        let distanceInches = 600.0 / 25.4 // 60 cm
        // inches offset using small-angle geometry: x = d * tan(theta)
        let inchesX = distanceInches * tan(deg * .pi / 180.0)
        let pixels = inchesX * ppi
        let points = pixels / scale
        // Clamp within safe margins
        let minX = 20.0
        let maxX = Double(UIScreen.main.bounds.width) - 20.0
        let x = max(minX, min(maxX, midX + points))
        return CGFloat(x)
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


