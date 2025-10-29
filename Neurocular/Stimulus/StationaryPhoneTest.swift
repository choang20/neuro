//
//  SmoothPursuitTest.swift
//  Neurocular
//
//  Created by Max Taggart on 5/6/25.
//

import SwiftUI
import Combine

struct StationaryPhoneTest: View {
    @State private var orientation = UIDevice.current.orientation
    // Always zero for this test. Value is set in the constructor.
    private var dot_speed_subject: CurrentValueSubject<TimestampedValue<CGFloat>, Never>!
    // Always constant in this test. Value is set in the constructor.
    private var dot_position_subject: CurrentValueSubject<TimestampedValue<CGPoint>, Never>!
    let spatial_emitter: SpatialDataEmitter = SpatialDataEmitter()
    
    @Binding var navigation_path: NavigationPath
    @Binding var storage_manager: StorageManager
    @State private var face_detector: FaceDetector
    @State private var recorder: TestRecorder
    private var patient_info: PatientInfo?
    
    init(
        navigation_path: Binding<NavigationPath>,
        storage_manager: Binding<StorageManager>,
        patient_info: PatientInfo?
    ) {
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager
        self.patient_info = patient_info
        let face_detector = FaceDetector(spatial_publisher: self.spatial_emitter.subject.eraseToAnyPublisher())
        self.face_detector = face_detector
        self.dot_speed_subject = CurrentValueSubject<TimestampedValue<CGFloat>, Never>(
            TimestampedValue.from(0.0)
        )
        self.dot_position_subject = CurrentValueSubject<TimestampedValue<CGPoint>, Never>(
            TimestampedValue.from(CGPoint(x: 0, y: 0))
        )
        self.recorder = TestRecorder(
            patient_info: patient_info,
            dot_position_publisher: self.dot_position_subject.eraseToAnyPublisher(),
            dot_speed_publisher: self.dot_speed_subject.eraseToAnyPublisher(),
            spatial_face_publisher: face_detector.face_detected_frame_subject.eraseToAnyPublisher(),
            storage_manager: storage_manager.wrappedValue
        )
    }
    
    var body: some View {
        VStack{
            switch orientation {
            case .portrait:
                if !self.face_detector.face_detected{
                    Text("No face detected yet")
                } else {
                    switch self.recorder.status {
                    case .Ready, .Recording:
                        StationaryStimulus()
                            .onAppear {
                                self.recorder.record()
                            }
                            .overlay {
                                SpatialDataOverlay(spatial_frame_publisher: spatial_emitter.subject.eraseToAnyPublisher())
                            }
                        Button {
                            self.dot_speed_subject.send(completion: .finished)
                        } label: {
                            Text("End Test")
                                .padding()
                                .background(.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    case .Saving:
                        VStack {
                            ProgressView()
                            Text("Saving...")
                        }
                    case .Finished(_):
                        Text("Done").task {
                            try! await Task.sleep(for: .seconds(1))
                            navigation_path.removeLast(navigation_path.count)
                        }
                    }
                }
            case .portraitUpsideDown:
                Text("Your phone is upside down.")
            case _:
                Text("Please hold your phone at eye level in portrait mode.")
            }
        }.onRotate { new_orientation in
            orientation = new_orientation
        }
    }
}

/**
 Has two jobs:
 1. Help gate access to the exam until after a face is first detected.
 2. Convert a stream of SpatialFrameData into FrameFaceData, i.e. only emit face-tracking frame
   data, which will only happen once a face has been detected.
 */
@Observable
class FaceDetector {
    var face_detected: Bool = false
    @ObservationIgnored
    var face_detected_frame_subject = PassthroughSubject<FrameFaceData, Never>()
    private var cancellables: Set<AnyCancellable> = Set()
    
    init(spatial_publisher: AnyPublisher<SpatialFrameData, Never>) {
        spatial_publisher.sink { frame in
            switch frame {
            case .NoFaceDetected:
                ()
            case .FaceDetected(let frameFaceData):
                if !self.face_detected {
                    self.face_detected = true
                }
                self.face_detected_frame_subject.send(frameFaceData)
            }
        }.store(in: &cancellables)
    }
}

// DeviceRotationViewModifier and onRotate are defined in UIHelpers.swift

//#Preview {
//    Test(
//        navigation_path: .constant(NavigationPath()),
//        patient_info: nil,
//        storage_manager: .constant(StorageManager())
//    )
//}
