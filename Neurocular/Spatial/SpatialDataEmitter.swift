//
//  SpatialDataEmitter.swift
//  Neurocular
//
//  Created by Max Taggart on 5/27/25.
//

import Foundation
import UIKit
import simd
import ARKit
import Combine

enum SpatialFrameData {
    case NoFaceDetected
    case FaceDetected(FrameFaceData)
}

struct FrameFaceData {
    let transforms: Transforms
    let image: SendablePixelBuffer
    let wild_guess: Bool
    let timestamp: Date
}

/**
 The transforms for the head and eyes for each frame of the video capture
 */
struct Transforms: Codable, Equatable {
    var camera: SerializableMatrix4x4
    var head: SerializableMatrix4x4
    var left_eye: SerializableMatrix4x4
    var right_eye: SerializableMatrix4x4
}

/**
 CVPixelBuffer is not sendable, but it is made accessible to us on some background thread. So, to
 send it between threads without a warning we are wrapping it in this @unchecked Sendable type
 since we are only ever passing them into the buffer adapter.
 See [this forum post](https://forums.swift.org/t/sending-a-sendable-but-non-sendable-type/69318)
 */
struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

typealias SerializableMatrix4x4 = [[Float]]

extension SerializableMatrix4x4 {
    static func zeros() -> SerializableMatrix4x4{
        return [
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0]
        ]
    }
    
    static func from_simd_4x4(simd_matrix m: simd_float4x4) -> SerializableMatrix4x4 {
        return [
            [m[0, 0], m[0, 1], m[0, 2], m[0, 3]],
            [m[1, 0], m[1, 1], m[1, 2], m[1, 3]],
            [m[2, 0], m[2, 1], m[2, 2], m[2, 3]],
            [m[3, 0], m[3, 1], m[3, 2], m[3, 3]]
        ]
    }
    
    var horizontal_angle: Float {
        atan(self[2][0] / self[2][2]) * 180 / Float.pi
    }
    
    var vertical_angle: Float {
        atan(self[2][1] / self[2][2]) * 180 / Float.pi
    }
}



/*
Responsible for instantiating an ARKit session and then emitting face-position
information through its `.subject`. Face-position data can be in one of three
states:

1. no face has been detected since the ARKit session was instantiated.
2. ARKit detected a face, and it is currently in frame. Here are its spatial 
estimates.
3. ARKit detected a face, but it is no longer in frame. Here are the spatial 
estimates, but they should not be relied on.
*/
class SpatialDataEmitter {
    let subject = CurrentValueSubject<SpatialFrameData, Never>(.NoFaceDetected)
    private var ar_event_handler: AREventHandler!
    
    init() {
        ar_event_handler = AREventHandler(subject: subject)
        ar_event_handler.begin_capture()
    }
}

fileprivate class AREventHandler: NSObject {
    let subject: CurrentValueSubject<SpatialFrameData, Never>
    private var ar_session: ARSession!
    
    init(subject: CurrentValueSubject<SpatialFrameData, Never>) {
        self.subject = subject
    }
    
    func begin_capture() {
        // Check that face tracking is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking not supported")
        }
        ar_session = ARSession()
        ar_session.delegate = self
        ar_session.run(
            ARFaceTrackingConfiguration(),
            options: [.resetTracking, .removeExistingAnchors]
        )
    }
}

extension AREventHandler: ARSessionDelegate {
    /*
     Emit face anchor information if there is a face in the frame, otherwise emit a .NoFaceDetected
     */
    func session(_ session: ARSession, didUpdate frame: ARFrame){
        for anchor in frame.anchors {
            guard let face_anchor = anchor as? ARFaceAnchor else {
                continue
            }
            /*
             Note, as pointed out very helpfully by ChatGPT, once ARKit has created a face
             anchor it will not remove that anchor until the session ends, regardless of
             whether or not the face is still visible in the frame. And, even if the user's
             face is still in the frame, it may be obscured, and/or ARKit may have lost track
             of it momentarily and is therefore providing a less-than-reliable estimate of
             the face's postion. Luckily, at least, ARKit tells us whether it is making a
             wild guess by providing an `isTracked` property on the FaceAnchor. Which is true
             when ARKit is confident about the face's position, and false otherwise,
             including when the face is out of frame.
             */
            self.subject.send(.FaceDetected(
                FrameFaceData(
                    transforms: Transforms(
                        camera: SerializableMatrix4x4.from_simd_4x4(simd_matrix: frame.camera.transform),
                        head: SerializableMatrix4x4.from_simd_4x4(simd_matrix: face_anchor.transform),
                        left_eye: SerializableMatrix4x4.from_simd_4x4(simd_matrix: face_anchor.leftEyeTransform),
                        right_eye: SerializableMatrix4x4.from_simd_4x4(simd_matrix: face_anchor.rightEyeTransform)
                    ),
                    image: SendablePixelBuffer(buffer: frame.capturedImage),
                    wild_guess: !face_anchor.isTracked,
                    timestamp: Date()
                )
            ))
            return
        }
        // If execution reaches this point then no face anchor was detected
        self.subject.send(.NoFaceDetected)
    }
}





