//
//  GazeAnglePlot.swift
//  emphairmint
//
//  Created by Max Taggart on 3/4/25.
//

import SwiftUI
import Charts

struct GazeAnglePlot: View {
    let transforms: [Transforms]
    let plot_data_horizontal: [EyeAngleForFrame]
    let distance_data: [EyeDistanceForFrame]
    
    init(transforms: [Transforms]) {
        self.transforms = transforms
        self.plot_data_horizontal = tidy_gaze_angles(
            bias_right_eye(
                apply_angle_calibration(
                    calculate_horizontal_gaze_angle_vectorized(transforms))))
        self.distance_data = distances_to_frames(
            calculate_distance_from_screen_vectorized(transforms)
        )
    }
    
    var body: some View {
//        if app_config.print_changes {let _ = Self._printChanges()}
        AnglePlot(
            title: "Horizontal Gaze Angle",
            data: plot_data_horizontal,
            n_frames: transforms.count
        )
//        AnglePlot(
//            title: "Vertical Gaze Angle",
//            data: plot_data_vertical,
//            n_frames: transforms.left_eye.count
//        )
        DistancePlot(
            title: "Eye Distance from Screen",
            data: distance_data,
            n_frames: transforms.count
        )
    }
        
}

struct AnglePlot: View {
    let title: String
    let data: [EyeAngleForFrame]
    let n_frames: Int
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Angle", $0.angle)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
            }
            .chartYAxis {
                AxisMarks(
                    values: [-10, -5, 0, 5, 10]
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Gaze Angle")
            .chartLegend(position: .top)
            .chartYScale(domain: [-10, 10])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}

struct DistancePlot: View {
    let title: String
    let data: [EyeDistanceForFrame]
    let n_frames: Int
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Inches", $0.distance)
                )
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Inches")
            .chartLegend(position: .top)
            .chartYScale(domain: [0, 20])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}



struct EyeAngleForFrame {
    let frame_index: Int
    let elapsed: TimeInterval
    let eye: String
    let angle: Float
}

extension EyeAngleForFrame: Identifiable {
    var id: String {
        "\(eye)_\(frame_index)"
    }
}

/**
 Transforms a list of GazeAngle objects into a list of EyeAngleForFrame objects, which are more easily plotted.
 */
func tidy_gaze_angles(_ angles: [GazeAngles]) -> [EyeAngleForFrame] {
    angles.enumerated().flatMap { (frame_index, angle) in
        [
            EyeAngleForFrame(
                frame_index: frame_index,
                elapsed: Double(frame_index) / 60.0,
                eye: "Left",
                angle: angle.left),
            EyeAngleForFrame(
                frame_index: frame_index,
                elapsed: Double(frame_index) / 60.0,
                eye: "Right",
                angle: angle.right)
        ]
    }
}

/**
 Applies the calibration  model obtained through our gaze-angle calibration data collection.
 */
func apply_angle_calibration(_ uncalibrated_angles: [GazeAngles]) -> [GazeAngles] {
    let coefficients: [Float] = [
        -3.82185321,
        1.54036450,
        0.0196023800,
        0.00118953528,
    ]
    func calibrate(angle: Float) -> Float {
        return coefficients[0] + coefficients[1] * angle + coefficients[2] * pow(angle, 2) + coefficients[3] * pow(angle, 3)
    }
    return uncalibrated_angles.map {angle in
        GazeAngles(
            left: calibrate(angle: angle.left),
            right: calibrate(angle: angle.right)
        )
    }
}

/*
 Adds whatever constant is needed to the right eye angles to make them equal
 to the left eye angles in the first frame.
 */
func bias_right_eye(_ angles: [GazeAngles]) -> [GazeAngles] {
    let initial_difference = angles[0].left - angles[0].right;
    return angles.map {angle in
        return GazeAngles (
            left: angle.left,
            right: angle.right + initial_difference
        )
    }
    
}

struct EyeDistanceForFrame {
    let frame_index: Int
    let elapsed: TimeInterval
    let distance: Float
}

extension EyeDistanceForFrame: Identifiable {
    var id: String {
        "\(frame_index)"
    }
}

func distances_to_frames(_ distances: [Float]) -> [EyeDistanceForFrame] {
    return distances.enumerated().map{ (frame_index, distance) in
        EyeDistanceForFrame (
            frame_index: frame_index,
            elapsed: Double(frame_index) / 60.0,
            distance: distance
        )
    }
}

//#Preview {
//    let storage_manager = StorageManager.for_preview()
//    let transforms = storage_manager.read_transforms_for_test(id: "3ba72673-499e-4c31-ba51-e74ba9dbf4a5")
//    GazeAnglePlot(transforms: transforms)
//}
