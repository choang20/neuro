//
//  SpatialDataOverlay.swift
//  Neurocular
//
//  Created by Max Taggart on 6/1/25.
//

import SwiftUI
import Combine

/*
Displays head angle, head distance, eye angles, and an indicator of which of the
three face-detection states the current SpatialFrameData is.
*/
struct SpatialDataOverlay: View {
    let spatial_frame_publisher: AnyPublisher<SpatialFrameData, Never>
    @State private var frame_data: SpatialFrameData = .NoFaceDetected
    @State private var orientation = UIDevice.current.orientation
    
    var body: some View {
        
         VStack {
            switch orientation {
            case .landscapeLeft, .landscapeRight:
                HStack{
                    OverlayData(frame_data: frame_data, with_spacing: true)
                }.padding()
                Spacer()
            case _:
                HStack{
                    Spacer()
                    VStack (alignment: .trailing) {
                        OverlayData(frame_data: frame_data, with_spacing: false)
                        Spacer()
                    }.padding()
                }
            }
             
         }
         .onReceive(spatial_frame_publisher) {spatial_frame in
             frame_data = spatial_frame
         }
         .onRotate{ new_orientation in
             orientation = new_orientation
         }
    }
}

struct Measurements {
    let head_distance: String
    let head_angle: String
    let left_eye_angle: String
    let right_eye_angle: String
    
    static func from(frame_data: SpatialFrameData) -> Measurements {
        let measurements: Measurements
        switch frame_data {
        case .NoFaceDetected:
            measurements = Measurements(
                head_distance: "?",
                head_angle: "?",
                left_eye_angle: "?",
                right_eye_angle: "?"
            )
        case .FaceDetected(let face_data):
            let distance = calculate_distance_from_screen(
                from_transforms: face_data.transforms
            )
            measurements = Measurements(
                head_distance: pad(text: String(format: "%.1f\"", distance), length: 6),
                head_angle: pad(text: String(format: "%.0f°", round(face_data.transforms.head.horizontal_angle)), length: 6),
                left_eye_angle: pad(text: String(format: "%.0f°", round(face_data.transforms.left_eye.horizontal_angle)), length: 6),
                right_eye_angle: pad(text: String(format: "%.0f°", round(face_data.transforms.left_eye.horizontal_angle)), length: 6)
            )
        }
        return measurements
    }
}

struct OverlayData: View {
    let frame_data: SpatialFrameData
    let with_spacing: Bool
    
    let measurement_font = Font
            .system(size: 14)
            .monospaced()
    
    var body: some View {
        let measurements = Measurements.from(frame_data: frame_data)
        Group {
            
           
            let image_name = switch frame_data {
            case .NoFaceDetected:
                "FaceNotFound"
            case .FaceDetected(let frameFaceData):
                if frameFaceData.wild_guess {
                    "WildGuess"
                } else {
                    "TrackingActive"
                }
            }
           
            Image(image_name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
            
            if with_spacing {
                Spacer()
            }
            
            HStack{
                Text("Distance:")
                    .foregroundStyle(.gray)
                Text(measurements.head_distance)
                    .foregroundStyle(.foreground)
                    .font(measurement_font)
            }
            
            if with_spacing {
                Spacer()
            }
            
            HStack{
                Text("Head:")
                    .foregroundStyle(.gray)
                Text(measurements.head_angle)
                    .foregroundStyle(.foreground)
                    .font(measurement_font)
            }
           
            if with_spacing {
                Spacer()
            }
           
            HStack{
                Text("Left Eye:")
                    .foregroundStyle(.gray)
                Text(measurements.left_eye_angle)
                    .foregroundStyle(.foreground)
                    .font(measurement_font)
            }
           
            if with_spacing {
                Spacer()
            }
           
            HStack{
                Text("Right Eye:")
                    .foregroundStyle(.gray)
                Text(measurements.right_eye_angle)
                    .foregroundStyle(.foreground)
                    .font(measurement_font)
            }
        }
    }
}

/*
 Ensures that the text is at least `length` characters long by adding spaces to
 the end.
 */
fileprivate func pad(text: String, length: Int) -> String {
    let actual_length = text.count
    let diff = max(length - actual_length, 0)
    let padding = String(repeating: " ", count: diff)
    return text + padding
}

#Preview {
    let data: SpatialFrameData = .NoFaceDetected
    let subject  = CurrentValueSubject<SpatialFrameData, Never>(data)
    SpatialDataOverlay(spatial_frame_publisher: subject.eraseToAnyPublisher())
}
