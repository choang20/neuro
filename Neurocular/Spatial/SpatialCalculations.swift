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
