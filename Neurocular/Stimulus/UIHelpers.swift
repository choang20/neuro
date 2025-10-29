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


