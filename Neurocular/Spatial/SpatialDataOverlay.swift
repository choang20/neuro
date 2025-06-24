//
//  SpatialDataOverlay.swift
//  Neurocular
//
//  Created by Max Taggart on 6/1/25.
//

import SwiftUI

struct SpatialDataOverlay: View {
    @Binding var frame_data: SpatialFrameData?
    
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
                let gaze_angles = calculate_horizontal_gaze_angle(
                    from_transforms: face_data.transforms
                )
                let head_angle = calculate_head_angle(from_transforms: face_data.transforms)
                measurements = Measurements(
                    head_distance: pad(text: String(format: "%.1f\"", distance), length: 6),
                    head_angle: pad(text: String(format: "%.0f°", round(head_angle)), length: 6),
                    left_eye_angle: pad(text: String(format: "%.0f°", round(gaze_angles.left)), length: 6),
                    right_eye_angle: pad(text: String(format: "%.0f°", round(gaze_angles.right)), length: 6)
                )
            }
            return measurements
        }
    }
    
    let measurement_font = Font
            .system(size: 14)
            .monospaced()
    
    var body: some View {
        if let frame_data = frame_data {
            VStack {
                HStack{
                    let measurements = Measurements.from(frame_data: frame_data)
                    HStack{
                        Text("Distance:")
                            .foregroundStyle(.gray)
                        Text(measurements.head_distance)
                            .foregroundStyle(.foreground)
                            .font(measurement_font)
                    }
                    
                    Spacer()
                    
                    HStack{
                        Text("Head:")
                            .foregroundStyle(.gray)
                        Text(measurements.head_angle)
                            .foregroundStyle(.foreground)
                            .font(measurement_font)
                    }
                    
                    Spacer()
                    
                    HStack{
                        Text("Left Eye:")
                            .foregroundStyle(.gray)
                        Text(measurements.left_eye_angle)
                            .foregroundStyle(.foreground)
                            .font(measurement_font)
                    }
                    
                    Spacer()
                    
                    HStack{
                        Text("Right Eye:")
                            .foregroundStyle(.gray)
                        Text(measurements.right_eye_angle)
                            .foregroundStyle(.foreground)
                            .font(measurement_font)
                    }
                    
                    Spacer()
                    
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
                    
                }.padding()
                Spacer()
            }
        } else {
            ProgressView()
        }
    }
}

/*
 Ensures that the text is at least length characters long by adding spaces to the end
 */
func pad(text: String, length: Int) -> String {
    let actual_length = text.count
    let diff = max(length - actual_length, 0)
    let padding = String(repeating: " ", count: diff)
    return text + padding
}

#Preview {
    let data: SpatialFrameData = .NoFaceDetected
    SpatialDataOverlay(frame_data: .constant(data))
}
