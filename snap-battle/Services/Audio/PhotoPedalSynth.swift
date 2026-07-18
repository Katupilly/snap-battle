import AVFoundation
import Foundation

enum PhotoPedalSynthStopReason: Equatable, Sendable {
    case requested
    case interruption
    case engineFailure
}

@MainActor
protocol PedalPlaying: AnyObject {
    var isPlaying: Bool { get }
    var stopHandler: ((PhotoPedalSynthStopReason) -> Void)? { get set }
    func play(_ pedal: PhotoPedal) throws
    func stop()
}

private final class PlaybackBuffer: @unchecked Sendable {
    let samples: [Float]; var position = 0
    init(samples: [Float]) { self.samples = samples }
}

@MainActor
final class PhotoPedalSynth: NSObject, PedalPlaying {
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private let distortion = AVAudioUnitDistortion()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private var source: AVAudioSourceNode?
    private var playback: PlaybackBuffer?
    private(set) var isPlaying = false
    var stopHandler: ((PhotoPedalSynthStopReason) -> Void)?

    override init() {
        super.init(); configureEngine()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    func play(_ pedal: PhotoPedal) throws {
        stop()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        try PedalPlaybackTiming.validate(pedal.sequence, sampleRate: format.sampleRate)
        applyEffect(pedal.effect, profile: pedal.sequence.soundProfile)
        let buffer = PlaybackBuffer(samples: Self.renderSequence(pedal.sequence, sampleRate: Int(format.sampleRate)))
        playback = buffer
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                let sample = buffer.position < buffer.samples.count ? buffer.samples[buffer.position] : 0
                buffer.position += 1
                for audioBuffer in buffers where audioBuffer.mData != nil { audioBuffer.mData!.assumingMemoryBound(to: Float.self)[frame] = sample }
            }
            return noErr
        }
        self.source = source
        engine.attach(source); engine.connect(source, to: reverb, format: format)
        do {
            try engine.start(); isPlaying = true
        } catch {
            stop(reason: .engineFailure)
            throw error
        }
    }

    func stop() {
        stop(reason: .requested)
    }

    private func stop(reason: PhotoPedalSynthStopReason) {
        let shouldNotify = isPlaying || reason == .engineFailure
        if let source { engine.disconnectNodeOutput(source); engine.detach(source) }
        source = nil; playback = nil; engine.stop(); isPlaying = false
        if shouldNotify { stopHandler?(reason) }
    }

    private func configureEngine() {
        engine.attach(reverb); engine.attach(distortion)
        engine.connect(reverb, to: distortion, format: format); engine.connect(distortion, to: engine.mainMixerNode, format: format)
    }

    private func applyEffect(_ effect: PedalEffect, profile: PedalSoundProfile) {
        let reverbPreset: AVAudioUnitReverbPreset
        switch profile.reverbPreset {
        case .smallRoom: reverbPreset = .smallRoom
        case .mediumRoom: reverbPreset = .mediumRoom
        case .cathedral: reverbPreset = .cathedral
        }
        reverb.loadFactoryPreset(reverbPreset)
        distortion.loadFactoryPreset(profile.distortionPreset == .drumsBitBrush ? .drumsBitBrush : .multiEcho1)
        reverb.wetDryMix = effect == .reverb ? Float(profile.reverbMix) : 0
        distortion.wetDryMix = effect == .distortion ? Float(profile.distortionMix) : 0
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, AVAudioSession.InterruptionType(rawValue: type) == .began else { return }
        stop(reason: .interruption)
    }

    private static func renderSequence(_ sequence: PedalSequence, sampleRate: Int) -> [Float] {
        let samplesPerStep = PedalPlaybackTiming.samplesPerStep(sequence: sequence, sampleRate: Double(sampleRate))
        let gateSamples = max(1, Int(Double(samplesPerStep) * sequence.soundProfile.gate))
        let wave = waveformTable(sequence.soundProfile.waveform, size: 512), envelope = envelopeTable(length: gateSamples)
        var output = [Float](repeating: 0, count: samplesPerStep * PedalSequence.steps)
        let notesByStep = Dictionary(grouping: sequence.notes, by: \.step)
        for step in 0 ..< PedalSequence.steps {
            for note in notesByStep[step] ?? [] {
                let frequency = 440.0 * pow(2, Double(note.midiNote - 69) / 12), phaseIncrement = frequency * Double(wave.count) / Double(sampleRate)
                for sample in 0 ..< gateSamples {
                    let phase = Int(Double(sample) * phaseIncrement) % wave.count
                    output[step * samplesPerStep + sample] += wave[phase] * envelope[sample] * note.velocity * 0.16
                }
            }
        }
        return output.map { max(-0.92, min(0.92, $0)) }
    }

    private static func waveformTable(_ waveform: PedalWaveform, size: Int) -> [Float] {
        switch waveform {
        case .square: (0 ..< size).map { $0 < size / 2 ? 1 : -1 }
        case .triangle: (0 ..< size).map { Float(1 - 4 * abs(Double($0) / Double(size) - 0.5)) }
        }
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
