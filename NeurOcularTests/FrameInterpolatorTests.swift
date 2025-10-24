//
//  NeurOcularTests.swift
//  NeurOcularTests
//
//  Created by Max Taggart on 6/30/25.
//

import Testing
import Foundation
@testable import NeurOcular

func t_from_time(_ timestamp: Date) -> SpatialTransforms {
    SpatialTransforms(
        transforms: Transforms(
            camera: SerializableMatrix4x4.zeros(),
            head: SerializableMatrix4x4.zeros(),
            left_eye: SerializableMatrix4x4.zeros(),
            right_eye: SerializableMatrix4x4.zeros()
        ),
        wild_guess: false,
        timestamp: timestamp
    )
}
/**
 Construct spatial frames that are 1 second apart starting at the current date.
 */
func create_spatial_frames() -> [SpatialTransforms] {
     let now = Date()
     return [
        t_from_time(now),
        t_from_time(now.advanced(by: 1)),
        t_from_time(now.advanced(by: 2)),
        t_from_time(now.advanced(by: 3)),
     ]
 }




struct FrameInterpolation {

    @Test("1 to 1 with stimulus and speed slightly before spatial")
    func one_to_one_1() async throws {
        let spatial_frames = create_spatial_frames()
        let stimulus_positions = spatial_frames.enumerated().map {(index, s_frame) in
            TimestampedValue<Point>(
                timestamp: s_frame.timestamp.advanced(by: -0.1),
                value: Point(x: Double(index), y: Double(index))
            )
        }
        let stimulus_speeds = spatial_frames.enumerated().map {(index, s_frame) in
            TimestampedValue<Double>(
                timestamp: s_frame.timestamp.advanced(by: -0.1),
                value: Double(index)
            )
        }
        let test_frames = ExamFrames(
            exam_id: "test1",
            spatial_transforms: spatial_frames,
            stimulus_positions: stimulus_positions,
            stimulus_speeds: stimulus_speeds
        )
        let interpolated_frames = interpolate_frames(test_frames)
        let expected_interpolated_frames = [
            InterpolatedFrame(
                timestamp: spatial_frames[0].timestamp,
                position: stimulus_positions[0].value,
                speed: stimulus_speeds[0].value,
                transforms: spatial_frames[0],
                wild_guess: spatial_frames[0].wild_guess
            ),
            InterpolatedFrame(
                timestamp: spatial_frames[1].timestamp,
                position: Point(x: 0.9, y: 0.9),
                speed: 0.9,
                transforms: spatial_frames[1],
                wild_guess: spatial_frames[1].wild_guess
            ),
            InterpolatedFrame(
                timestamp: spatial_frames[2].timestamp,
                position: Point(x: 1.9, y: 1.9),
                speed: 1.9,
                transforms: spatial_frames[2],
                wild_guess: spatial_frames[2].wild_guess
            ),
            InterpolatedFrame(
                timestamp: spatial_frames[3].timestamp,
                position: Point(x: 2.9, y: 2.9),
                speed: 2.9,
                transforms: spatial_frames[3],
                wild_guess: spatial_frames[3].wild_guess
            )
        ]
        for (observed_frame, expected_frame) in zip(interpolated_frames, expected_interpolated_frames) {
            #expect(observed_frame == expected_frame)
        }
        
    }

}
