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
    @State private var hideFastPhases = false
    @State private var smoothWindow = 3

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nystagmus Result")
                    .font(.title3)
                Spacer()
            }.padding(.horizontal)

            controls

            Chart(filtered(samples)) {
                LineMark(x: .value("t", $0.t), y: .value("deg", $0.eyeDeg))
                    .foregroundStyle(Color.blue)
                LineMark(x: .value("t", $0.t), y: .value("vel", $0.eyeVel))
                    .foregroundStyle(Color.green)
            }
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel(position: .leading) { Text("Degrees") }
            .chartYAxisLabel(position: .trailing) { Text("Velocity") }
            .chartYScale(domain: -45...45)
            .chartXScale(domain: window)
            .frame(height: 260)
            .padding(.horizontal)
        }
        .padding(.bottom)
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

    private func filtered(_ s: [Sample]) -> [Sample] {
        var out = s
        if hideFastPhases {
            out = out.map { smp in
                abs(smp.eyeVel) > 30 ? Sample(t: smp.t, eyeDeg: Double.nan, eyeVel: smp.eyeVel) : smp
            }
        }
        if smoothWindow > 1 {
            out = movingAverage(out, window: smoothWindow)
        }
        return out.filter { $0.t >= window.lowerBound && $0.t <= window.upperBound }
    }

    private func movingAverage(_ s: [Sample], window: Int) -> [Sample] {
        guard window > 1 else { return s }
        var out: [Sample] = []
        out.reserveCapacity(s.count)
        var buf: [Double] = []
        var vbuf: [Double] = []
        for (i, smp) in s.enumerated() {
            if !smp.eyeDeg.isNaN { buf.append(smp.eyeDeg) } else { buf.append(Double.nan) }
            vbuf.append(smp.eyeVel)
            if buf.count > window { buf.removeFirst(); vbuf.removeFirst() }
            let deg = buf.filter{ !$0.isNaN }.reduce(0, +) / Double(max(1, buf.filter{ !$0.isNaN }.count))
            let vel = vbuf.reduce(0, +) / Double(vbuf.count)
            out.append(Sample(t: smp.t, eyeDeg: deg, eyeVel: vel))
        }
        return out
    }
}


