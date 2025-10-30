//
//  SpatialCalculation.swift
//  Neurocular
//
//  Created by Max Taggart on 6/1/25.
//

import Foundation
import simd

/**
 Returns the distance of the subject's eyes from the screen, in inches.
 */
func calculate_distance_from_screen(from_transforms transforms: Transforms) -> Float {
    let left_point = SIMD4(transforms.left_eye[3]);
    let right_point = SIMD4(transforms.right_eye[3]);
    let midpoint = (left_point + right_point) * 0.5;
    let inverse_head = simd_float4x4(columns: (
        SIMD4(transforms.head[0]),
        SIMD4(transforms.head[1]),
        SIMD4(transforms.head[2]),
        SIMD4(transforms.head[3])
    )).inverse;
    let d4 = (inverse_head * midpoint);
    let point_in_camera_space = SIMD3<Float>(d4[0], d4[1], d4[2]);
    return Float(simd_length(point_in_camera_space) * 100 / 2.54);
}

func calculate_distance_from_screen_vectorized(_ transforms: [Transforms]) -> [Float] {
    transforms.map(calculate_distance_from_screen)
}

/**
 Returns the horizontal gaze angles for the left and right eyes in degrees, where positive is to the
 subject's right and negative is to the subject's left.
 */
func calculate_horizontal_gaze_angle(
    _ transforms: [Transforms]
) -> ArrayByEye<Float> {
    ArrayByEye(
        left: transforms.map { t in t.left_eye.horizontal_angle},
        right: transforms.map { t in t.right_eye.horizontal_angle}
    )
}


/**
 Returns the vertical gaze angles for the left and right eyes in degrees, where positive is to the
 subject's right and negative is to the subject's left.
 */
func calculate_vertical_gaze_angle(
    _ transforms: [Transforms]
) -> ArrayByEye<Float> {
    ArrayByEye(
        left: transforms.map { t in t.left_eye.vertical_angle},
        right: transforms.map { t in t.right_eye.vertical_angle}
    )
}

func derivative(of values: [Float], inter_sample_distance: Float) -> [Float] {
    if values.count == 1 {
        return values
    }
    var out: [Float] = []
    var previous = values[0]
    for i in 1..<values.count {
        let next_value = values[i]
        out.append((next_value - previous) / inter_sample_distance)
        previous = next_value
    }
    // Copy the last element in order to keep the retain
    // the length of the input vector
    out.append(out[out.count - 1])
    return out
}

// MARK: - Head yaw relative to camera (robust to device orientation)

/**
 Returns the head yaw in degrees relative to the camera/screen for a given frame.
 Uses the relative transform (inverse(camera) * head) and extracts yaw from a
 quaternion to decouple pitch/roll.
 */
// Original quaternion-based yaw (kept for reference/testing)
func headYawDegreesRelativeToCamera_quat(_ transforms: Transforms) -> Float {
    let cam = simd_float4x4(columns: (
        SIMD4(transforms.camera[0]),
        SIMD4(transforms.camera[1]),
        SIMD4(transforms.camera[2]),
        SIMD4(transforms.camera[3])
    ))
    let head = simd_float4x4(columns: (
        SIMD4(transforms.head[0]),
        SIMD4(transforms.head[1]),
        SIMD4(transforms.head[2]),
        SIMD4(transforms.head[3])
    ))
    let relative = simd_inverse(cam) * head
    let q = simd_quatf(relative)
    let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
    let yawRadians = atan2f(2*(w*y + z*x), 1 - 2*(y*y + x*x))
    return yawRadians * 180.0 / .pi
}

// Robust yaw via forward-vector projection in camera coordinates.
// Works consistently regardless of device orientation or which front camera is used.
func headYawDegreesRelativeToCamera(_ transforms: Transforms) -> Float {
    let cam = simd_float4x4(columns: (
        SIMD4(transforms.camera[0]),
        SIMD4(transforms.camera[1]),
        SIMD4(transforms.camera[2]),
        SIMD4(transforms.camera[3])
    ))
    let head = simd_float4x4(columns: (
        SIMD4(transforms.head[0]),
        SIMD4(transforms.head[1]),
        SIMD4(transforms.head[2]),
        SIMD4(transforms.head[3])
    ))
    // Head in camera space
    let rel = simd_inverse(cam) * head
    // Camera looks along -Z. Head forward in its local frame is -Z. Extract rel's Z axis.
    let zAxis = SIMD3<Float>(rel.columns.2.x, rel.columns.2.y, rel.columns.2.z)
    let headForward = simd_normalize(-zAxis)
    // Project forward onto camera XZ-plane and compute yaw about +Y.
    let fXZ = simd_normalize(SIMD2<Float>(headForward.x, headForward.z))
    // atan2(x, -z): right is +, left is - (camera coordinates)
    let yaw = atan2f(fXZ.x, -fXZ.y) * 180.0 / .pi
    return yaw
}

/**
 Tracks a calibrated and lightly smoothed head yaw. Call `reset()` at the start
 of a test, then feed frames to `update`. Returns nil for untracked frames.
 */
final class HeadYawTracker {
    static let shared = HeadYawTracker()
    private var baselineDeg: Float? = nil
    private var filteredDeg: Float = 0
    private let alpha: Float = 0.3
    
    func reset() {
        baselineDeg = nil
        filteredDeg = 0
    }
    
    func setBaseline(_ value: Float) {
        baselineDeg = value
        filteredDeg = 0
    }
    
    func update(with transforms: Transforms, isTracked: Bool) -> Float? {
        guard isTracked else { return nil }
        let raw = headYawDegreesRelativeToCamera(transforms)
        // If baseline not set, do not infer it from the first frame; return nil until caller calibrates
        guard let baseline = baselineDeg else { return nil }
        let zeroed = raw - baseline
        filteredDeg = alpha * zeroed + (1 - alpha) * filteredDeg
        return filteredDeg
    }

    // Returns zeroed yaw using the calibrated baseline, without smoothing or tracking requirement.
    func zeroedYaw(_ transforms: Transforms) -> Float? {
        guard let baseline = baselineDeg else { return nil }
        let raw = headYawDegreesRelativeToCamera(transforms)
        return raw - baseline
    }
}
