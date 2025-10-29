//
//  NystagmusScreen.swift
//  Neurocular
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import Combine

struct NystagmusScreen: View {
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

    private func waitUntil(_ predicate: @escaping (Float) -> Bool) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var cancellable: AnyCancellable?
            cancellable = spatial_emitter.subject.sink { frame in
                if case .FaceDetected(let f) = frame {
                    if let deg = HeadYawTracker.shared.update(with: f.transforms, isTracked: !f.wild_guess) {
                        if predicate(deg) {
                            cancellable?.cancel()
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func countToFive() async {
        speakQueued(["1","2","3","4","5"])
        try? await Task.sleep(for: .seconds(5))
    }

    private func runProgram() {
        Task {
            HeadYawTracker.shared.reset()
            speak("Slowly move your head as far as possible to the left while you look at the red dot.")
            await waitUntil { $0 <= -45 }
            speak("Hold this position; keep looking at the red dot.")
            await countToFive()
            speak("Now slowly turn your head all the way to the right while you look at the red dot.")
            await waitUntil { $0 >= 45 }
            speak("Hold this position; keep looking at the red dot.")
            await countToFive()
            // Optionally repeat cycles as needed
            dot_speed_subject.send(completion: .finished)
        }
    }

    var body: some View {
        TestScaffold(
            title: "nystagmus",
            instructionsText: "Turn your head slowly left to at least 45°, hold 5 seconds; then right to at least 45°, hold 5 seconds. Keep eyes on the red dot.",
            recordingStatus: recorder.status,
            makeStimulus: {
                StationaryStimulus()
                    .overlay {
                        SpatialDataOverlay(spatial_frame_publisher: spatial_emitter.subject.eraseToAnyPublisher())
                    }
                    .onAppear {
                        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
                        dot_position_subject.send(TimestampedValue.from(center))
                        dot_speed_subject.send(TimestampedValue.from(0))
                        recorder.record()
                    }
            },
            startTest: { runProgram() },
            onFinish: {
                if case .Finished(.success(let id)) = recorder.status,
                   let _ = storage_manager.get_exam_metadata_by_id(id) {
                    navigation_path.append(ResultRoute(examId: id, kind: "nystagmus"))
                } else {
                    navigation_path.removeLast(navigation_path.count)
                }
            },
            layout: .stacked
        )
    }
}


