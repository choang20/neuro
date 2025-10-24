import Foundation

struct InterpolatedFrame: Equatable {
    let timestamp: Date
    let position: Point
    let speed: Double
    let transforms: SpatialTransforms
    let wild_guess: Bool
}

/**
 Stimulus position, speed, and spatial frame data should all be published at the
 same rate, i.e. 60hz. But, in reality, they may not be published at exactly that rate, and they
 certainly aren't published at exactly the same time. So the recorder records the streams separately
 and relies on the FrameInterpolator to create a single, interpolated timeline. It does this by using the
 spatial transform frames as the reference point and then mapping position and speed frames to each
 transform frame using linear interpolation.
 */
func interpolate_frames(_ frames: ExamFrames) -> [InterpolatedFrame] {
    // Use spatial transforms as the reference timeline
    let spatial_frames = frames.spatial_transforms
    let positions = frames.stimulus_positions
    let speeds = frames.stimulus_speeds
    
    // If no spatial frames, return empty array
    if spatial_frames.isEmpty {
        return []
    }
    
    var interpolated_frames: [InterpolatedFrame] = []
    
    for spatial_frame in spatial_frames {
        let timestamp = spatial_frame.timestamp
        
        // Find the two position frames that bracket this timestamp
        let interpolated_position = interpolate_point_at_timestamp(
            timestamp: timestamp,
            values: positions
        )
        
        // Find the two speed frames that bracket this timestamp
        let interpolated_speed = interpolate_double_at_timestamp(
            timestamp: timestamp,
            values: speeds
        )
        
        // Create the interpolated frame
        let interpolated_frame = InterpolatedFrame(
            timestamp: timestamp,
            position: interpolated_position,
            speed: interpolated_speed,
            transforms: spatial_frame,
            wild_guess: spatial_frame.wild_guess
        )
        
        interpolated_frames.append(interpolated_frame)
    }
    
    return interpolated_frames
}

/**
 Helper function to interpolate a Point value at a given timestamp from a sorted array of timestamped values.
 Uses linear interpolation between the two closest timestamped values.
 */
private func interpolate_point_at_timestamp(
    timestamp: Date,
    values: [TimestampedValue<Point>]
) -> Point {
    // If no values, return zero point
    if values.isEmpty {
        return Point(x: 0, y: 0)
    }
    
    // If only one value, return it
    if values.count == 1 {
        return values[0].value
    }
    
    // Find the two values that bracket the timestamp
    var before_index: Int?
    var after_index: Int?
    
    for (index, value) in values.enumerated() {
        if value.timestamp <= timestamp {
            before_index = index
        } else {
            after_index = index
            break
        }
    }
    
    // Handle edge cases
    if before_index == nil {
        // Timestamp is before all values, use the first value
        return values[0].value
    }
    
    if after_index == nil {
        // Timestamp is after all values, use the last value
        return values[values.count - 1].value
    }
    
    // Perform linear interpolation
    let before_value = values[before_index!]
    let after_value = values[after_index!]
    
    let before_time = before_value.timestamp.timeIntervalSinceReferenceDate
    let after_time = after_value.timestamp.timeIntervalSinceReferenceDate
    let target_time = timestamp.timeIntervalSinceReferenceDate
    
    let time_ratio = (target_time - before_time) / (after_time - before_time)
    
    // Linear interpolation for x and y coordinates
    let interpolated_x = before_value.value.x + time_ratio * (after_value.value.x - before_value.value.x)
    let interpolated_y = before_value.value.y + time_ratio * (after_value.value.y - before_value.value.y)
    
    return Point(x: interpolated_x, y: interpolated_y)
}

/**
 Helper function to interpolate a Double value at a given timestamp from a sorted array of timestamped values.
 Uses linear interpolation between the two closest timestamped values.
 */
private func interpolate_double_at_timestamp(
    timestamp: Date,
    values: [TimestampedValue<Double>]
) -> Double {
    // If no values, return zero
    if values.isEmpty {
        return 0.0
    }
    
    // If only one value, return it
    if values.count == 1 {
        return values[0].value
    }
    
    // Find the two values that bracket the timestamp
    var before_index: Int?
    var after_index: Int?
    
    for (index, value) in values.enumerated() {
        if value.timestamp <= timestamp {
            before_index = index
        } else {
            after_index = index
            break
        }
    }
    
    // Handle edge cases
    if before_index == nil {
        // Timestamp is before all values, use the first value
        return values[0].value
    }
    
    if after_index == nil {
        // Timestamp is after all values, use the last value
        return values[values.count - 1].value
    }
    
    // Perform linear interpolation
    let before_value = values[before_index!]
    let after_value = values[after_index!]
    
    let before_time = before_value.timestamp.timeIntervalSinceReferenceDate
    let after_time = after_value.timestamp.timeIntervalSinceReferenceDate
    let target_time = timestamp.timeIntervalSinceReferenceDate
    
    let time_ratio = (target_time - before_time) / (after_time - before_time)
    
    // Linear interpolation
    return before_value.value + time_ratio * (after_value.value - before_value.value)
}
