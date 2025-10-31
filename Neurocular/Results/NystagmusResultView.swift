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
    struct PSDPoint: Identifiable { let id = UUID(); let f: Double; let p: Double }
    private let psd: [PSDPoint]
    private let peakHz: Double
    private let baselineLP: [Double]
    private let reconSaw: [Double]
    private let reconCombined: [Double]
    private let hasNystagmus: Bool
    @State private var window: ClosedRange<Double>
    @State private var hideFastPhases = true
    @State private var smoothWindow = 4
    // Baseline is always shown; the overlay eye trace and sawtooth appear together
    private let showDetails = false // hide velocity and PSD by default

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
        // Build analysis signal per neuro-ophthalmologist guidance
        let masked = Self.maskFastPhases(pos: eyeDeg, vel: eyeVel, vth: 30)
        let filled = Self.interpolateNaNs(masked)
        let detrended = Self.highPass(filled, cutoffHz: 0.5, fs: 60.0)
        // Slow baseline (LP 0.4 Hz) and narrowband sawtooth (2–5 Hz with 3 harmonics)
        let baseline = Self.lowPassMA(filled, cutoffHz: 0.3, fs: 60.0)
        let saw = Self.reconstructHarmonics(detrended, fs: 60.0, fmin: 2.0, fmax: 5.0, harmonics: 3)
        self.baselineLP = baseline
        self.reconSaw = saw
        self.reconCombined = zip(baseline, saw).map(+)

        // Welch PSD on detrended position (full length)
        let (freqs, power) = Self.welchPSD(detrended, fs: 60.0, nperseg: 256, overlap: 0.5)
        var pts: [PSDPoint] = []
        for i in 0..<freqs.count { if freqs[i] <= 10.0 { pts.append(PSDPoint(f: freqs[i], p: power[i])) } }
        self.psd = pts
        // Peak in 2–5 Hz
        let band = pts.filter { $0.f >= 2.0 && $0.f <= 5.0 }
        self.peakHz = band.max(by: { $0.p < $1.p })?.f ?? 0
        // Simple nystagmus detector: band power ratio (2–5 Hz vs 0.5–10 Hz)
        let bandPower = band.reduce(0) { $0 + $1.p }
        let totalPower = pts.filter { $0.f >= 0.5 && $0.f <= 10.0 }.reduce(0) { $0 + $1.p }
        self.hasNystagmus = (totalPower > 0) ? (bandPower/totalPower) > 0.1 : false
        // Auto-focus on the largest fast phase (reset): window around the biggest |velocity| spike
        let totalT = Double(tmp.count) * dt
        // Show full recording span by default so slow baseline curvature is visible
        self._window = State(initialValue: 0...totalT)
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nystagmus Result")
                    .font(.title3)
                Spacer()
            }.padding(.horizontal)

            // Removed baseline-only toggle for a simpler view

            // Position (deg)
            let segs = segments(filteredDegrees(samples))
            let eyeSeries = eyeSeriesFrom(segs)
            let baselineSeries = seriesFrom(baselineLP)
            let reconSeries = hasNystagmus ? seriesFrom(reconCombined) : []
            positionChart(eyeSeries: eyeSeries, baselineSeries: baselineSeries, reconSeries: reconSeries)
            .chartXAxisLabel("Seconds")
            .chartYAxisLabel("Degrees")
            .chartYScale(domain: -45...45)
            .chartXScale(domain: window)
            .chartForegroundStyleScale([:])
            .chartPlotStyle { plot in
                plot.clipShape(Rectangle())
            }
            .frame(height: 220)
            .padding(.horizontal)
            .padding(.top, 8)

            if showDetails {
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

                // Welch PSD (position) 0–10 Hz
                Chart(psd) {
                    LineMark(x: .value("Hz", $0.f), y: .value("Power", $0.p))
                        .foregroundStyle(Color.purple)
                }
                .chartXAxisLabel("Hz")
                .chartYAxisLabel("PSD (deg²/Hz)")
                .chartXScale(domain: 0...10)
                .frame(height: 160)
                .padding(.horizontal)
                .overlay(alignment: .leading) {
                    if peakHz > 0 {
                        GeometryReader { geo in
                            let x = geo.size.width * CGFloat(peakHz / 10.0)
                            Rectangle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 2)
                                .offset(x: x)
                        }
                    }
                }
            }
        }
        .padding(.bottom)
        }
    }

    // Zoom controls removed for clarity. We auto-focus the window in init.

    private func filteredDegrees(_ s: [Sample]) -> [Sample] {
        // 1) Mask fast phases with higher threshold and extend gaps
        let thresh = 80.0
        let pad = 2 // extend by ±2 frames
        var masked: [Sample] = s
        if hideFastPhases {
            // mark indices to mask
            var maskIdx: Set<Int> = []
            for (i, smp) in s.enumerated() {
                if abs(smp.eyeVel) > thresh { maskIdx.insert(i) }
            }
            // extend
            for i in maskIdx {
                let start = max(0, i - pad)
                let end = min(s.count - 1, i + pad)
                for j in start...end { maskIdx.insert(j) }
            }
            for i in maskIdx { masked[i] = Sample(t: s[i].t, eyeDeg: Double.nan, eyeVel: s[i].eyeVel) }
        }
        // 2) Gentle median3 + MA(3–5) on remaining visible segments only
        var y = masked
        y = median3Deg(y)
        y = movingAverageDeg(y, window: max(3, min(5, smoothWindow)))
        // 3) Window and decimate for plotting
        y = y.filter { $0.t >= window.lowerBound && $0.t <= window.upperBound }
        return downsample(y, factor: 2)
    }

    private func filteredVelocity(_ s: [Sample]) -> [Sample] {
        var out = s
        // Hide extreme spikes that cause full-height rails in the plot
        out = out.map { smp in
            abs(smp.eyeVel) > 400 ? Sample(t: smp.t, eyeDeg: smp.eyeDeg, eyeVel: Double.nan) : smp
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

    // Split into contiguous non-NaN segments to avoid connecting across gaps
    private func segments(_ s: [Sample]) -> [[Sample]] {
        var out: [[Sample]] = []
        var cur: [Sample] = []
        var lastT: Double? = nil
        for pt in s {
            if pt.eyeDeg.isNaN {
                if !cur.isEmpty { out.append(cur); cur.removeAll() }
                lastT = nil
            } else {
                if let lt = lastT {
                    let dt = pt.t - lt
                    // Split on backward time or large gap (>0.3s)
                    if dt < 0 || dt > 0.3 {
                        if !cur.isEmpty { out.append(cur); cur.removeAll() }
                    }
                }
                cur.append(pt)
                lastT = pt.t
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    // MARK: - Analysis helpers (masking, filtering, PSD)
    private static func maskFastPhases(pos: [Double], vel: [Double], vth: Double) -> [Double] {
        var out = pos
        for i in 0..<min(pos.count, vel.count) {
            if abs(vel[i]) > vth { out[i] = .nan }
        }
        return out
    }

    private static func interpolateNaNs(_ x: [Double]) -> [Double] {
        var y = x
        var i = 0
        let n = y.count
        while i < n {
            if y[i].isNaN {
                let start = i - 1
                var j = i
                while j < n && y[j].isNaN { j += 1 }
                let end = j
                let left = start >= 0 ? y[start] : (end < n ? y[end] : 0)
                let right = end < n ? y[end] : left
                let len = max(1, end - start)
                for k in i..<end {
                    let t = Double(k - i + 1) / Double(len)
                    y[k] = left + (right - left) * t
                }
                i = end
            } else { i += 1 }
        }
        return y
    }

    private static func movingAvgD(_ x: [Double], window: Int) -> [Double] {
        guard window > 1 else { return x }
        var y: [Double] = []
        y.reserveCapacity(x.count)
        var buf: [Double] = []
        for v in x {
            buf.append(v)
            if buf.count > window { buf.removeFirst() }
            y.append(buf.reduce(0,+) / Double(buf.count))
        }
        return y
    }

    private func median3Deg(_ s: [Sample]) -> [Sample] {
        guard s.count >= 3 else { return s }
        var out = s
        for i in 1..<(s.count-1) {
            let a = s[i-1].eyeDeg
            let b = s[i].eyeDeg
            let c = s[i+1].eyeDeg
            if a.isNaN || b.isNaN || c.isNaN { continue }
            let m = [a,b,c].sorted()[1]
            out[i] = Sample(t: s[i].t, eyeDeg: m, eyeVel: s[i].eyeVel)
        }
        return out
    }

    private static func lowPassMA(_ x: [Double], cutoffHz: Double, fs: Double) -> [Double] {
        let win = max(3, Int(round(fs / max(cutoffHz, 1e-3))))
        return movingAvgD(x, window: win)
    }

    private static func highPass(_ x: [Double], cutoffHz: Double, fs: Double) -> [Double] {
        // Simple HP via subtracting long-window moving average
        let period = max(1, Int(fs / max(cutoffHz, 1e-3))) // ~1/cutoff seconds
        let trend = movingAvgD(x, window: period)
        return zip(x, trend).map { $0 - $1 }
    }

    private static func hann(_ n: Int) -> [Double] {
        guard n > 1 else { return Array(repeating: 1, count: max(n,1)) }
        return (0..<n).map { 0.5 - 0.5 * cos(2.0 * .pi * Double($0) / Double(n-1)) }
    }

    private static func welchPSD(_ x: [Double], fs: Double, nperseg: Int, overlap: Double) -> ([Double],[Double]) {
        let n = x.count
        let seg = min(nperseg, n)
        let step = max(1, Int(Double(seg) * (1.0 - overlap)))
        let window = hann(seg)
        var acc: [Double] = Array(repeating: 0, count: seg/2+1)
        var count = 0
        var start = 0
        while start + seg <= n {
            let slice = Array(x[start..<(start+seg)])
            let mean = slice.reduce(0,+) / Double(seg)
            var w: [Double] = []
            w.reserveCapacity(seg)
            for i in 0..<seg { w.append((slice[i] - mean) * window[i]) }
            let p = periodogram(w)
            for i in 0..<acc.count { acc[i] += p[i] }
            count += 1
            start += step
        }
        if count == 0 { return ([],[]) }
        let scale = 1.0 / Double(count)
        let psd = acc.map { $0 * scale / fs }
        let freqs = (0..<acc.count).map { fs * Double($0) / Double(seg) }
        return (freqs, psd)
    }

    private static func periodogram(_ x: [Double]) -> [Double] {
        // Naive DFT power for real signal; returns bins 0..N/2
        let n = x.count
        let half = n/2
        var out: [Double] = Array(repeating: 0, count: half+1)
        for k in 0...half {
            var re = 0.0, im = 0.0
            let twoPiNk = 2.0 * .pi * Double(k) / Double(n)
            for (i, v) in x.enumerated() {
                let angle = twoPiNk * Double(i)
                re += v * cos(angle)
                im -= v * sin(angle)
            }
            out[k] = (re*re + im*im) / Double(n)
        }
        return out
    }

    // Reconstruct narrowband component around the dominant peak in [fmin,fmax],
    // preserving phase and first few harmonics.
    private static func reconstructHarmonics(_ x: [Double], fs: Double, fmin: Double, fmax: Double, harmonics: Int) -> [Double] {
        let n = x.count
        if n == 0 { return [] }
        // DFT
        var Re = Array(repeating: 0.0, count: n)
        var Im = Array(repeating: 0.0, count: n)
        for k in 0..<n {
            var r = 0.0, m = 0.0
            let twoPiNk = 2.0 * .pi * Double(k) / Double(n)
            for (i, v) in x.enumerated() {
                let a = twoPiNk * Double(i)
                r += v * cos(a)
                m -= v * sin(a)
            }
            Re[k] = r
            Im[k] = m
        }
        let binHz = fs / Double(n)
        let kmin = max(1, Int(floor(fmin / binHz)))
        let kmax = min(n/2 - 1, Int(ceil(fmax / binHz)))
        if kmax <= kmin { return Array(repeating: 0, count: n) }
        // Find dominant bin in band
        var bestK = kmin
        var bestMag = 0.0
        for k in kmin...kmax {
            let mag = Re[k]*Re[k] + Im[k]*Im[k]
            if mag > bestMag { bestMag = mag; bestK = k }
        }
        // Keep fundamental and first few harmonics symmetrically
        var R2 = Array(repeating: 0.0, count: n)
        var I2 = Array(repeating: 0.0, count: n)
        for h in 1...harmonics {
            let k = bestK * h
            if k >= n/2 { break }
            R2[k] = Re[k]; I2[k] = Im[k]
            let kc = n - k
            R2[kc] = Re[kc]; I2[kc] = Im[kc]
        }
        // Inverse DFT
        var y = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for k in 0..<n {
                let a = 2.0 * .pi * Double(k) * Double(i) / Double(n)
                sum += R2[k] * cos(a) - I2[k] * sin(a)
            }
            y[i] = sum / Double(n)
        }
        return y
    }

    // Series for overlay from full-length arrays, sliced to current window
    struct YPoint: Identifiable { let id = UUID(); let t: Double; let y: Double }
    private func seriesFrom(_ arr: [Double]) -> [YPoint] {
        var pts: [YPoint] = []
        pts.reserveCapacity(arr.count)
        let dt = 1.0 / 60.0
        for i in 0..<arr.count {
            let t = Double(i) * dt
            if t >= window.lowerBound && t <= window.upperBound {
                pts.append(YPoint(t: t, y: arr[i]))
            }
        }
        return pts
    }

    // Eye series with segment keys to prevent cross-gap connections
    struct SegPoint: Identifiable { let id = UUID(); let t: Double; let y: Double; let series: String }
    private func eyeSeriesFrom(_ segs: [[Sample]]) -> [SegPoint] {
        var out: [SegPoint] = []
        for (idx, seg) in segs.enumerated() {
            let key = "eye_\(idx)"
            for s in seg { out.append(SegPoint(t: s.t, y: s.eyeDeg, series: key)) }
        }
        return out
    }

    // Extracted chart builder to reduce type-checking complexity
    @ViewBuilder
    private func positionChart(eyeSeries: [SegPoint], baselineSeries: [YPoint], reconSeries: [YPoint]) -> some View {
        Chart {
            ForEach(eyeSeries) { p in
                LineMark(x: .value("t", p.t), y: .value("deg", p.y))
                    .foregroundStyle(by: .value("Series", p.series))
            }
            ForEach(reconSeries) { p in
                LineMark(x: .value("t", p.t), y: .value("deg", p.y))
                    .foregroundStyle(Color.red.opacity(0.7))
            }
            ForEach(baselineSeries) { p in
                LineMark(x: .value("t", p.t), y: .value("deg", p.y))
                    .foregroundStyle(Color.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
    }
}


