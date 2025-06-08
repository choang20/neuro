////
////  VideoIO.swift
////  emphairmint
////
////  Created by Max Taggart on 2/4/25.
////
//
//import Foundation
//import AVFoundation
//
//enum VideoWriterError: Error {
//    case UnableToAddInput
//    case UnableToStartWriting(status: AVAssetWriter.Status, error: Error?)
//    case FlushBufferTimeout
//    case FlushBufferCancelled(_ error: Error)
//}
//
//struct VideoWriter {
//    let write_pixel_buffer: (_ buffer: CVPixelBuffer) -> Void
//    let finished: () async -> VideoWriterError?
//    let output_location: URL
//}
//
//func create_video_writer(
//    with_destination destination_url: URL,
//    first_buffer: CVPixelBuffer,
//    frame_rate: Int32 = 60
//) -> Result<VideoWriter, VideoWriterError> {
//    let video_width = NSNumber(value: Float(CVPixelBufferGetWidth(first_buffer)))
//    let video_height = NSNumber(value: Float(CVPixelBufferGetHeight(first_buffer)))
//    let avOutputSettings: [String: Any] = [
//        AVVideoCodecKey: AVVideoCodecType.h264,
//        AVVideoWidthKey: video_width,
//        AVVideoHeightKey: video_height
//    ]
//    let video_writer_input = AVAssetWriterInput(
//        mediaType: AVMediaType.video, outputSettings: avOutputSettings
//    )
//    // By default the video is captured and written as if the phone were on its
//    // side. So, to view the video upright we need to rotate it by 90 degrees
//    // clockwise. It also captures the mirrored image that is displayed to the
//    // user, not the image as seen from the camera. So we need to reflect it also.
//    video_writer_input.transform = CGAffineTransform(rotationAngle: -Double.pi / 2.0)
//        .scaledBy(x: -1, y: 1)
//    // This helps the video_writer_input be able to accept frames at a faster
//    // rate, hopefully. Even though we are using this we probably still need to
//    // maintain our own buffer in case this value is False when we go to append.
//    video_writer_input.expectsMediaDataInRealTime = true
//    let sourcePixelBufferAttributesDictionary = [
//        kCVPixelBufferPixelFormatTypeKey as String: NSNumber(
//            value: kCVPixelFormatType_32ARGB
//        ),
//        kCVPixelBufferWidthKey as String: video_width,
//        kCVPixelBufferHeightKey as String: video_height
//    ]
//    // Create the pixel buffer adapter and associate it with the
//    // AVAssetWriterInput (videoWriter). We need to use an adapter because
//    // it allows us to specify timing information for each video frame. If we
//    // had CMSampleBuffer objects (which contain both a pixel buffer and timing
//    // information) instead of CVPixelBuffer objects we could just append them
//    // directly to the AVAssetWriterInput object, but we don't.
//    let pixel_buffer_adaptor = AVAssetWriterInputPixelBufferAdaptor(
//        assetWriterInput: video_writer_input,
//        sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary
//    )
//    
//    let video_writer = create_asset_writer(
//        output_url: destination_url,
//        first_buffer: first_buffer,
//        output_settings: avOutputSettings
//    )
//    
//    if video_writer.canAdd(video_writer_input) {
//        video_writer.add(video_writer_input)
//    } else {
//        return .failure(VideoWriterError.UnableToAddInput)
//    }
//    if !video_writer.startWriting() {
//        return .failure(VideoWriterError.UnableToStartWriting(status: video_writer.status, error: video_writer.error))
//    }
//    video_writer.startSession(atSourceTime: CMTime.zero)
//    
//    var frame_count: Int64 = 0
//    var finished: Bool = false
//    var frame_buffer: [(buffer: CVPixelBuffer, presentation_time: CMTime)] = []
//    var frames_written = 0
//    
//    func write_buffer(buffer: CVPixelBuffer) {
//        /*
//         The idea here is that the AVAssetWriterInput object is sometimes
//         ready for input and sometimes not. If you try to append a buffer to
//         the input when it isn't ready it throws an exception and the program
//         crashes, it's very particular (why it can't just maintain an internal
//         buffer is a mystery to me). So, instead, we are maintaining our own
//         buffer and adding frames to that buffer if the input writer is unable
//         to accept input when this function is called. Then in `on_finished()` we
//         are flushing the buffer with a timeout so that we ensure all the frames
//         are written.
//         */
//        if finished {
//            fatalError("writer already finished")
//        }
//        // Always append the frame to the temporary buffer to keep the logic simple
//        frame_count += 1
//        let elapsed_time = CMTime(value: frame_count, timescale: frame_rate)
//        frame_buffer.append((buffer: buffer, presentation_time: elapsed_time))
//        if !video_writer_input.isReadyForMoreMediaData {
//            // The input is not ready for more frames, wait until the next call
//            return
//        }
//        while video_writer_input.isReadyForMoreMediaData && frame_buffer.count > 0 {
//            let (buffer, time) = frame_buffer.removeFirst()
//            pixel_buffer_adaptor.append(buffer, withPresentationTime: time)
//            frames_written += 1
//        }
//    }
//    
//    func on_finished() async -> VideoWriterError? {
//        /*
//         At this point there may still be frames in the frame_buffer. So,
//         this function flushes them as the input writer is able to receive them
//         with a 5 second timeout.
//         */
//        if finished {
//            return nil
//        }
//        // Make sure we always mark everything as finished
//        defer {
//            video_writer_input.markAsFinished()
//            Task { await video_writer.finishWriting() }
//            finished = true
//            // We need to exclude the video file from icloud backup
//            // here instead of in the storage manager because this file
//            // does the writing and there is no occasion in the Storage Manager
//            // to exclude it from backup.
//            StorageManager.exclude_from_icloud_backup(destination_url)
//        }
//        let timeout_seconds = 5.0
//        let start_time = Date()
//        while frame_buffer.count > 0 {
//            print("left in buffer: \(frame_buffer.count)")
//            print("written: \(frames_written)")
//            while video_writer_input.isReadyForMoreMediaData {
//                let (buffer, time) = frame_buffer.removeFirst()
//                pixel_buffer_adaptor.append(buffer, withPresentationTime: time)
//                frames_written += 1
//            }
//            // Check if we have timed out
//            if start_time.distance(to: Date()) > timeout_seconds {
//                return .FlushBufferTimeout
//            }
//            // Sleep and poll again
//            do {
//                try await Task.sleep(for: .milliseconds(50))
//            } catch {
//                return .FlushBufferCancelled(error)
//            }
//        }
//        return nil
//    }
//    
//    return .success(VideoWriter(
//        write_pixel_buffer: write_buffer,
//        finished: on_finished,
//        output_location: destination_url
//    ))
//}
//
//
//private func create_asset_writer(
//    output_url: URL, first_buffer: CVPixelBuffer, output_settings: [String: Any]
//) -> AVAssetWriter {
//    
//    guard let assetWriter = try? AVAssetWriter(
//        outputURL: output_url, fileType: AVFileType.mp4
//    ) else {
//        fatalError("AVAssetWriter() failed")
//    }
//    
//    guard assetWriter.canApply(
//        outputSettings: output_settings, forMediaType: AVMediaType.video
//    ) else {
//        fatalError("canApplyOutputSettings() failed")
//    }
//    
//    return assetWriter
//}
