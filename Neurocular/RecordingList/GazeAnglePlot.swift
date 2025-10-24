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
    let plot_data_horizontal: [PlotValueByEye]
    let head_angle_horizontal: [PlotValue]
    let head_eye_angle_diff: [PlotValueByEye]
    let distance_data: [PlotValue]
    let velocity_data: [PlotValueByEye]
    let absolute_velocity_data: [PlotValueByEye]
    
    init(interpolated_frames: [InterpolatedFrame]) {
        self.transforms = interpolated_frames.map {$0.transforms.transforms}
        // Calculate the calibrated and biased gaze angles
        let calibrated_gaze_angles = calculate_horizontal_gaze_angle(transforms).map_by_eye(apply_angle_calibration)
        let calibrated_and_biased_gaze_angles = bias_right_eye(calibrated_gaze_angles)
        
        self.plot_data_horizontal = calibrated_and_biased_gaze_angles.consume_with(tidy_gaze_angles)
        
        self.head_angle_horizontal = transforms
            .enumerated()
            .map { (index, transform) in
                PlotValue(
                    frame_index: index,
                    elapsed: Double(index) / 60.0,
                    value: transform.head.horizontal_angle
                )
            }
        
        /**
            Calculate the difference between the head angle and the negative eye angle. This
         should be zero, or close to zero, since gaze should remain fixed on the stationary
         target diplayed on the screen. Large deviations from zero either mean that the user
         looked away from the target, or more likely, that there is a significant error in ARKit's
         head and/or eye-angle estimate.
         */
        self.head_eye_angle_diff = calibrated_and_biased_gaze_angles.map_zipped(
            other: transforms.map{t in t.head.horizontal_angle}
        ) { (eye_angle, head_angle) in
            eye_angle + head_angle
        }.consume_with(tidy_gaze_angles)
        
        self.distance_data = distances_to_frames(
            calculate_distance_from_screen_vectorized(transforms)
        )
        
        // Calculate the velocities for each eye
        let velocities = calibrated_and_biased_gaze_angles.map_array_by_eye { angles in
            derivative(of: angles, inter_sample_distance: 1.0 / 60.0)
        }
        self.velocity_data = velocities.consume_with(tidy_gaze_angles)
        self.absolute_velocity_data = velocity_data.map {datum in
            PlotValueByEye(
                frame_index: datum.frame_index,
                elapsed: datum.elapsed,
                eye: datum.eye,
                value: abs(datum.value))
        }
        
//        /*
//         This is probably going to be really noisy, it looks like the eye speed slows down
//         at each end of the excursion, understandably. So we may be better off sampling the
//         eye speed in the middle of the excursion since at this point it should match the
//         stimulus' speed if the subject is able to maintain smooth pursuit. Otherwise it
//         should be much higher than the stimulus speed. The issue with this approach is that
//         even when the subject is able to maintain smooth pursuit they may occasionally
//         perform "catch up" eye movements if they lose concentration, and those movements
//         are going to be much faster than the stimulus.
//         
//         It may also be the case that subjects spend a higher proportion of the excursion
//         time with their eyes stationary when they have lost smooth pursuit. It would not
//         be a larger absolute amount of time, since the duration of each excursion becomes
//         shorter the faster the stimulus is moving.
//         
//         We can also filter out movement that is faster than known physiological limits for
//         eye movement (150 deg/s?) since this is pretty much guaranteed to be noise.
//         
//         Also, from the Google paper it looked like subjects tend to "cut corners" or anticipate
//         where the stimulus is going. So during smooth pursuit it may be that subjects start to
//         lag behind the stimulus as it nears the end of an excursion waiting for the stimulus to
//         return to their point of gaze.
//         */
//        self.velocity_difference_data = right_velocity_difference + left_velocity_difference
    }
    
    var body: some View {
//        if app_config.print_changes {let _ = Self._printChanges()}
        let frame_height: CGFloat = 300;
        
        PlotByEye(
            title: "Horizontal Gaze Angle",
            y_axis_label: "Gaze Angle",
            data: plot_data_horizontal,
            n_frames: transforms.count,
            default_ticks: [-60, -45, -30, -15, 0, 15, 30, 45, 60]
        )
        .frame(height: frame_height)
        
        SinglePlot(
            title: "Horizontal Head Angle",
            y_axis_label: "Head Angle",
            data: head_angle_horizontal,
            n_frames: transforms.count,
            default_ticks: [-60, -45, -30, -15, 0, 15, 30, 45, 60]
        )
        .frame(height: frame_height)
        
        PlotByEye(
            title: "Difference Between Eye and Head Angle",
            y_axis_label: "Absolute Degrees",
            data: head_eye_angle_diff,
            n_frames: transforms.count,
            default_ticks: [-60, -45, -30, -15, 0, 15, 30, 45, 60]
        )
        .frame(height: frame_height)
        
        PlotByEye(
            title: "Eye Velocity",
            y_axis_label: "Speed",
            data: velocity_data,
            n_frames: transforms.count,
            default_ticks: [-200, -150, -100, -50, 0, 50, 100, 150, 200]
        )
        .frame(height: frame_height)
        
        PlotByEye(
            title: "Absolute Velocity",
            y_axis_label: "Speed",
            data: absolute_velocity_data,
            n_frames: transforms.count,
            default_ticks: [0, 50, 100, 150, 200]
        )
        .frame(height: frame_height)
        
        SinglePlot(
            title: "Eye Distance from Screen",
            y_axis_label: "Distance",
            data: distance_data,
            n_frames: transforms.count,
            default_ticks: [0, 5, 10, 15, 20, 25, 30]
        )
        .frame(height: frame_height)
    }
        
}


struct SinglePlot: View {
    let title: String
    let y_axis_label: String
    let data: [PlotValue]
    let n_frames: Int
    let default_ticks: [Int]
    @State private var scale_to_fit = false
    
    private var axis_marks: [Int] {
        if !scale_to_fit {
            return default_ticks
        }
        let min_value = data.min {(datum1, datum2) in
            datum1.value < datum2.value
        }!.value
        let max_value = data.max {(datum1, datum2) in
            datum1.value < datum2.value
        }!.value
        return [min_value * 1.1, 0, max_value * 1.1].map({Int($0)})
    }
    
    var body: some View {
        VStack{
            Text(title)
            HStack {
                Spacer()
                Image(systemName: "square.resize")
                    .padding(.top, -20)
                    .padding(.trailing, 20)
                    .foregroundStyle(.gray)
                    .onTapGesture {
                        scale_to_fit = !scale_to_fit
                    }
            }
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Angle", $0.value)
                )
                .mask { RectangleMark() }
            }
            .chartYAxis {
                AxisMarks(
                    values: axis_marks
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel(y_axis_label)
            .chartLegend(position: .top)
            .chartYScale(domain: [axis_marks[0], axis_marks[axis_marks.count - 1]])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}


struct PlotByEye: View {
    let title: String
    let y_axis_label: String
    let data: [PlotValueByEye]
    let n_frames: Int
    let default_ticks: [Int]
    @State private var scale_to_fit = false
    
    private var axis_marks: [Int] {
        if !scale_to_fit {
            return default_ticks
        }
        let min_value = data.min {(datum1, datum2) in
            datum1.value < datum2.value
        }!.value
        let max_value = data.max {(datum1, datum2) in
            datum1.value < datum2.value
        }!.value
        return [min_value * 1.1, 0, max_value * 1.1].map({Int($0)})
    }
    
    var body: some View {
        VStack{
            Text(title)
            HStack {
                Spacer()
                Image(systemName: "square.resize")
                    .padding(.top, -20)
                    .padding(.trailing, 20)
                    .foregroundStyle(.gray)
                    .onTapGesture {
                        scale_to_fit = !scale_to_fit
                    }
            }
            Chart(data) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Angle", $0.value)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
                .mask { RectangleMark() }
            }
            .chartYAxis {
                AxisMarks(
                    values: axis_marks
                )
                { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self)!)°")
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel(y_axis_label)
            .chartLegend(position: .top)
            .chartYScale(domain: [axis_marks[0], axis_marks[axis_marks.count - 1]])
            .chartXScale(domain: [0, Float(n_frames) / 60.0])
            .padding()
        }
    }
}


struct PlotValue {
    let frame_index: Int
    let elapsed: TimeInterval
    let value: Float
}

extension PlotValue: Identifiable {
    var id: String {
        "\(frame_index)"
    }
}

struct PlotValueByEye {
    let frame_index: Int
    let elapsed: TimeInterval
    let eye: String
    let value: Float
}

extension PlotValueByEye: Identifiable {
    var id: String {
        "\(eye)_\(frame_index)"
    }
}


/**
 Transforms a list of GazeAngle objects into a list of EyeAngleForFrame objects, which are more easily plotted.
 */
func tidy_gaze_angles(left_angles: [Float], right_angles: [Float]) -> [PlotValueByEye] {
    Swift.zip(left_angles, right_angles).enumerated().flatMap { (frame_index, angles) in
        let (left_angle, right_angle) = angles
        return [
            PlotValueByEye(
                frame_index: frame_index,
                elapsed: Double(frame_index) / 60.0,
                eye: "Left",
                value: left_angle),
            PlotValueByEye(
                frame_index: frame_index,
                elapsed: Double(frame_index) / 60.0,
                eye: "Right",
                value: right_angle)
        ]
    }
}

/**
 Much of the data that get plotted and processed in this file are really just arrays of numbers organized by
 eye. This struct reflects that fact and provides helper functions for doing rust-style function chaining that
 manipulates those values.
 */
struct ArrayByEye<T> {
    let left: [T]
    let right: [T]
    
    /**
     Applies the mapping function to each eye separately, returning a new instance of ArrayByEye.
     */
    func map_by_eye<P>(_ closure: (T) -> P) -> ArrayByEye<P> {
        ArrayByEye<P>(left: left.map(closure), right: right.map(closure))
    }
    
    /**
        Passes the left and right-eye arrays to the closure in their entirety.
     */
    func map_array_by_eye<P>(_ closure: ([T]) -> [P]) -> ArrayByEye<P> {
        ArrayByEye<P>(left: closure(left), right: closure(right))
    }
    
    /**
        Passes the left and right-eye data into the closure.
     */
    func consume_with<P>(_ closure: ([T], [T]) -> P) -> P {
        closure(left, right)
    }
    
    /**
     Applies the closure to the left-eye data and leaves the right-eye data unchanged. Returns
     a new copy of the data.
     */
    func map_left(_ closure: (T) -> T) -> ArrayByEye<T> {
        ArrayByEye(left: left.map(closure), right: right)
    }
    
    /**
     Applies the closure to the right-eye data and leaves the left-eye data unchanged. Returns
     a new copy of the data.
     */
    func map_right(_ closure: (T) -> T) -> ArrayByEye<T> {
        ArrayByEye(left: left, right: right.map(closure))
    }
    
    func map_zipped<P, Q>(other: [P], closure: (T, P) -> Q) -> ArrayByEye<Q> {
        ArrayByEye<Q>(
            left: Swift.zip(left, other).map(closure),
            right: Swift.zip(right, other).map(closure)
        )
    }
    
    /**
     Combines the left and right-eye data to produce a single array. Left and right eye data are
     zipped together before being passed into the closure.
     */
    func zip() -> Zip2Sequence<[T], [T]> {
        Swift.zip(left, right)
    }
}



/**
 Applies the calibration  model obtained through our gaze-angle calibration data collection.
 */
func apply_angle_calibration(angle: Float) -> Float {
    let coefficients: [Float] = [
        -3.82185321,
        1.54036450,
        0.0196023800,
        0.00118953528,
    ]
    return coefficients[0] + coefficients[1] * angle + coefficients[2] * pow(angle, 2) + coefficients[3] * pow(angle, 3)
}

/*
 Adds whatever constant is needed to the right eye angles to make them equal
 to the left eye angles in the first frame.
 */
func bias_right_eye(_ angles: ArrayByEye<Float>) -> ArrayByEye<Float> {
    let initial_difference = angles.left[0] - angles.right[0];
    return angles.map_right {angle in
        angle + initial_difference
    }
    
}

func distances_to_frames(_ distances: [Float]) -> [PlotValue] {
    return distances.enumerated().map{ (frame_index, distance) in
        PlotValue (
            frame_index: frame_index,
            elapsed: Double(frame_index) / 60.0,
            value: distance
        )
    }
}

#Preview {
    let test_data_dir = URL(fileURLWithPath: "/Users/max.taggart/Developer/Ehrenkranz/Neurocular/test_data/exams")
    let storage_manager = StorageManager(with_base_dir: test_data_dir);
    let exam_metadata = storage_manager.get_exam_metadata_by_id("c4bee50c-ff9f-4c4e-8034-15bdcd3253dc")!
    let frames = storage_manager.get_exam_frames_by_id(exam_metadata.id)!
    ScrollView {
        GazeAnglePlot(interpolated_frames: interpolate_frames(frames))
    }
}
