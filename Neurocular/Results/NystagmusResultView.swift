//
//  NystagmusResultView.swift
//  Neurocular
//

import SwiftUI
import Charts

struct NystagmusResultView: View {
    let examId: ExamId
    @Binding var navigation_path: NavigationPath
    @Binding var storage_manager: StorageManager

    struct Sample: Identifiable {
        let id = UUID()
        let t: Double
        let eyeDeg: Double
        let eyeVel: Double
    }

    private let samples: [Sample]
    @State private var window: ClosedRange<Double>
    @State private var hideFastPhases = true
    @State private var smoothWindow = 5

    init(examId: ExamId, navigation_path: Binding<NavigationPath>, storage_manager: Binding<StorageManager>) {
        self.examId = examId
        self._navigation_path = navigation_path
        self._storage_manager = storage_manager

        let frames = storage_manager.wrappedValue.get_exam_frames_by_id(examId)!
        let interpolated = interpolate_frames(frames)
        let transforms = interpolated.map { $0.transforms.transforms }
        let byEye = calculate_horizontal_gaze_angle(transforms).map_by_eye(apply_angle_calibration)
        let biased = bias_right_eye(byEye)
        let left = biased.left.map { Double($0) }
        let right = biased.right.map { Double($0) }
        let eyeDeg = zip(left, right).map { ($0 + $1) / 2.0 }
        let dt: Double = 1.0 / 60.0

        var eyeVel: [Double] = []
        eyeVel.reserveCapacity(eyeDeg.count)
        for i in 0..<eyeDeg.count { eyeVel.append(i == 0 ? 0 : (eyeDeg[i]-eyeDeg[i-1]) / dt) }

        var tmp: [Sample] = []
        tmp.reserveCapacity(eyeDeg.count)
        for i in 0..<eyeDeg.count { tmp.append(Sample(t: Double(i)*dt, eyeDeg: eyeDeg[i], eyeVel: eyeVel[i])) }
        self.samples = tmp
        self._window = State(initialValue: 0...(Double(tmp.count)/60.0))
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nystagmus Result")
                    .font(.title3)
                Spacer()
            }.padding(.horizontal)

            controls

            // Position (deg)
            Chart(filteredDegrees(samples)) {
                LineMark(x: .value("t", $0.t), y: .value("deg", $0.eyeDeg))
                    .foregroundStyle(Color.blue)
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Degrees")
            .chartYScale(domain: -45...45)
            .chartXScale(domain: window)
            .frame(height: 220)
            .padding(.horizontal)

            // Velocity (deg/s)
            Chart(filteredVelocity(samples)) {
                LineMark(x: .value("t", $0.t), y: .value("vel", $0.eyeVel))
                    .foregroundStyle(Color.green)
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Velocity (deg/s)")
            .chartYScale(domain: -200...200)
            .chartXScale(domain: window)
            .frame(height: 160)
            .padding(.horizontal)
        }
        .padding(.bottom)
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 16) {
            Text("Zoom")
            Slider(value: Binding(
                get: { window.lowerBound },
                set: { window = $0...window.upperBound }
            ), in: 0...(samples.last?.t ?? 0), step: 0.1)
            Slider(value: Binding(
                get: { window.upperBound },
                set: { window = window.lowerBound...$0 }
            ), in: 0...(samples.last?.t ?? 0), step: 0.1)
            Toggle("Hide >30°/s", isOn: $hideFastPhases)
            Stepper("Smooth: \(smoothWindow)", value: $smoothWindow, in: 1...9)
        }
        .padding(.horizontal)
    }

    private func filteredDegrees(_ s: [Sample]) -> [Sample] {
        var out = s
        if hideFastPhases {
            out = out.map { smp in
                abs(smp.eyeVel) > 30 ? Sample(t: smp.t, eyeDeg: Double.nan, eyeVel: smp.eyeVel) : smp
            }
        }
        if smoothWindow > 1 {
            out = movingAverageDeg(out, window: smoothWindow)
        }
        out = out.filter { $0.t >= window.lowerBound && $0.t <= window.upperBound }
        return downsample(out, factor: 2)
    }

    private func filteredVelocity(_ s: [Sample]) -> [Sample] {
        var out = s
        // Hide extreme spikes that cause full-height rails in the plot
        out = out.map { smp in
            abs(smp.eyeVel) > 200 ? Sample(t: smp.t, eyeDeg: smp.eyeDeg, eyeVel: Double.nan) : smp
        }
        if smoothWindow > 1 {
            out = movingAverageVel(out, window: max(3, smoothWindow/2))
        }
        out = out.filter { $0.t >= window.lowerBound && $0.t <= window.upperBound }
        return downsample(out, factor: 2)
    }

    private func movingAverageDeg(_ s: [Sample], window: Int) -> [Sample] {
        guard window > 1 else { return s }
        var out: [Sample] = []
        out.reserveCapacity(s.count)
        var buf: [Double] = []
        for (i, smp) in s.enumerated() {
            if !smp.eyeDeg.isNaN { buf.append(smp.eyeDeg) } else { buf.append(Double.nan) }
            if buf.count > window { buf.removeFirst() }
            let deg = buf.filter{ !$0.isNaN }.reduce(0, +) / Double(max(1, buf.filter{ !$0.isNaN }.count))
            out.append(Sample(t: smp.t, eyeDeg: deg, eyeVel: smp.eyeVel))
        }
        return out
    }

    private func movingAverageVel(_ s: [Sample], window: Int) -> [Sample] {
        guard window > 1 else { return s }
        var out: [Sample] = []
        out.reserveCapacity(s.count)
        var vbuf: [Double] = []
        for smp in s {
            vbuf.append(smp.eyeVel)
            if vbuf.count > window { vbuf.removeFirst() }
            let vel = vbuf.reduce(0, +) / Double(vbuf.count)
            out.append(Sample(t: smp.t, eyeDeg: smp.eyeDeg, eyeVel: vel))
        }
        return out
    }

    // Simple plotting downsample to reduce overdraw
    private func downsample(_ s: [Sample], factor: Int) -> [Sample] {
        guard factor > 1 else { return s }
        var out: [Sample] = []
        out.reserveCapacity(s.count / factor + 1)
        var i = 0
        while i < s.count {
            out.append(s[i])
            i += factor
        }
        if s.count % factor != 0 { out.append(s.last!) }
        return out
    }
}


