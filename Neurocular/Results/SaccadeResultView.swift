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
    struct StepWindow: Identifiable { let id = UUID(); let index: Int; let title: String; let slice: [Sample]; let latencyMs: Int; let peakVel: Int; let endpointErr: Int }
    private let steps: [StepWindow]

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
        let scale: Double = Double(UIScreen.main.scale) // points→pixels conversion
        let screenMidX = Double(UIScreen.main.bounds.midX)
        var targetDeg: [Double] = []
        targetDeg.reserveCapacity(n)
        for s in spatial {
            // advance pointer to most recent position at or before this timestamp
            while posIndex + 1 < positions.count && positions[posIndex + 1].timestamp <= s.timestamp {
                posIndex += 1
            }
            let pxX = positions.isEmpty ? screenMidX : Double(positions[posIndex].value.x)
            let deltaPts = pxX - screenMidX
            // Convert SwiftUI points → pixels before PPI conversion
            let deltaPixels = deltaPts * scale
            let inchesX = deltaPixels / ppi
            // Use a fixed viewing distance (60cm) so steps are truly flat between jumps
            let dist = 600.0 / 25.4
            let ang = atan2(inchesX, dist) * 180.0 / .pi
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
        var sdeg: [Double] = []
        sdeg.reserveCapacity(interp.count)
        for f in interp {
            let inches = Double(calculate_distance_from_screen(from_transforms: f.transforms.transforms))
            let pixelsPerDeg = max(ppi * inches * tan(.pi / 180.0), 1e-6)
            let speedPointsPerSec = f.speed
            // Convert points/s → pixels/s before turning into deg/s
            let speedPixelsPerSec = speedPointsPerSec * scale
            sdeg.append(speedPixelsPerSec / pixelsPerDeg)
        }
        self.speedDeg = sdeg
        // Detect steps from target angle change
        self.steps = SaccadeResultView.detectSteps(all: tmp)
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saccades Result")
                .font(.title3)
                .padding(.horizontal)
                .padding(.top, 8)

            // Top spacer to avoid any overlap with nav bar on compact devices
            Rectangle().fill(Color.clear).frame(height: 8)

            ForEach(steps) { st in
                SaccadePanel(title: st.title, slice: st.slice, metrics: (latencyMs: st.latencyMs, peakVel: st.peakVel, endpointErr: st.endpointErr))
            }
        }
        .padding(.bottom)
        .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Step detection based on target position change
    private static func detectSteps(all: [Sample]) -> [StepWindow] {
        let n = all.count
        guard n > 2 else { return [] }
        var onsets: [Int] = []
        let dt = 1.0 / 60.0
        let thr = 5.0 // degrees change
        var i = 1
        while i < n {
            let d = all[i].targetDeg - all[i-1].targetDeg
            if abs(d) >= thr {
                onsets.append(i)
                // skip ahead ~0.8s to avoid duplicate detection
                i += Int(0.8 / dt)
                continue
            }
            i += 1
        }
        var steps: [StepWindow] = []
        for (idx, onset) in onsets.enumerated() {
            let start = max(0, onset - Int(0.2 / dt))
            let end = min(n-1, onset + Int(0.8 / dt))
            if end <= start { continue }
            let sliceRaw = Array(all[start...end])
            let t0 = all[onset].t
            let slice = sliceRaw.map { s in Sample(t: s.t - t0, targetDeg: s.targetDeg, eyeDeg: s.eyeDeg, eyeVel: s.eyeVel) }
            // Metrics
            let latencyFrames = Self.computeLatency(slice: slice)
            let latencyMs = Int(Double(latencyFrames) * dt * 1000.0)
            let peak = Self.computePeakVel(slice: slice)
            let err = Self.computeEndpointError(slice: slice)
            let dtheta = all[min(onset+1,n-1)].targetDeg - all[max(onset-1,0)].targetDeg
            let title = String(format: "Step %d (Δ%.0f° %@)", idx+1, abs(dtheta), dtheta>=0 ? "→" : "←")
            steps.append(StepWindow(index: idx+1, title: title, slice: slice, latencyMs: latencyMs, peakVel: Int(round(peak)), endpointErr: Int(round(err))))
        }
        return steps
    }

    private static func computeLatency(slice: [Sample]) -> Int {
        // first time |vel|>30 deg/s for >=2 frames
        var run = 0
        for (i,s) in slice.enumerated() where s.t >= 0 {
            if abs(s.eyeVel) > 30 { run += 1 } else { run = 0 }
            if run >= 2 { return i-1 }
        }
        return slice.count
    }

    private static func computePeakVel(slice: [Sample]) -> Double {
        var peak = 0.0
        for s in slice where s.t >= 0 && s.t <= 0.25 { peak = max(peak, abs(s.eyeVel)) }
        return peak
    }

    private static func computeEndpointError(slice: [Sample]) -> Double {
        // average eye minus target 0.25..0.35s after onset
        let lo = 0.25, hi = 0.35
        var sum = 0.0, cnt = 0.0
        for s in slice where s.t >= lo && s.t <= hi { sum += (s.eyeDeg - s.targetDeg); cnt += 1 }
        return cnt > 0 ? sum/cnt : 0
    }
}

private struct SaccadePanel: View {
    let title: String
    let slice: [SaccadeResultView.Sample]
    let metrics: (latencyMs: Int, peakVel: Int, endpointErr: Int)?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.leading)
            // Simple view: hide metrics for a cleaner single chart
            // If you want metrics back, re-enable the block below.
            // if let m = metrics {
            //     Text("latency: \(m.latencyMs) ms   peak: \(m.peakVel)°/s   endpoint: \(m.endpointErr)°")
            //         .font(.caption)
            //         .foregroundStyle(.secondary)
            //         .padding(.leading)
            // }

            // Degrees chart (fixed domain)
            Chart {
                // Target position as square wave using duplicate points at jumps
                ForEach(stepPoints(slice), id: \.0) { p in
                    LineMark(x: .value("t", p.0), y: .value("deg", p.1))
                        .foregroundStyle(by: .value("Series", "Target"))
                }
                // Eye position (deg)
                ForEach(slice) { s in
                    LineMark(x: .value("t", s.t), y: .value("deg", s.eyeDeg))
                        .foregroundStyle(by: .value("Series", "Eye"))
                }
                // Annotate step onset (t=0) and latency (if available)
                RuleMark(x: .value("t", 0.0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,3]))
                    .foregroundStyle(Color.gray.opacity(0.6))
                if let m = metrics {
                    let tLatency = Double(m.latencyMs) / 1000.0
                    RuleMark(x: .value("t", tLatency))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2,2]))
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .annotation(position: .top, alignment: .center) {
                            Text("Latency")
                                .font(.caption2)
                                .foregroundStyle(Color.orange)
                        }
                }
            }
            .chartForegroundStyleScale([
                "Target": .red,
                "Eye": .blue
            ])
            .chartYAxis {
                AxisMarks(position: .leading, values: [-45, -30, -15, 0, 15, 30, 45]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self)!)°") }
                }
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Degrees")
            .chartYScale(domain: -45...45)
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
            .padding(.horizontal)

            // Simple view: velocity panel removed for clarity
        }
    }

    // Build square-wave points by duplicating time at jump boundaries
    private func stepPoints(_ s: [SaccadeResultView.Sample]) -> [(Double, Double)] {
        guard !s.isEmpty else { return [] }
        var pts: [(Double, Double)] = []
        pts.reserveCapacity(s.count * 2)
        var prev = s[0].targetDeg
        pts.append((s[0].t, prev))
        for i in 1..<s.count {
            let curr = s[i].targetDeg
            let t = s[i].t
            if curr != prev {
                // vertical edge: duplicate time at boundary with previous value, then new value
                pts.append((t, prev))
                pts.append((t, curr))
                prev = curr
            } else {
                pts.append((t, curr))
            }
        }
        return pts
    }
}


