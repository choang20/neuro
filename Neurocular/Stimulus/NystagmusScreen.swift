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
        await waitUntilStable(predicate: predicate, requiredFrames: 8)
    }

    private func waitUntilStable(predicate: @escaping (Float) -> Bool, requiredFrames: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var cancellable: AnyCancellable?
            var count = 0
            var graceMiss = 0 // ignore brief dips up to 2 frames
            cancellable = spatial_emitter.subject.sink { frame in
                if case .FaceDetected(let f) = frame {
                    var angle: Float? = nil
                    // Prefer raw zeroed yaw for gating; use smoothed only if needed
                    if let z = HeadYawTracker.shared.zeroedYaw(f.transforms) {
                        angle = z
                    } else if let d = HeadYawTracker.shared.update(with: f.transforms, isTracked: !f.wild_guess) {
                        angle = d
                    }
                    if let a = angle {
                        if predicate(a) {
                            count += 1
                            graceMiss = 0
                            if count >= requiredFrames {
                                cancellable?.cancel()
                                continuation.resume()
                            }
                        } else {
                            // allow brief misses to prevent resets from single bad frames
                            if graceMiss < 2 {
                                graceMiss += 1
                            } else {
                                count = 0
                                graceMiss = 0
                            }
                        }
                    }
                }
            }
        }
    }

    private func calibrateBaseline(seconds: Double = 1.2) async {
        var samples: [Float] = []
        var cancellable: AnyCancellable?
        cancellable = spatial_emitter.subject.sink { frame in
            if case .FaceDetected(let f) = frame {
                if !f.wild_guess {
                    let raw = headYawDegreesRelativeToCamera(f.transforms)
                    samples.append(raw)
                }
            }
        }
        // Non-blocking wait
        try? await Task.sleep(for: .seconds(seconds))
        cancellable?.cancel()
        if samples.count > 3 {
            let sorted = samples.sorted()
            let mid = sorted[sorted.count / 2]
            HeadYawTracker.shared.setBaseline(mid)
        } else if let first = samples.first {
            HeadYawTracker.shared.setBaseline(first)
        }
    }

    private func countToFive() async {
        speakQueued(["1","2","3","4","5"])
        try? await Task.sleep(for: .seconds(5))
    }

    private func runProgram() {
        Task {
            HeadYawTracker.shared.reset()
            // Calibrate baseline with a short median window
            await calibrateBaseline()
            speak("Slowly move your head as far as possible to the left while you look at the red dot.")
            await waitUntilStable(predicate: { abs($0) >= 40 }, requiredFrames: 4)
            speak("Hold this position; keep looking at the red dot.")
            await countToFive()
            speak("Now slowly turn your head all the way to the right while you look at the red dot.")
            await waitUntilStable(predicate: { abs($0) >= 40 }, requiredFrames: 4)
            speak("Hold this position; keep looking at the red dot.")
            await countToFive()
            // Optionally repeat cycles as needed
            dot_speed_subject.send(completion: .finished)
        }
    }

    private func finishNowAndShowResults() {
        // End recording immediately and navigate when the save completes
        dot_speed_subject.send(completion: .finished)
        Task {
            // Poll briefly until recorder finishes
            for _ in 0..<20 { // ~1s max
                if case .Finished(.success(let id)) = recorder.status,
                   let _ = storage_manager.get_exam_metadata_by_id(id) {
                    navigation_path.append(ResultRoute(examId: id, kind: "nystagmus"))
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
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
                        if case .Ready = recorder.status {
                            recorder.record()
                        }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("done") { finishNowAndShowResults() }
            }
        }
    }
}


