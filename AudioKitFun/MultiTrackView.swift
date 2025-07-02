import AVFoundation
import AudioKit
import AudioKitEX
import AudioKitUI
import SwiftUI

class AudioTrack {
    let name: String
    let player: AudioPlayer
    let fader: Fader
    let url: URL
    
    init(name: String, url: URL) throws {
        self.name = name
        self.url = url
        let file = try AVAudioFile(forReading: url)
        self.player = AudioPlayer(file: file)!
        player.volume = 0.2
        self.fader = Fader(player)
        self.fader.gain = 0.5
    }
}

@Observable
class MultiTrackEngine {
    private let engine = AudioEngine()
    private let mixer = Mixer()
    private(set) var tracks: [AudioTrack] = []
    
    var isPlaying = false
    var isLoaded = false
    var playbackProgress: Double = 0
    
    private var playStartTime: TimeInterval = 0
    private var pausedAt: TimeInterval = 0
    
    init() {
        engine.output = mixer
    }
    
    func loadTracks() {
        let trackFiles: [(filename: String, instrument: String)] = [
            ("syn_34.wav", "Synthesizer"),
            ("Audio 10_07.wav", "Lead Synth"),
            ("Audio 11_06.wav", "Pad"),
            ("bs_10.wav", "Bass")
        ]

        do {
            stop()
            tracks.removeAll()
            mixer.removeAllInputs()
            
            print("Loading tracks...")
            
            for (filename, instrument) in trackFiles {
                print("Loading [\(filename)]...")
                let url = Bundle.main.url(forResource: filename, withExtension: nil)!
                let track = try AudioTrack(name: instrument, url: url)
                tracks.append(track)
                mixer.addInput(track.fader)
            }
            print("Done loading tracks.")
            isLoaded = true
            
            try engine.start()
        } catch {
            print("Error loading tracks: \(error)")
        }
    }
    
    // MARK: - playback
    
    func stop() {
        for track in tracks {
            track.player.stop()
        }
    }
    
    func startSynchronizedPlayback() {
        guard isLoaded else { return }
        
        // Schedule all tracks to play at the same time
        let now = AVAudioTime.now()
        let sampleRate: Double = 44100.0
        let sampleTime = now.sampleTime + Int64(0.1 * sampleRate) // 4410
        let startTime = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)
        
        for track in tracks {
            track.player.play(from: pausedAt, at: startTime)
        }
        
        playStartTime = Date().timeIntervalSinceReferenceDate - pausedAt
        isPlaying = true
    }
    
    func pause() {
        pausedAt = Date().timeIntervalSinceReferenceDate - playStartTime
        for track in tracks {
            track.player.pause()
        }
        
        isPlaying = false
    }
    
    // MARK: - volume/mute
    
    func volume(for track: AudioTrack) -> Float {
        print(track.fader.gain)
        return Float(track.fader.gain)
    }
    
    func setVolume(for track: AudioTrack, to value: Float) {
        track.fader.gain = AUValue(value)
    }
    
    func toggleMute(for track: AudioTrack) {
        let fader = track.fader
        track.fader.gain = fader.gain > 0 ? 0 : 0.2
    }
    
    // MARK: - progress tracking
    
    var duration: TimeInterval {
        guard let firstTrack = tracks.first else { return 0 }
        return firstTrack.player.duration
    }
    
    func updateProgress() {
        guard isPlaying else { return }
        let duraton = self.duration
        guard duration > 0 else { return }
        
        let elapsedTime = Date().timeIntervalSinceReferenceDate - playStartTime
        playbackProgress = min(elapsedTime / duration, 1.0)
    }
}


struct MultiTrackView: View {
    @State private var engine = MultiTrackEngine()
    @State private var volumeValues: [Float] = []
    @State private var progressTimer: Timer?
    
    let trackColors: [Color] = [
        Color(red: 0.2, green: 0.6, blue: 1.0),    // Blue
        Color(red: 0.9, green: 0.3, blue: 0.3),    // Red
        Color(red: 0.3, green: 0.8, blue: 0.4),    // Green
        Color(red: 0.9, green: 0.6, blue: 0.2),    // Orange
        Color(red: 0.7, green: 0.3, blue: 0.9),    // Purple
        Color(red: 0.9, green: 0.8, blue: 0.2),    // Yellow
        Color(red: 0.3, green: 0.8, blue: 0.8),    // Cyan
        Color(red: 0.9, green: 0.4, blue: 0.6)     // Pink
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            transportControls
            
            if engine.isLoaded {
                tracks
            } else {
                Spacer()
                ProgressView("Loading Tracks...")
                Spacer()
            }
        }
        .navigationTitle("Multi-track Mixer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !engine.isLoaded {
                engine.loadTracks()
                volumeValues = engine.tracks.map { engine.volume(for: $0) }
            }
        }
        .onChange(of: engine.isPlaying) { _, isPlaying in
            if isPlaying {
                progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    engine.updateProgress()
                }
            } else {
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
        }
    }
    
    @ViewBuilder
    private var transportControls: some View {
        HStack(spacing: 30) {
            Button(action: {
                if engine.isPlaying {
                    engine.pause()
                } else {
                    engine.startSynchronizedPlayback()
                }
            }) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
            }
            .disabled(!engine.isLoaded)
            
            Button(action: {
                engine.stop()
            }) {
                Image(systemName: "stop.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
            }
            .disabled(!engine.isLoaded)
        }
        .padding()
    }
    
    @ViewBuilder
    private var tracks: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(engine.tracks.enumerated()), id: \.element.name) { (offset, track) in
                    ZStack {
                        let trackColor = trackColors[offset % trackColors.count]
                        trackColor.opacity(0.2)
                        
                        HStack {
                            // track name/controls
                            VStack(alignment: .leading, spacing: 8) {
                                Text(track.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(trackColor)
                                
                                HStack {
                                    // mute button
                                    Button(action: {
                                        engine.toggleMute(for: track)
                                        volumeValues[safe: offset] = engine.volume(for: track)
                                    }) {
                                        Text("M")
                                            .font(.system(size: 12, weight: .medium))
                                            .frame(width: 24, height: 24)
                                            .background(Color.black.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    
                                    volumeSlider(for: track, index: offset)
                                }
                            }
                            
                            waveform(for: track, color: trackColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(trackColor.opacity(0.5))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .overlay {
                GeometryReader { proxy in
                    let waveFormStartX: CGFloat = 130
                    Rectangle()
                        .fill(engine.isPlaying ? Color.red : Color.red.opacity(0.4))
                        .frame(width: 2)
                        .offset(x: waveFormStartX + (proxy.size.width - waveFormStartX) * engine.playbackProgress)
                }
            }
        }
    }
    
    @ViewBuilder
    private func waveform(for track: AudioTrack, color: Color) -> some View {
        AudioFileWaveform(url: track.url, rmsSamplesPerWindow: 512, color: color)
            .frame(height: 60)
            .background(
                Rectangle()
                    .fill(color.opacity(0.5))
                    .frame(height: 1)
            )
    }
    
    @ViewBuilder
    private func volumeSlider(for track: AudioTrack, index: Int) -> some View {
        VStack {
            // volume slider
            Slider(
                value: Binding(
                    get: { engine.volume(for: track) },
                    set: {
                        volumeValues[safe: index] = $0
                        engine.setVolume(for: track, to: $0)
                    }
                ),
                in: 0...1
            )
            .frame(width: 80)
            
            Text("\(Int((volumeValues[safe: index] ?? 0) * 100))%")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        get {
            guard index >= 0 && index < count else { return nil }
            
            return self[index]
        }
        set {
            guard index >= 0 && index < count, let newValue else { return }
            
            self[index] = newValue
        }
    }
}


#Preview {
    NavigationStack {
        MultiTrackView()
    }
}


