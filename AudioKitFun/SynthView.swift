import AudioKit
import AudioKitEX
import AudioKitUI
import Controls
import SoundpipeAudioKit
import SwiftUI

@Observable
final class Conductor {

    var frequency: AUValue = 100 {
        didSet {
            updateFrequencies()
        }
    }

    var engine: AudioEngine

    // oscillators
    var baseOscillator: DynamicOscillator
    var octaveUpOscillator: DynamicOscillator
    var detunedOscillator: DynamicOscillator

    var octaveUpMultiplier: AUValue = 0 {
        didSet {
            octaveUpOscillator.amplitude = baseOscillator.amplitude * (octaveUpMultiplier / 100.0)
        }
    }
    var detunedMultiplier: AUValue = 0 {
        didSet {
            detunedOscillator.amplitude = baseOscillator.amplitude * (detunedMultiplier / 100.0)
        }
    }

    var mixer: Mixer
    var mainFader: Fader

    init() {
        engine = AudioEngine()

        baseOscillator = DynamicOscillator(waveform: Table(.sine))
        octaveUpOscillator = DynamicOscillator(waveform: Table(.sine))
        detunedOscillator = DynamicOscillator(waveform: Table(.sine))

        let mixer = Mixer()
        self.mixer = mixer

        mainFader = Fader(mixer)
        mixer.addInput(baseOscillator)
        mixer.addInput(octaveUpOscillator)
        mixer.addInput(detunedOscillator)

        let reverb = CostelloReverb(
            mainFader,
            balance: 0.4,
            feedback: 0.7,
            cutoffFrequency: 3000
        )

        mixer.volume = 0.75

        engine.output = reverb

        baseOscillator.amplitude = 0.3
        octaveUpOscillator.amplitude = 0
        detunedOscillator.amplitude = 0
        //        octaveUpOscillator.amplitude = baseOscillator.amplitude * 0.5
        //        detunedOscillator.amplitude = baseOscillator.amplitude * 0.6

        if isMuted {
            mainFader.gain = 0
        }

        updateFrequencies()
    }

    var isMuted = true {
        didSet {
            mainFader.$leftGain.ramp(to: isMuted ? 0 : 1, duration: 0.2)
            mainFader.$rightGain.ramp(to: isMuted ? 0 : 1, duration: 0.2)
        }
    }

    private func updateFrequencies() {
        baseOscillator.frequency = frequency
        octaveUpOscillator.frequency = frequency * 2

        let centsInOctave = 1200
        let detunedCents = 7
        let detunedFrequency = frequency * pow(2.0, AUValue(detunedCents) / AUValue(centsInOctave))
        detunedOscillator.frequency = detunedFrequency
    }

    private func updateWaveTables() {
        baseOscillator.setWaveform(Table(waveType.tableType))
        octaveUpOscillator.setWaveform(Table(waveType.tableType))
        detunedOscillator.setWaveform(Table(waveType.tableType))
    }

    func setupAudio() {
        try! engine.start()
    }

    func start() {
        baseOscillator.start()
        octaveUpOscillator.start()
        detunedOscillator.start()
    }

    func stop() {
        baseOscillator.stop()
        octaveUpOscillator.stop()
        detunedOscillator.stop()
    }

    var waveType: WaveType = .sine {
        didSet {
            updateWaveTables()
        }
    }

    enum WaveType: Int {
        case sine
        case square
        case sawtooth
        case triangle

        var tableType: TableType {
            switch self {
            case .sine: return .sine
            case .square: return .square
            case .sawtooth: return .sawtooth
            case .triangle: return .triangle
            }
        }
    }
}

struct SynthView: View {
    @State var conductor = Conductor()

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                Button("Start", systemImage: "play.fill") {
                    conductor.start()
                }

                Button("Stop", systemImage: "stop.fill") {
                    conductor.stop()
                }

                Button(
                    "Mute", systemImage: conductor.isMuted ? "speaker.slash.fill" : "speaker.fill"
                ) {
                    conductor.isMuted.toggle()
                }
            }
            .buttonStyle(.bordered)
            .padding()

            NodeOutputView(
                conductor.mixer,
                color: .cyan,
                backgroundColor: Color(red: 0, green: 0.05, blue: 0.15)
            )
            .frame(height: 200)

            Picker("Wave Type", selection: $conductor.waveType) {
                Text("Sine").tag(Conductor.WaveType.sine)
                Text("Square").tag(Conductor.WaveType.square)
                Text("Sawtooth").tag(Conductor.WaveType.sawtooth)
                Text("Triangle").tag(Conductor.WaveType.triangle)
            }
            .pickerStyle(.segmented)
            .padding()

            VStack(alignment: .leading) {
                HStack {
                    Text("Base Frequency")
                    Spacer()
                    Text("\(conductor.frequency, specifier: "%.2f") Hz")
                        .font(.body.monospacedDigit())
                        .bold()
                }
                Slider(value: $conductor.frequency, in: 20...1500)
            }
            .padding()

            HStack(spacing: 80) {
                VStack {
                    ArcKnob(
                        "oct",
                        value: $conductor.octaveUpMultiplier,
                        range: 0...100
                    )
                    .foregroundColor(.accentColor)
                    .backgroundColor(.accentColor.opacity(0.3))
                    .frame(width: 80, height: 80)

                    Text("\(conductor.octaveUpOscillator.frequency, specifier: "%.2f") Hz")
                        .font(.body.monospacedDigit())
                }

                VStack {
                    ArcKnob(
                        "det",
                        value: $conductor.detunedMultiplier,
                        range: 0...100
                    )
                    .foregroundColor(.accentColor)
                    .backgroundColor(.accentColor.opacity(0.3))
                    .frame(width: 80, height: 80)

                    Text("\(conductor.detunedOscillator.frequency, specifier: "%.2f") Hz")
                        .font(.body.monospacedDigit())
                }
            }

            Spacer()
        }
        .navigationTitle("Monophonic Synth")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            conductor.setupAudio()
        }
        .onDisappear {
            conductor.stop()
        }
    }
}

#Preview {
    NavigationStack {
        SynthView()
    }
}
