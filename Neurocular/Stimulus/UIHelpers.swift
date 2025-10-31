//
//  UIHelpers.swift
//  Neurocular
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI
import AVFoundation

// Our custom view modifier to track rotation and call our action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

// Use a single shared synthesizer so utterances are queued consistently.
fileprivate let sharedSynthesizer = AVSpeechSynthesizer()
fileprivate var audioSessionConfigured = false

func speak(_ text: String) {
    if !audioSessionConfigured {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .defaultToSpeaker])
        try? session.setActive(true, options: [])
        audioSessionConfigured = true
    }
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    utterance.postUtteranceDelay = 0.0
    sharedSynthesizer.speak(utterance)
}

func speakQueued(_ phrases: [String], rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.95, preDelay: Double = 0.15) {
    if !audioSessionConfigured {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .defaultToSpeaker])
        try? session.setActive(true, options: [])
        audioSessionConfigured = true
    }
    for phrase in phrases {
        let u = AVSpeechUtterance(string: phrase)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = rate
        u.preUtteranceDelay = preDelay
        sharedSynthesizer.speak(u)
    }
}

// MARK: - Target dot sizing helpers

func estimatedPPI() -> CGFloat {
    // iPhone 14/15 class devices ~460 ppi. Use as a safe default.
    return 460.0
}

/**
 Returns the target dot diameter in pixels sized to 8.5 mm (midpoint of 8–9 mm)
 to match the clinical request. This corresponds to ~0.8° at 60 cm.
 */
func targetDotDiameterPixels() -> CGFloat {
    let diameterMM: CGFloat = 8.5
    let inches = diameterMM / 25.4
    let pixels = inches * estimatedPPI()
    // Convert device pixels to SwiftUI points
    let scale = UIScreen.main.scale
    return pixels / scale
}


