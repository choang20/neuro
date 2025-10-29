//
//  TestScaffold.swift
//  Neurocular
//
// 
//

import SwiftUI

struct TestScaffold<Stimulus: View>: View {
    enum LayoutStyle { case split, stacked }
    let title: String
    let instructionsText: String
    let recordingStatus: RecordingStatus
    let makeStimulus: () -> Stimulus
    let startTest: () -> Void
    let onFinish: () -> Void
    let layout: LayoutStyle

    @State private var hasStarted = false
    @State private var orientation = UIDevice.current.orientation

    var body: some View {
        GeometryReader { geo in
            if orientation == .portrait || orientation == .portraitUpsideDown {
                VStack(spacing: 16) {
                    Text("Please rotate your phone to landscape to begin.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Image(systemName: "iphone.landscape")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if layout == .split {
                    HStack(alignment: .top, spacing: 16) {
                        VStack {
                            Text(title)
                                .font(.title3)
                                .padding(.bottom, 8)
                            if !hasStarted {
                                Button("start") {
                                    hasStarted = true
                                    speak(instructionsText)
                                    startTest()
                                }
                                .padding(10)
                                .foregroundColor(.white)
                                .background(Color.green)
                                .clipShape(Circle())
                            } else {
                                makeStimulus()
                            }
                        }
                        .frame(width: geo.size.width * 0.62)

                        VStack(alignment: .trailing) {
                            HStack {
                                Spacer()
                                if case .Finished(_) = recordingStatus {
                                    Button("done") { onFinish() }
                                        .padding(12)
                                        .background(Color.yellow)
                                        .clipShape(Circle())
                                }
                            }
                            Text(instructionsText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                            Spacer()
                        }
                        .frame(width: min(geo.size.width * 0.38, 360))
                    }
                } else {
                    // stacked layout: title, stimulus, then instructions below
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(title)
                                .font(.title3)
                            Spacer()
                            if case .Finished(_) = recordingStatus {
                                Button("done") { onFinish() }
                                    .padding(12)
                                    .background(Color.yellow)
                                    .clipShape(Circle())
                            }
                        }
                        if !hasStarted {
                            Button("start") {
                                hasStarted = true
                                speak(instructionsText)
                                startTest()
                            }
                            .padding(10)
                            .foregroundColor(.white)
                            .background(Color.green)
                            .clipShape(Circle())
                        } else {
                            makeStimulus()
                        }
                        Text(instructionsText)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.trailing, 16)
                }
            }
        }
        .onRotate { orientation = $0 }
    }
}


