import SwiftUI
import AudioKit
import SoundpipeAudioKit
import AudioKitEX

protocol HasAmplitude {
    var amplitude: AUValue { get set }
}

struct PanVolumeNode<N: Node & HasAmplitude> {
    var node: N
    let panner: Panner

    init(_ node: N, volume: AUValue = 0, pan: AUValue = 0) {
        self.node = node
        self.panner = Panner(node)
        self.volume = volume
        self.pan = pan

        self.node.amplitude = volume
        self.panner.pan = pan
    }

    var volume: AUValue {
        didSet {
            node.amplitude = volume
        }
    }

    var pan: AUValue {
        didSet {
            panner.pan = pan
        }
    }
}

extension PinkNoise: HasAmplitude {}
extension WhiteNoise: HasAmplitude {}
extension BrownianNoise: HasAmplitude {}

@Observable
final class NoiseConductor {
    var isPlaying = false {
        didSet {
            if isPlaying {
                start()
            } else {
                stop()
            }
        }
    }

    var autoPan = false {
        didSet {
            if autoPan {
                enableAutoPan()
            } else {
                disableAutoPan()
            }
        }
    }
    var autoPanRate: AUValue = 1

    var pinkNoise = PanVolumeNode(PinkNoise())
    var whiteNoise = PanVolumeNode(WhiteNoise())
    var brownNoise = PanVolumeNode(BrownianNoise())

    var reverb: Reverb
    var stereoFieldLimiter: StereoFieldLimiter

    var engine = AudioEngine()
    let mixer = Mixer()

    init() {
        let stereoFieldLimiter = StereoFieldLimiter(mixer)
        reverb = Reverb(stereoFieldLimiter)
        self.stereoFieldLimiter = stereoFieldLimiter

        mixer.addInput(pinkNoise.panner)
        mixer.addInput(whiteNoise.panner)
        mixer.addInput(brownNoise.panner)

        engine.output = reverb

        configureDefaults()
    }

    private func configureDefaults() {
        reverb.dryWetMix = 0.1
        stereoFieldLimiter.amount = 1
    }

    private func start() {
        pinkNoise.node.start()
        whiteNoise.node.start()
        brownNoise.node.start()

        try! engine.start()
    }

    private func stop() {
        engine.stop()
        autoPan = false
    }

    private var autoPanTimer: Timer?

    func enableAutoPan(depth: Float = 1) {
        var phase: Float = 0

        autoPanTimer?.invalidate()
        autoPanTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self else { return }

            phase += 0.01 * autoPanRate
            pinkNoise.pan = sin(phase) * depth
            whiteNoise.pan = sin(phase + 2.0) * depth
            brownNoise.pan = sin(phase + 4.0) * depth
        }
    }

    func disableAutoPan() {
        autoPanTimer?.invalidate()
        autoPanTimer = nil
    }
}


struct AmbientNoiseView: View {
@State var conductor = NoiseConductor()

    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Button(action: {
                        conductor.isPlaying.toggle()
                    }) {
                        Image(systemName: conductor.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 20, height: 20)
                            .padding(4)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        conductor.autoPan.toggle()
                    }) {
                        Image(systemName: conductor.autoPan ? "arrow.trianglehead.2.clockwise.rotate.90.circle.fill" : "arrow.trianglehead.2.clockwise.rotate.90.circle")
                            .font(.title)
                            .frame(width: 20, height: 20)
                            .padding(4)
                    }
                    .buttonStyle(.borderedProminent)
                }
                NoiseControlsView(conductor: conductor)


                GroupBox {
                    SliderView(
                        title: "Stereo Width",
                        value:
                            Binding(
                                get: { 1 - conductor.stereoFieldLimiter.amount },
                                set: { conductor.stereoFieldLimiter.amount = 1 - $0 }
                            ),
                        range: 0...1
                    )

                    SliderView(title: "Reverb", value: $conductor.reverb.dryWetMix, range: 0...1)
                    SliderView(title: "Autopan Rate", value: $conductor.autoPanRate, range: 0...10)
                }
            }
            .padding()
        }
    }
}

struct NoiseControlsView: View {
    @Bindable var conductor: NoiseConductor

    var body: some View {
        GroupBox(label: Text("Noise Controls")) {
            VStack {
                SliderView(title: "Pink Noise", value: $conductor.pinkNoise.volume, range: 0...1)
                SliderView(title: "Pink Pan", value: $conductor.pinkNoise.pan, range: -1...1)

                SliderView(title: "White Noise", value: $conductor.whiteNoise.volume, range: 0...1)
                SliderView(title: "White Pan", value: $conductor.whiteNoise.pan, range: -1...1)

                SliderView(title: "Brown Noise", value: $conductor.brownNoise.volume, range: 0...1)
                SliderView(title: "Brown Pan", value: $conductor.brownNoise.pan, range: -1...1)
            }
        }
    }
}

struct SliderView: View {
    var title: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .frame(width: 40, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var value: Float = 0.5
    SliderView(title: "Test", value: $value, range: 0...1)
        .padding()
}

#Preview {
    NavigationStack {
        AmbientNoiseView()
    }
}
