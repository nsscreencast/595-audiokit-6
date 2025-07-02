//
//  AudioKitFunApp.swift
//  AudioKitFun
//
//  Created by Ben Scheirman on 4/2/25.
//

import AVFoundation
import SwiftUI

@main
struct AudioKitFunApp: App {
    init() {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try! AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
