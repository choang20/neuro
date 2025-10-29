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
    private let speedDeg: [Double]

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
        // Convert recorded speed (px/s) to deg/s at each frame using distance at that frame
        // Use interpolated frames to map speeds at spatial timestamps
        let interp = interpolate_frames(frames)
        let ppi: Double = 460.0
        var sdeg: [Double] = []
        sdeg.reserveCapacity(interp.count)
        for f in interp {
            let inches = Double(calculate_distance_from_screen(from_transforms: f.transforms.transforms))
            let k = max(ppi * inches * tan(.pi / 180.0), 1e-6)
            sdeg.append(f.speed / k)
        }
        self.speedDeg = sdeg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saccades Result")
                .font(.title3)
                .padding(.horizontal)
                .padding(.top, 8)

            SaccadePanel(title: "5°/s", slice: segmentSlice(target: 5))
            SaccadePanel(title: "15°/s", slice: segmentSlice(target: 15))
            SaccadePanel(title: "30°/s", slice: segmentSlice(target: 30))
        }
        .padding(.bottom)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func segmentSlice(target: Double) -> [Sample] {
        // Find the longest contiguous window where |speedDeg - target| <= tol for >= minDur seconds
        let tol = 2.0
        let minFrames = Int(1.5 * 60.0) // at least 1.5s
        var bestRange: Range<Int>? = nil
        var i = 0
        while i < speedDeg.count {
            if abs(speedDeg[i] - target) <= tol {
                let start = i
                while i < speedDeg.count && abs(speedDeg[i] - target) <= tol { i += 1 }
                let end = i
                if end - start >= minFrames {
                    if bestRange == nil || (end - start) > (bestRange!.count) {
                        bestRange = start..<end
                    }
                }
            } else {
                i += 1
            }
        }
        guard let r = bestRange else { return [] }
        // Normalize time to start at 0 for the slice
        let t0 = samples[r.lowerBound].t
        return samples[r].map { s in Sample(t: s.t - t0, targetDeg: s.targetDeg, eyeDeg: s.eyeDeg, eyeVel: s.eyeVel) }
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

            // Degrees chart (fixed domain)
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
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [-45, -30, -15, 0, 15, 30, 45]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self)!)°") }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Degrees")
            .chartYScale(domain: -45...45)
            .frame(height: 220)
            .padding(.horizontal)

            // Velocity chart (separate panel)
            Chart {
                ForEach(slice) { s in
                    LineMark(x: .value("t", s.t), y: .value("vel", s.eyeVel))
                        .foregroundStyle(Color.green)
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Velocity (deg/s)")
            .chartYScale(domain: -200...200)
            .frame(height: 120)
            .padding(.horizontal)
        }
    }
}


