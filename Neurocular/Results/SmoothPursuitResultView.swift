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
    @State private var showError: Bool = false

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
        func median3(_ xs: [Float]) -> [Float] {
            if xs.count < 3 { return xs }
            var out = xs
            for i in 1..<(xs.count-1) {
                let a = xs[i-1], b = xs[i], c = xs[i+1]
                out[i] = [a,b,c].sorted()[1]
            }
            return out
        }
        func movingAvg(_ xs: [Float], window: Int) -> [Float] {
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
        // --- Robust smoothing pipeline for pursuit ---
        func sgSmooth11(_ xs: [Float]) -> [Float] {
            // Savitzky–Golay (window 11, poly 3) coefficients
            let k: [Float] = [-36, 9, 44, 69, 84, 89, 84, 69, 44, 9, -36].map { $0 / 429.0 }
            let n = xs.count
            if n < k.count { return xs }
            var out = xs
            for i in 5..<(n-5) {
                var acc: Float = 0
                for j in -5...5 { acc += k[j+5] * xs[i+j] }
                out[i] = acc
            }
            return out
        }
        func derivative(_ xs: [Float], dt: Float) -> [Float] {
            guard xs.count > 1 else { return xs }
            var out: [Float] = Array(repeating: 0, count: xs.count)
            for i in 1..<xs.count { out[i] = (xs[i] - xs[i-1]) / dt }
            out[0] = out[1]
            return out
        }
        func maskAndInterpolate(values: [Float], velocity: [Float], threshold: Float, minRun: Int = 8) -> [Float] {
            var vals = values
            let n = values.count
            var i = 0
            while i < n {
                if abs(velocity[i]) > threshold {
                    let start = i
                    var run = 0
                    while i < n && abs(velocity[i]) > threshold { i += 1; run += 1 }
                    if run < minRun { continue }
                    let end = min(i, n-1)
                    let leftVal = start > 0 ? vals[start-1] : vals[end]
                    let rightVal = end < n-1 ? vals[end] : vals[start]
                    let len = max(1, end - start)
                    for t in 0..<len { vals[start+t] = leftVal + (rightVal - leftVal) * Float(t+1) / Float(len+1) }
                } else {
                    i += 1
                }
            }
            return vals
        }
        func pipeline(_ xs: [Float]) -> [Float] {
            let dt: Float = 1.0 / 60.0
            let pre = movingAvg(xs, window: 9)
            let v = derivative(pre, dt: dt)
            let masked = maskAndInterpolate(values: pre, velocity: v, threshold: 60, minRun: 8)
            // Effective wider SG by applying multiple passes
            let sg1 = sgSmooth11(masked)
            let sg2 = sgSmooth11(sg1)
            let sg3 = sgSmooth11(sg2)
            let lp = movingAvg(sg3, window: 31)
            // Spline fit across coarse pivots with slope cap, then resample
            let spline = Self.splineResample(lp, stride: 3, slopeCapDegPerSec: 50)
            // Keep original length so the time axis remains correct
            return spline
        }
        let smoothed = ArrayByEye<Float>(
            left: pipeline(biased.left),
            right: pipeline(biased.right)
        )
        let localPlotData = smoothed.consume_with(tidy_gaze_angles)
        let localNFrames = transforms.count

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
        let localTarget = target
        // Initialize stored properties in one place (avoid using self before init complete)
        self.plotData = localPlotData
        self.nFrames = localNFrames
        self.targetData = localTarget
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading) {
            Text("Smooth Pursuit Result")
                .font(.title3)
                .padding(.horizontal)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { scaleToFit.toggle() }) {
                            Image(systemName: "square.resize")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showError.toggle() }) {
                            Image(systemName: showError ? "waveform.path" : "waveform")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Next") {
                            navigation_path.append(ResultRoute(examId: examId, kind: "saccades"))
                        }
                    }
                }

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
                if showError {
                    ForEach(errorSeries()) { e in
                        LineMark(x: .value("Time", e.elapsed), y: .value("Gaze Angle", e.value))
                            .foregroundStyle(Color.orange.opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5,3]))
                    }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Horizontal Gaze Angle (°)")
            .chartYScale(domain: yDomain())
            .chartXScale(domain: [0, Float(nFrames) / 60.0])
            .frame(height: 300)
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
            let mid = 0.5 * (p05 + p95)
            var span = max(2.0, p95 - p05)
            // Guard against spurious outliers: cap span growth
            span = min(span, 40.0)
            // If very small amplitude, widen to at least ±3° around median
            let half = max(3.0, 0.55 * span)
            return (mid - half)...(mid + half)
        }
        // Tighter default if amplitude small
        let targetAmp = (targetData.map { Double($0.value) }.max() ?? 0) - (targetData.map { Double($0.value) }.min() ?? 0)
        if targetAmp < 10 { return -5...5 }
        return -20...20
    }

    private func errorSeries() -> [PlotValue] {
        // Build average eye by frame_index
        var sumByFrame: [Int: (sum: Double, count: Int, elapsed: Double)] = [:]
        for p in plotData {
            let entry = sumByFrame[p.frame_index] ?? (0, 0, p.elapsed)
            sumByFrame[p.frame_index] = (entry.sum + Double(p.value), entry.count + 1, entry.elapsed)
        }
        var out: [PlotValue] = []
        for t in targetData {
            if let e = sumByFrame[t.frame_index], e.count > 0 {
                let avgEye = e.sum / Double(e.count)
                let err = avgEye - Double(t.value)
                out.append(PlotValue(frame_index: t.frame_index, elapsed: e.elapsed, value: Float(err)))
            }
        }
        return out.sorted { $0.frame_index < $1.frame_index }
    }

    // MARK: - Spline helpers (display only)
    private static func downsample(_ xs: [Float], factor: Int) -> [Float] {
        guard factor > 1 else { return xs }
        var out: [Float] = []
        out.reserveCapacity(xs.count / factor + 1)
        var i = 0
        while i < xs.count { out.append(xs[i]); i += factor }
        if xs.count % factor != 0 { out.append(xs.last!) }
        return out
    }

    private static func splineResample(_ xs: [Float], stride: Int, slopeCapDegPerSec: Float) -> [Float] {
        guard xs.count > stride * 2 else { return xs }
        let dt: Float = 1.0 / 60.0
        let h = Float(stride)
        // Build pivot points
        var pivots: [Float] = []
        var idxs: [Int] = []
        var i = 0
        while i < xs.count { pivots.append(xs[i]); idxs.append(i); i += stride }
        if idxs.last! != xs.count - 1 { pivots.append(xs.last!); idxs.append(xs.count - 1) }
        let mCount = pivots.count
        // Slopes (per sample)
        var m: [Float] = Array(repeating: 0, count: mCount)
        let cap = slopeCapDegPerSec * dt
        for j in 0..<mCount {
            if j == 0 {
                m[j] = (pivots[min(1, mCount-1)] - pivots[0]) / Float(idxs[min(1, mCount-1)] - idxs[0])
            } else if j == mCount - 1 {
                m[j] = (pivots[j] - pivots[j-1]) / Float(idxs[j] - idxs[j-1])
            } else {
                m[j] = (pivots[j+1] - pivots[j-1]) / Float(idxs[j+1] - idxs[j-1])
            }
            m[j] = max(-cap, min(cap, m[j]))
        }
        // Resample back to original grid using Hermite
        var out = xs
        for j in 0..<(mCount-1) {
            let x0 = pivots[j], x1 = pivots[j+1]
            let i0 = idxs[j], i1 = idxs[j+1]
            let segLen = max(1, i1 - i0)
            for s in 0...segLen {
                let t = Float(s) / Float(segLen)
                let h00 = 2*t*t*t - 3*t*t + 1
                let h10 = t*t*t - 2*t*t + t
                let h01 = -2*t*t*t + 3*t*t
                let h11 = t*t*t - t*t
                let val = h00*x0 + h10*(m[j]*Float(segLen)) + h01*x1 + h11*(m[j+1]*Float(segLen))
                out[i0 + s] = val
            }
        }
        return out
    }
}


