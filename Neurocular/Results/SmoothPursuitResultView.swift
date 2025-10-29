//
//  SmoothPursuitResultView.swift
//  Neurocular
//

import SwiftUI
import Charts

struct SmoothPursuitResultView: View {
    let examId: ExamId
    @Binding var navigation_path: NavigationPath
    @Binding var storage_manager: StorageManager

    private let plotData: [PlotValueByEye]
    private let nFrames: Int

    init(examId: ExamId, navigation_path: Binding<NavigationPath>, storage_manager: Binding<StorageManager>) {
        self.examId = examId
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager
        let frames = storage_manager.wrappedValue.get_exam_frames_by_id(examId)!
        let interpolated = interpolate_frames(frames)
        let transforms = interpolated.map { $0.transforms.transforms }
        let calibrated = calculate_horizontal_gaze_angle(transforms).map_by_eye(apply_angle_calibration)
        let biased = bias_right_eye(calibrated)
        self.plotData = biased.consume_with(tidy_gaze_angles)
        self.nFrames = transforms.count
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Smooth Pursuit Result")
                    .font(.title3)
                Spacer()
                Button("Next") {
                    navigation_path.append(ResultRoute(examId: examId, kind: "saccades"))
                }
            }
            .padding(.horizontal)

            Chart(plotData) {
                LineMark(
                    x: .value("Time", $0.elapsed),
                    y: .value("Gaze Angle", $0.value)
                )
                .foregroundStyle(by: .value("Eye", $0.eye))
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Horizontal Gaze Angle (°)")
            .chartXScale(domain: [0, Float(nFrames) / 60.0])
            .padding()
        }
    }
}


