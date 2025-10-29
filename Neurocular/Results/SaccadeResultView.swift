//
//  SaccadeResultView.swift
//  Neurocular
//

import SwiftUI
import Charts

struct SaccadeResultView: View {
    let examId: ExamId
    @Binding var navigation_path: NavigationPath
    @Binding var storage_manager: StorageManager

    struct Sample: Identifiable {
        let id = UUID()
        let t: Double        // seconds
        let targetDeg: Double
        let eyeDeg: Double
        let eyeVel: Double
    }

    private let samples: [Sample]

    init(examId: ExamId, navigation_path: Binding<NavigationPath>, storage_manager: Binding<StorageManager>) {
        self.examId = examId
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager
        let frames = storage_manager.wrappedValue.get_exam_frames_by_id(examId)!

        // Build per-spatial-frame aligned arrays
        let spatial = frames.spatial_transforms
        let n = spatial.count
        let dt: Double = 1.0 / 60.0

        // Precompute eye horizontal angles (average of eyes, calibrated and biased)
        let transforms = spatial.map { $0.transforms }
        let byEye = calculate_horizontal_gaze_angle(transforms).map_by_eye(apply_angle_calibration)
        let biased = bias_right_eye(byEye)
        let left = biased.left.map { Double($0) }
        let right = biased.right.map { Double($0) }
        let eyeDeg = zip(left, right).map { ($0 + $1) / 2.0 }

        // Velocity (deg/s)
        var eyeVel: [Double] = []
        eyeVel.reserveCapacity(n)
        for i in 0..<n {
            if i == 0 { eyeVel.append(0); continue }
            let v = (eyeDeg[i] - eyeDeg[i-1]) / dt
            eyeVel.append(v)
        }

        // Target angle derived from stimulus positions and distance
        // Map each spatial timestamp to the latest known stimulus position
        let positions = frames.stimulus_positions.sorted { $0.timestamp < $1.timestamp }
        var posIndex = 0
        let ppi: Double = 460.0
        let screenMidX = Double(UIScreen.main.bounds.midX)
        var targetDeg: [Double] = []
        targetDeg.reserveCapacity(n)
        for s in spatial {
            // advance pointer to most recent position at or before this timestamp
            while posIndex + 1 < positions.count && positions[posIndex + 1].timestamp <= s.timestamp {
                posIndex += 1
            }
            let pxX = positions.isEmpty ? screenMidX : Double(positions[posIndex].value.x)
            let deltaPx = pxX - screenMidX
            let inchesX = deltaPx / ppi
            let dist = Double(calculate_distance_from_screen(from_transforms: s.transforms))
            let ang = atan2(inchesX, max(dist, 1e-3)) * 180.0 / .pi
            targetDeg.append(ang)
        }

        // Build unified samples
        var tmp: [Sample] = []
        tmp.reserveCapacity(n)
        for i in 0..<n {
            tmp.append(Sample(t: Double(i) * dt, targetDeg: targetDeg[i], eyeDeg: eyeDeg[i], eyeVel: eyeVel[i]))
        }
        self.samples = tmp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saccades Result")
                .font(.title3)
                .padding(.horizontal)

            // Split into 3 equal time windows and render 3 plots labeled with target speeds
            ForEach(0..<3) { idx in
                SaccadePanel(title: ["5°/s", "15°/s", "30°/s"][idx],
                             slice: slice(samples, segment: idx))
            }
        }
        .padding(.bottom)
    }

    private func slice(_ arr: [Sample], segment: Int) -> [Sample] {
        let third = max(arr.count / 3, 1)
        let start = segment * third
        let end = segment == 2 ? arr.count : min(start + third, arr.count)
        return Array(arr[start..<end])
    }
}

private struct SaccadePanel: View {
    let title: String
    let slice: [SaccadeResultView.Sample]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.leading)

            Chart {
                // Target position (deg)
                ForEach(slice) { s in
                    LineMark(x: .value("t", s.t), y: .value("deg", s.targetDeg))
                        .foregroundStyle(Color.red)
                }
                // Eye position (deg)
                ForEach(slice) { s in
                    LineMark(x: .value("t", s.t), y: .value("deg", s.eyeDeg))
                        .foregroundStyle(Color.blue)
                }
                // Eye velocity (deg/s) on trailing axis
                ForEach(slice) { s in
                    LineMark(x: .value("t", s.t), y: .value("vel", s.eyeVel))
                        .foregroundStyle(Color.green)
                        .symbol(Circle())
                        .interpolationMethod(.linear)
                        .yAxis(.trailing)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [-45, -30, -15, 0, 15, 30, 45]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self)!)°") }
                }
            }
            .chartYAxis(.trailing) {
                AxisMarks(position: .trailing)
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel(position: .leading, alignment: .center) { Text("Degrees") }
            .chartYAxisLabel(position: .trailing, alignment: .center) { Text("Velocity") }
            .frame(height: 220)
            .padding(.horizontal)
        }
    }
}


