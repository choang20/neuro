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
    let velocity_data: [SpeedForFrame]
    let absolute_velocity_data: [SpeedForFrame]
    let stimulus_absolute_velocity_data: [StimulusSpeedForFrame]
    let velocity_difference_data: [VelocityDifferenceForFrame]
    
    init(transforms: [Transforms], degrees_per_second: [Int]) {
        self.transforms = transforms
        self.plot_data_horizontal = tidy_gaze_angles(
            bias_right_eye(
                apply_angle_calibration(
                    calculate_horizontal_gaze_angle_vectorized(transforms))))
        self.distance_data = distances_to_frames(
            calculate_distance_from_screen_vectorized(transforms)
        )
        let left_angles = self.plot_data_horizontal.filter{ datum in
            datum.eye == "Left"
        }.map { datum in
            datum.angle
        }
        let left_speeds = derivative(of: left_angles, inter_sample_distance: 1.0 / 60.0)
        let left_frames = self.plot_data_horizontal.filter{ datum in
            datum.eye == "Left"
        }.enumerated(
        ).map { (index, datum) in
            SpeedForFrame(
                frame_index: datum.frame_index,
                elapsed: datum.elapsed,
                eye: datum.eye,
                speed: left_speeds[index]
            )
        }
        let right_angles = self.plot_data_horizontal.filter{ datum in
            datum.eye == "Right"
        }.map { datum in
            datum.angle
        }
        let right_speeds = derivative(of: right_angles, inter_sample_distance: 1.0 / 60.0)
        let right_frames = self.plot_data_horizontal.filter{ datum in
            datum.eye == "Right"
        }.enumerated(
        ).map { (index, datum) in
            SpeedForFrame(
                frame_index: datum.frame_index,
                elapsed: datum.elapsed,
                eye: datum.eye,
                speed: right_speeds[index]
            )
        }
        self.velocity_data = left_frames + right_frames
        self.absolute_velocity_data = velocity_data.map {datum in
            SpeedForFrame(
                frame_index: datum.frame_index,
                elapsed: datum.elapsed,
                eye: datum.eye,
                speed: abs(datum.speed))
        }
        self.stimulus_absolute_velocity_data = right_frames.enumerated(
        ).map { (index, datum) in
            StimulusSpeedForFrame(
                frame_index: datum.frame_index,
                elapsed: datum.elapsed,
                speed: degrees_per_second[index]
            )
        }
        let right_velocity_difference = right_frames.enumerated().map { (index, frame) in
            let stimulus_speed = degrees_per_second[index]
            return VelocityDifferenceForFrame(
                frame_index: frame.frame_index,
                elapsed: frame.elapsed,
                eye: frame.eye,
                difference: frame.speed - Float(stimulus_speed))
        }
        let left_velocity_difference = left_frames.enumerated().map { (index, frame) in
            let stimulus_speed = degrees_per_second[index]
            return VelocityDifferenceForFrame(
                frame_index: frame.frame_index,
                elapsed: frame.elapsed,
                eye: frame.eye,
                difference: frame.speed - Float(stimulus_speed))
        }
        /*
         This is probably going to be really noisy, it looks like the eye speed slows down
         at each end of the excursion, understandably. So we may be better off sampling the
         eye speed in the middle of the excursion since at this point it should match the
         stimulus' speed if the subject is able to maintain smooth pursuit. Otherwise it
         should be much higher than the stimulus speed. The issue with this approach is that
         even when the subject is able to maintain smooth pursuit they may occasionally
         perform "catch up" eye movements if they lose concentration, and those movements
         are going to be much faster than the stimulus.
         
         It may also be the case that subjects spend a higher proportion of the excursion
         time with their eyes stationary when they have lost smooth pursuit. It would not
         be a larger absolute amount of time, since the duration of each excursion becomes
         shorter the faster the stimulus is moving.
         
         We can also filter out movement that is faster than known physiological limits for
         eye movement (150 deg/s?) since this is pretty much guaranteed to be noise.
         
         Also, from the Google paper it looked like subjects tend to "cut corners" or anticipate
         where the stimulus is going. So during smooth pursuit it may be that subjects start to
         lag behind the stimulus as it nears the end of an excursion waiting for the stimulus to
         return to their point of gaze.
         */
        self.velocity_difference_data = right_velocity_difference + left_velocity_difference
    }
    
    var body: some View {
//        if app_config.print_changes {let _ = Self._printChanges()}
        AnglePlot(
            title: "Horizontal Gaze Angle",
            data: plot_data_horizontal,
            n_frames: transforms.count
        )
        SpeedPlot(
            title: "Eye Velocity",
            data: velocity_data,
            n_frames: transforms.count
        )
        AbsoluteSpeedPlot(
            title: "Absolute Velocity",
            data: absolute_velocity_data,
            n_frames: transforms.count
        )
        StimuluSpeedPlot(
            title: "Stimulus Absolute Velocity",
            data: stimulus_absolute_velocity_data
        )
        VelocityDifferencePlot(
            title: "Eye Speed Error",
            data: self.velocity_difference_data,
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

struct SpeedPlot: View {
    let title: String
    let data: [SpeedForFrame]
    let n_frames: Int
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Speed", $0.speed)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
            }
            .chartYAxis {
                AxisMarks(
                    values: [-200, -150, -100, -50, 0, 50, 100, 150, 200]
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Deg/s")
            .chartLegend(position: .top)
            .chartYScale(domain: [-200, 200])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}

struct AbsoluteSpeedPlot: View {
    let title: String
    let data: [SpeedForFrame]
    let n_frames: Int
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Speed", $0.speed)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
            }
            .chartYAxis {
                AxisMarks(
                    values: [0, 50, 100, 150, 200]
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Deg/s")
            .chartLegend(position: .top)
            .chartYScale(domain: [0, 200])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}

struct StimuluSpeedPlot: View {
    let title: String
    let data: [StimulusSpeedForFrame]
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Speed", $0.speed)
                )
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Deg/s")
            .chartLegend(position: .top)
            .chartYScale(domain: [0, 35])
            .chartXScale(domain: [0, Float(data.count) / 60.0])
            .padding()
        }
    }
}

struct VelocityDifferencePlot: View {
    let title: String
    let data: [VelocityDifferenceForFrame]
    let n_frames: Int
    
    var body: some View {
        VStack{
            Text(title)
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("∆V", $0.difference)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
            }
            .chartYAxis {
                AxisMarks(
                    values: [-200, -150, -100, -50, 0, 50, 100, 150, 200]
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Deg/s")
            .chartLegend(position: .top)
            .chartYScale(domain: [-200, 200])
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

struct SpeedForFrame {
    let frame_index: Int
    let elapsed: TimeInterval
    let eye: String
    let speed: Float
}

extension SpeedForFrame: Identifiable {
    var id: String {
        "\(eye)_\(frame_index)"
    }
}

struct VelocityDifferenceForFrame {
    let frame_index: Int
    let elapsed: TimeInterval
    let eye: String
    let difference: Float
}

extension VelocityDifferenceForFrame: Identifiable {
    var id: String {
        "\(eye)_\(frame_index)"
    }
}

struct StimulusSpeedForFrame {
    let frame_index: Int
    let elapsed: TimeInterval
    let speed: Int
}

extension StimulusSpeedForFrame: Identifiable {
    var id: String {
        "\(frame_index)"
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
