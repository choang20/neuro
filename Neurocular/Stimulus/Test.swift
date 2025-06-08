//
//  Exam.swift
//  Neurocular
//
//  Created by Max Taggart on 5/6/25.
//

import SwiftUI


struct Test: View {
    @State private var rotate_screen: Bool = true
    private var current_cycle_index: Int = 0
    @State private var test_finished: Bool = false
    
    
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
        if rotate_screen {
            Text(
                "Please rotate your screen counterclockwise into landscape mode."
            ).task {
                try! await Task.sleep(for: .seconds(2))
                rotate_screen = false
            }
        } else if test_finished {
            Text("Done")
        } else {
            Stimulus(on_completed_test: {test_finished = true})
        }
        
    }
}


#Preview {
    Test()
}
