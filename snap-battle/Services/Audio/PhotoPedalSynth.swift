import AVFoundation
import Foundation

private final class PlaybackBuffer: @unchecked Sendable {
    let samples: [Float]
    var position = 0
    init(samples: [Float]) { self.samples = samples }
}

@MainActor
final class PhotoPedalSynth: NSObject {
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private let distortion = AVAudioUnitDistortion()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private var source: AVAudioSourceNode?
    private var playback: PlaybackBuffer?
    private(set) var isPlaying = false

    override init() {
        super.init()
        configureEngine()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func play(_ sequence: PedalSequence, effect: PedalEffect) throws {
        stop()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        setEffect(effect)
        let buffer = PlaybackBuffer(samples: Self.renderSequence(sequence, sampleRate: Int(format.sampleRate)))
        playback = buffer
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                let sample = buffer.position < buffer.samples.count ? buffer.samples[buffer.position] : 0
                buffer.position += 1
                for audioBuffer in buffers {
                    guard let data = audioBuffer.mData else { continue }
                    data.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
        self.source = source
        engine.attach(source)
        engine.connect(source, to: reverb, format: format)
        try engine.start()
        isPlaying = true
    }

    func stop() {
        if let source { engine.disconnectNodeOutput(source); engine.detach(source) }
        source = nil
        playback = nil
        engine.stop()
        isPlaying = false
    }

    private func configureEngine() {
        reverb.loadFactoryPreset(.mediumHall)
        distortion.loadFactoryPreset(.multiDistortedSquared)
        engine.attach(reverb); engine.attach(distortion)
        engine.connect(reverb, to: distortion, format: format)
        engine.connect(distortion, to: engine.mainMixerNode, format: format)
    }

    private func setEffect(_ effect: PedalEffect) {
        reverb.wetDryMix = effect == .reverb ? 48 : 0
        distortion.wetDryMix = effect == .distortion ? 55 : 0
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: type) == .began else { return }
        stop()
    }

    private static func renderSequence(_ sequence: PedalSequence, sampleRate: Int) -> [Float] {
        let samplesPerStep = max(1, Int(Double(sampleRate) * 60 / Double(sequence.harmony.bpm) / 4))
        let totalSamples = samplesPerStep * PedalSequence.steps
        let wave = waveformTable(size: 512)
        let envelope = envelopeTable(length: samplesPerStep)
        var output = [Float](repeating: 0, count: totalSamples)
        let notesByStep = Dictionary(grouping: sequence.notes, by: \.step)
        for step in 0 ..< PedalSequence.steps {
            for note in notesByStep[step] ?? [] {
                let frequency = 440.0 * pow(2, Double(note.midiNote - 69) / 12)
                let phaseIncrement = frequency * Double(wave.count) / Double(sampleRate)
                for sample in 0 ..< samplesPerStep {
                    let phase = Int(Double(sample) * phaseIncrement) % wave.count
                    output[step * samplesPerStep + sample] += wave[phase] * envelope[sample] * note.velocity * 0.16
                }
            }
        }
        return output.map { max(-0.92, min(0.92, $0)) }
    }

    private static func waveformTable(size: Int) -> [Float] {
        (0 ..< size).map { $0 < size / 2 ? 1 : -1 }
    }

    private static func envelopeTable(length: Int) -> [Float] {
        let attack = max(1, Int(Double(length) * 0.08)), decay = max(1, Int(Double(length) * 0.16)), release = max(1, Int(Double(length) * 0.22))
        return (0 ..< length).map { index in
            if index < attack { return Float(index) / Float(attack) }
            if index < attack + decay { return 1 - Float(index - attack) / Float(decay) * 0.35 }
            if index >= length - release { return 0.65 * (1 - Float(index - (length - release)) / Float(release)) }
            return 0.65
        }
    }
}
