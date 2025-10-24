////
////  SmoothPursuitTest.swift
////  Neurocular
////
////  Created by Max Taggart on 5/6/25.
////
//
//import SwiftUI
//import Combine
//
///*
// This test renders a dot that "ping pongs" back and forth across the screen at
// increasing velocity.
// */
//struct SmoothPursuitTest: View {
//    @State private var orientation_is_correct: Bool = false
//    @State private var rotation_instructions: String = "Please rotate your screen counterclockwise into landscape mode."
//    let dot_speed_subject = PassthroughSubject<TimestampedValue<CGFloat>, Never>()
//    let dot_position_subject = PassthroughSubject<TimestampedValue<CGPoint>, Never>()
//    let spatial_emitter: SpatialDataEmitter = SpatialDataEmitter()
//    
//    @Binding var navigation_path: NavigationPath
//    @Binding var storage_manager: StorageManager
//    @State private var face_detector: FaceDetector
//    @State private var recorder: TestRecorder
//    private var patient_info: PatientInfo?
//    
//    init(
//        navigation_path: Binding<NavigationPath>,
//        storage_manager: Binding<StorageManager>,
//        patient_info: PatientInfo?
//    ) {
//        self._navigation_path = navigation_path
//        self._storage_manager = storage_manager
//        self.patient_info = patient_info
//        let face_detector = FaceDetector(spatial_publisher: self.spatial_emitter.subject.eraseToAnyPublisher())
//        self.face_detector = face_detector
//        self.recorder = TestRecorder(
//            patient_info: patient_info,
//            dot_position_publisher: self.dot_position_subject.eraseToAnyPublisher(),
//            dot_speed_publisher: self.dot_speed_subject.eraseToAnyPublisher(),
//            spatial_face_publisher: face_detector.face_detected_frame_subject.eraseToAnyPublisher()
//        )
//    }
//    
//    var body: some View {
//        if !orientation_is_correct {
//            Text(rotation_instructions).onRotate { new_orientation in
//                switch new_orientation {
//                case .unknown:
//                    ()
//                case .portrait:
//                    orientation_is_correct = false
//                    rotation_instructions = "Please rotate your screen counterclockwise into landscape mode."
//                case .portraitUpsideDown:
//                    orientation_is_correct = false
//                    rotation_instructions = "Oops, too far."
//                case .landscapeLeft:
//                    orientation_is_correct = true
//                case .landscapeRight:
//                    orientation_is_correct = false
//                    rotation_instructions = "Other way."
//                case .faceUp:
//                    ()
//                case .faceDown:
//                    ()
//                case _:
//                    ()
//                }
//            }
//        } else if !self.face_detector.face_detected{
//            Text("No face detected yet")
//        } else {
//            switch self.recorder.status {
//            case .Ready, .Recording:
//                Stimulus(
//                    dot_speed_publisher: dot_speed_subject.eraseToAnyPublisher(),
//                    dot_position_subject: dot_position_subject
//                )
//                .overlay {
//                    SpatialDataOverlay(spatial_frame_publisher: spatial_emitter.subject.eraseToAnyPublisher())
//                }
//                .onAppear {
//                    self.recorder.record()
//                }.task {
//                    // Start emitting speeds
//                    let dot_speed_controller = DotSpeedController(
//                        dot_speed_subject: self.dot_speed_subject,
//                        spatial_publisher: self.spatial_emitter.subject.eraseToAnyPublisher()
//                    )
//                    await dot_speed_controller.emit_speeds()
//                }
//            case .Saving:
//                VStack {
//                    ProgressView()
//                    Text("Saving...")
//                }
//            case .Finished(_):
//                Text("Done").task {
//                    try! await Task.sleep(for: .seconds(1))
//                    navigation_path.removeLast(navigation_path.count)
//                }
//            }
//            
//        }
//        
//    }
//}
//
///**
// Has two jobs:
// 1. Help gate access to the exam until after a face is first detected.
// 2. Convert a stream of SpatialFrameData into FrameFaceData, i.e. only emit face-tracking frame data, which will only happen once a face has been detected.
// */
//@Observable
//class FaceDetector {
//    var face_detected: Bool = false
//    @ObservationIgnored
//    var face_detected_frame_subject = PassthroughSubject<FrameFaceData, Never>()
//    private var cancellables: Set<AnyCancellable> = Set()
//    
//    init(spatial_publisher: AnyPublisher<SpatialFrameData, Never>) {
//        spatial_publisher.sink { frame in
//            switch frame {
//            case .NoFaceDetected:
//                ()
//            case .FaceDetected(let frameFaceData):
//                if !self.face_detected {
//                    self.face_detected = true
//                }
//                self.face_detected_frame_subject.send(frameFaceData)
//            }
//        }.store(in: &cancellables)
//    }
//    
//    
//}
//
//class DotSpeedController {
//    let dot_speed_subject: PassthroughSubject<TimestampedValue<CGFloat>, Never>
//    let spatial_publisher: AnyPublisher<SpatialFrameData, Never>
//    private var cancellation: AnyCancellable! = nil
//    
//    init(
//        dot_speed_subject: PassthroughSubject<TimestampedValue<CGFloat>, Never>,
//        spatial_publisher: AnyPublisher<SpatialFrameData, Never>
//    ) {
//        self.dot_speed_subject = dot_speed_subject
//        self.spatial_publisher = spatial_publisher
//    }
//    
//    func emit_speeds() async {
//        try! await Task.sleep(for: .seconds(1))
//        // Ramp up the speeds linearly over some time interval. Spee
//        let start_speed_degrees: Float = 3.0
//        let end_speed_degrees: Float = 30.0
//        let exam_duration_seconds: Float = 10.0
//        let exam_start = Date()
//        var previous_distance: Float = 0.0
//        let iPhone14_ppi: Float = 460.0
//        var exam_finished = false
//        self.cancellation = spatial_publisher.sink { spatial_frame in
//            if exam_finished {
//                return
//            }
//            let eye_distance_from_screen_inches = switch spatial_frame {
//            case .NoFaceDetected:
//                // If no face is detected use the previous distance
//                previous_distance
//            case .FaceDetected(let frameFaceData):
//                calculate_distance_from_screen(from_transforms: frameFaceData.transforms)
//            }
//            // Hold onto the last distance so we can use it in case the phone loses
//            // track of the subject's face momentarily
//            previous_distance = eye_distance_from_screen_inches
//            let current_time = Date()
//            let current_degrees_per_second = self.interpolate_linear(
//                elapsed: Float(current_time.timeIntervalSince(exam_start)),
//                total_duration: exam_duration_seconds,
//                start: start_speed_degrees,
//                end: end_speed_degrees
//            )
//            if current_degrees_per_second == end_speed_degrees {
//                self.dot_speed_subject.send(completion: .finished)
//                exam_finished = true
//                return
//            }
//            let current_pixels_per_second = iPhone14_ppi * eye_distance_from_screen_inches * tan(Float.pi / 180.0) * current_degrees_per_second
//            self.dot_speed_subject.send(TimestampedValue.from(CGFloat(current_pixels_per_second)))
//        }
//    }
//    
//    
//    private func interpolate_linear(
//        elapsed: Float, total_duration: Float, start: Float, end: Float
//    ) -> Float {
//        let relative_time = elapsed / total_duration
//        if relative_time < 0 {
//            return start
//        }
//        if relative_time > 1 {
//            return end
//        }
//        let current = (end - start) * relative_time + start
//        return current
//    }
//}
//
//// Our custom view modifier to track rotation and
//// call our action
//struct DeviceRotationViewModifier: ViewModifier {
//    let action: (UIDeviceOrientation) -> Void
//
//    func body(content: Content) -> some View {
//        content
//            .onAppear()
//            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
//                action(UIDevice.current.orientation)
//            }
//    }
//}
//
//// A View wrapper to make the modifier easier to use
//extension View {
//    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
//        self.modifier(DeviceRotationViewModifier(action: action))
//    }
//}
//
////#Preview {
////    Test(
////        navigation_path: .constant(NavigationPath()),
////        patient_info: nil,
////        storage_manager: .constant(StorageManager())
////    )
////}
