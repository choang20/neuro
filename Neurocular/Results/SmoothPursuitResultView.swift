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
    private let targetData: [PlotValue]
    private let nFrames: Int
    @State private var scaleToFit: Bool = true

    init(examId: ExamId, navigation_path: Binding<NavigationPath>, storage_manager: Binding<StorageManager>) {
        self.examId = examId
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager
        let frames = storage_manager.wrappedValue.get_exam_frames_by_id(examId)!
        let interpolated = interpolate_frames(frames)
        let transforms = interpolated.map { $0.transforms.transforms }
        let calibrated = calculate_horizontal_gaze_angle(transforms).map_by_eye(apply_angle_calibration)
        let biased = bias_right_eye(calibrated)
        // Light smoothing (moving average window = 5 frames ~83ms at 60Hz)
        func smooth(_ xs: [Float], window: Int) -> [Float] {
            guard window > 1 else { return xs }
            var out: [Float] = []
            out.reserveCapacity(xs.count)
            var buf: [Float] = []
            for x in xs {
                buf.append(x)
                if buf.count > window { buf.removeFirst() }
                let avg = buf.reduce(0, +) / Float(buf.count)
                out.append(avg)
            }
            return out
        }
        let smoothed = biased.map_array_by_eye { smooth($0, window: 5) }
        self.plotData = smoothed.consume_with(tidy_gaze_angles)
        self.nFrames = transforms.count

        // Compute target angle (deg) from target pixel X and distance per frame
        let ppi: Double = 460.0
        let midX = Double(UIScreen.main.bounds.midX)
        var target: [PlotValue] = []
        target.reserveCapacity(interpolated.count)
        for (i, f) in interpolated.enumerated() {
            let pxX = Double(f.position.x)
            let inchesX = (pxX - midX) / ppi
            let distInches = Double(calculate_distance_from_screen(from_transforms: f.transforms.transforms))
            let deg = atan2(inchesX, max(distInches, 1e-3)) * 180.0 / .pi
            target.append(PlotValue(frame_index: i, elapsed: Double(i) / 60.0, value: Float(deg)))
        }
        self.targetData = target
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading) {
            HStack {
                Text("Smooth Pursuit Result")
                    .font(.title3)
                Spacer()
                Image(systemName: "square.resize")
                    .foregroundStyle(.gray)
                    .onTapGesture { scaleToFit.toggle() }
                Button("Next") {
                    navigation_path.append(ResultRoute(examId: examId, kind: "saccades"))
                }
            }
            .padding(.horizontal)

            Chart {
                // Eye traces (smoothed)
                ForEach(plotData) { p in
                    LineMark(x: .value("Time", p.elapsed), y: .value("Gaze Angle", p.value))
                        .foregroundStyle(by: .value("Eye", p.eye))
                }
                // Target angle (triangular)
                ForEach(targetData) { t in
                    LineMark(x: .value("Time", t.elapsed), y: .value("Gaze Angle", t.value))
                        .foregroundStyle(Color.red.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Horizontal Gaze Angle (°)")
            .chartYScale(domain: yDomain())
            .chartXScale(domain: [0, Float(nFrames) / 60.0])
            .padding()
        }
        }
    }

    private func yDomain() -> ClosedRange<Double> {
        if scaleToFit {
            // Robust auto-fit using P05/P95 to avoid outliers
            let eyes = plotData.map { Double($0.value) }
            let target = targetData.map { Double($0.value) }
            let all = (eyes + target).sorted()
            if all.isEmpty { return -20...20 }
            func percentile(_ p: Double) -> Double {
                let idx = min(max(Int(Double(all.count - 1) * p), 0), all.count - 1)
                return all[idx]
            }
            let p05 = percentile(0.05)
            let p95 = percentile(0.95)
            let span = max(2.0, p95 - p05) // ensure at least a small span
            let pad = max(0.5, 0.1 * span)
            return (p05 - pad)...(p95 + pad)
        }
        // Tighter default if amplitude small
        let targetAmp = (targetData.map { Double($0.value) }.max() ?? 0) - (targetData.map { Double($0.value) }.min() ?? 0)
        if targetAmp < 10 { return -5...5 }
        return -20...20
    }
}


