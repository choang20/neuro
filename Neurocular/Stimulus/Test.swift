//
//  Exam.swift
//  Neurocular
//
//  Created by Max Taggart on 5/6/25.
//

import SwiftUI


struct Test: View {
    @State private var orientation_is_correct: Bool = false
    @State private var test_finished: Bool = false
    @State private var rotation_instructions: String = "Please rotate your screen counterclockwise into landscape mode."
    @Binding var navigation_path: NavigationPath
    let patient_info: PatientInfo?
    let storage_manager: StorageManager
    
    
    var body: some View {
//        Text("")
//            .font(Font.system(size:1, design: .default))
//            .hidden()
//            .task {
//                for await frame_data in await spatial_emitter.stream {
//                    switch frame_data {
//                    case .NoFaceDetected:
//                        print("No Face Detected")
//                    case .FaceDetected(let data):
//                        let eye_distance_inches = calculate_distance_from_screen(
//                            from_transforms: data.transforms)
//                        let (degrees_per_second, _) = speed_cycles[current_cycle_index]
//                        // Calculate pixels per second given distance and width
//                        current_pixels_per_second = iPhone14_ppi * CGFloat(eye_distance_inches) * tan(CGFloat(Float.pi / 180.0) * CGFloat(degrees_per_second))
//                    }
//                }
//            }
        if !orientation_is_correct {
            Text(rotation_instructions).onRotate { new_orientation in
                print(new_orientation)
                switch new_orientation {
                case .unknown:
                    ()
                case .portrait:
                    orientation_is_correct = false
                    rotation_instructions = "Please rotate your screen counterclockwise into landscape mode."
                case .portraitUpsideDown:
                    orientation_is_correct = false
                    rotation_instructions = "Oops, too far."
                case .landscapeLeft:
                    orientation_is_correct = true
                case .landscapeRight:
                    orientation_is_correct = false
                    rotation_instructions = "Other way."
                case .faceUp:
                    ()
                case .faceDown:
                    ()
                case _:
                    ()
                }
            }
        } else if test_finished {
            Text("Done").task {
                try! await Task.sleep(for: .seconds(1))
                navigation_path.removeLast(navigation_path.count)
            }
        } else {
            Stimulus(
                patient_info: patient_info,
                storage_manager: storage_manager,
                on_completed_test: {test_finished = true}
            )
        }
        
    }
}

// Our custom view modifier to track rotation and
// call our action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

#Preview {
    Test(
        navigation_path: .constant(NavigationPath()),
        patient_info: nil,
        storage_manager: StorageManager()
    )
}
