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

func speak(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    utterance.postUtteranceDelay = 0.0
    sharedSynthesizer.speak(utterance)
}

func speakQueued(_ phrases: [String], rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.95, preDelay: Double = 0.15) {
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
 Returns the desired target dot diameter in pixels. The clinical request is for
 approximately 1 degree visual angle at 60cm, which corresponds to ~10.5mm.
 The product requirement specified 8–9mm, so we clamp to that window.
 */
func targetDotDiameterPixels() -> CGFloat {
    let mmFromOneDegreeAt60cm: CGFloat = 2 * 600 * CGFloat(tan(Double.pi / 360.0)) / 1.0 // ≈ 10.47mm
    let mmClamped = min(max(mmFromOneDegreeAt60cm, 8.0), 9.0) // enforce 8–9mm window
    let inches = mmClamped / 25.4
    return inches * estimatedPPI()
}


