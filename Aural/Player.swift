/*
Wrapper around AVAudioEngine. Handles all audio-related operations ... playback, effects (DSP), etc. Receives calls from PlayerDelegate to modify settings and perform playback.
*/

import Cocoa
import AVFoundation

class Player: AuralPlayer, AuralSoundTuner, AuralRecorder {
    
    private static let singleton: Player = Player()
    
    static func instance() -> Player {
        return singleton
    }
    
    private let playerNode: AVAudioPlayerNode
    private let audioEngine: AVAudioEngine
    private let mainMixer: AVAudioMixerNode
    
    // Used for conversions of sample rates / channel counts
    private let auxMixer: AVAudioMixerNode
    
    // Audio graph nodes
    private let eqNode: ParametricEQNode
    private let pitchNode: AVAudioUnitTimePitch
    private let reverbNode: AVAudioUnitReverb
    private let filterNode: MultiBandStopFilterNode
    private let delayNode: AVAudioUnitDelay
    private let timeNode: AVAudioUnitTimePitch
    
    // Helper
    private let audioEngineHelper: AudioEngineHelper
    
    // Sound setting value holders
    private var playerVolume: Float
    private var muted: Bool
    private var reverbPreset: AVAudioUnitReverbPreset
    
    // Buffer allocation
    private var bufferManager: BufferManager
    
    private var recorder: Recorder
    
    // Current playback position (frame)
    private var startFrame: AVAudioFramePosition?
    
    // Sets up the audio engine
    init() {
        
        playerNode = AVAudioPlayerNode()

        playerVolume = AppDefaults.volume
        muted = AppDefaults.muted
        reverbPreset = AppDefaults.reverbPreset.avPreset
        
        audioEngine = AVAudioEngine()
        mainMixer = audioEngine.mainMixerNode
        eqNode = ParametricEQNode()
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
        delayNode = AVAudioUnitDelay()
        filterNode = MultiBandStopFilterNode()
        timeNode = AVAudioUnitTimePitch()
        auxMixer = AVAudioMixerNode()
        
        audioEngineHelper = AudioEngineHelper(engine: audioEngine)
        
        audioEngineHelper.addNodes([playerNode, auxMixer, eqNode, filterNode, pitchNode, reverbNode, delayNode, timeNode])
        audioEngineHelper.connectNodes()
        audioEngineHelper.prepareAndStart()
        
        bufferManager = BufferManager(playerNode: playerNode)
        recorder = Recorder(audioEngine)
        
        loadState(AppState.defaults.playerState)
    }
    
    func loadState(_ state: PlayerState) {
        
        playerVolume = state.volume
        muted = state.muted
        playerNode.volume = muted ? 0 : playerVolume
        playerNode.pan = state.balance
        
        // EQ
        eqNode.setBands(state.eqBands)
        eqNode.globalGain = state.eqGlobalGain
        
        // Pitch
        pitchNode.bypass = state.pitchBypass
        pitchNode.pitch = state.pitch
        pitchNode.overlap = state.pitchOverlap
        
        // Time
        timeNode.bypass = state.timeBypass
        timeNode.rate = state.timeStretchRate
        timeNode.overlap = state.timeOverlap
        
        // Reverb
        reverbNode.bypass = state.reverbBypass
        setReverb(state.reverbPreset)
        reverbNode.wetDryMix = state.reverbAmount
        
        // Delay
        delayNode.bypass = state.delayBypass
        delayNode.wetDryMix = state.delayAmount
        delayNode.delayTime = state.delayTime
        delayNode.feedback = state.delayFeedback
        delayNode.lowPassCutoff = state.delayLowPassCutoff
        
        // Filter
        filterNode.bypass = state.filterBypass
        filterNode.setFilterBassBand(state.filterBassMin, state.filterBassMax)
        filterNode.setFilterMidBand(state.filterMidMin, state.filterMidMax)
        filterNode.setFilterTrebleBand(state.filterTrebleMin, state.filterTrebleMax)
    }
    
    // Prepares the player to play a given track
    private func initPlayer(_ track: Track) {
        
        let format = track.avFile!.processingFormat
        
        // Disconnect player and reconnect with the file's processing format        
        audioEngineHelper.reconnectNodes(playerNode, outputNode: auxMixer, format: format)
    }
    
    func play(_ playbackSession: PlaybackSession) {
        
        startFrame = BufferManager.FRAME_ZERO
        initPlayer(playbackSession.track.track!)
        bufferManager.play(playbackSession)
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func resume() {
        playerNode.play()
    }
    
    // In seconds
    func getSeekPosition() -> Double {
        
        let nodeTime: AVAudioTime? = playerNode.lastRenderTime
        
        if (nodeTime != nil) {
            
            let playerTime: AVAudioTime? = playerNode.playerTime(forNodeTime: nodeTime!)
            
            if (playerTime != nil) {
                
                let lastFrame = (playerTime?.sampleTime)!
                let seconds: Double = Double(startFrame! + lastFrame) / (playerTime?.sampleRate)!
                
                return seconds
            }
        }
        
        // This should never happen (player is not playing)
        return 0
    }
    
    func getVolume() -> Float {
        return playerVolume
    }
    
    func setVolume(_ volume: Float) {
        playerVolume = volume
        if (!muted) {
            playerNode.volume = volume
        }
    }
    
    func mute() {
        playerNode.volume = 0
        muted = true
    }
    
    func unmute() {
        playerNode.volume = playerVolume
        muted = false
    }
    
    func isMuted() -> Bool {
        return muted
    }
    
    func getBalance() -> Float {
        return playerNode.pan
    }
    
    func setBalance(_ balance: Float) {
        playerNode.pan = balance
    }
    
    func setEQGlobalGain(_ gain: Float) {
        eqNode.globalGain = gain
    }
    
    func setEQBand(_ freq: Int , gain: Float) {
        eqNode.setBand(Float(freq), gain: gain)
    }
    
    func setEQBands(_ bands: [Int: Float]) {
        eqNode.setBands(bands)
    }
    
    func togglePitchBypass() -> Bool {
        let newState = !pitchNode.bypass
        pitchNode.bypass = newState
        return newState
    }
    
    func setPitch(_ pitch: Float) {
        pitchNode.pitch = pitch
    }
    
    func setPitchOverlap(_ overlap: Float) {
        pitchNode.overlap = overlap
    }
    
    func toggleTimeBypass() -> Bool {
        let newState = !timeNode.bypass
        timeNode.bypass = newState
        return newState
    }
    
    func isTimeBypass() -> Bool {
        return timeNode.bypass
    }
    
    func setTimeStretchRate(_ rate: Float) {
        timeNode.rate = rate
    }
    
    func setTimeOverlap(_ overlap: Float) {
        timeNode.overlap = overlap
    }
    
    func toggleReverbBypass() -> Bool {
        let newState = !reverbNode.bypass
        reverbNode.bypass = newState
        return newState
    }
    
    func setReverb(_ preset: ReverbPresets) {
        
        let avPreset: AVAudioUnitReverbPreset = preset.avPreset
        reverbPreset = avPreset
        reverbNode.loadFactoryPreset(reverbPreset)
    }
    
    func setReverbAmount(_ amount: Float) {
        reverbNode.wetDryMix = amount
    }
    
    func toggleDelayBypass() -> Bool {
        let newState = !delayNode.bypass
        delayNode.bypass = newState
        return newState
    }
    
    func setDelayAmount(_ amount: Float) {
        delayNode.wetDryMix = amount
    }
    
    func setDelayTime(_ time: Double) {
        delayNode.delayTime = time
    }
    
    func setDelayFeedback(_ percent: Float) {
        delayNode.feedback = percent
    }
    
    func setDelayLowPassCutoff(_ cutoff: Float) {
        delayNode.lowPassCutoff = cutoff
    }
    
    func toggleFilterBypass() -> Bool {
        let newState = !filterNode.bypass
        filterNode.bypass = newState
        return newState
    }
    
    func setFilterBassBand(_ min: Float, _ max: Float) {
        filterNode.setFilterBassBand(min, max)
    }
    
    func setFilterMidBand(_ min: Float, _ max: Float) {
        filterNode.setFilterMidBand(min, max)
    }
    
    func setFilterTrebleBand(_ min: Float, _ max: Float) {
        filterNode.setFilterTrebleBand(min, max)
    }
    
    func stop() {
        
        bufferManager.stop()
        playerNode.reset()

        // Clear sound tails from reverb and delay nodes, if they're active
        
        if (!delayNode.bypass) {
            delayNode.reset()
        }
        
        if (!reverbNode.bypass) {
            reverbNode.reset()
        }
        
        startFrame = nil
    }
    
    func seekToTime(_ playbackSession: PlaybackSession, _ seconds: Double) {
        startFrame = bufferManager.seekToTime(playbackSession, seconds)
    }
    
    func startRecording(_ format: RecordingFormat) {
        recorder.startRecording(format)
    }
    
    func stopRecording() {
        recorder.stopRecording()
    }
    
    func saveRecording(_ url: URL) {
        recorder.saveRecording(url)
    }
    
    func deleteRecording() {
        recorder.deleteRecording()
    }
    
    func getRecordingInfo() -> RecordingInfo? {
        return recorder.getRecordingInfo()
    }
    
    func getState() -> PlayerState {
        
        let state: PlayerState = PlayerState()
        
        // Volume and pan (balance)
        state.volume = playerVolume
        state.muted = muted
        state.balance = playerNode.pan
        
        // EQ
        for band in eqNode.bands {
            state.eqBands[Int(band.frequency)] = band.gain
        }
        state.eqGlobalGain = eqNode.globalGain
        
        // Pitch
        state.pitchBypass = pitchNode.bypass
        state.pitch = pitchNode.pitch
        state.pitchOverlap = pitchNode.overlap
        
        // Time
        state.timeBypass = timeNode.bypass
        state.timeStretchRate = timeNode.rate
        state.timeOverlap = timeNode.overlap
        
        // Reverb
        state.reverbBypass = reverbNode.bypass
        state.reverbPreset = ReverbPresets.mapFromAVPreset(reverbPreset)
        state.reverbAmount = reverbNode.wetDryMix
        
        // Delay
        state.delayBypass = delayNode.bypass
        state.delayAmount = delayNode.wetDryMix
        state.delayTime = delayNode.delayTime
        state.delayFeedback = delayNode.feedback
        state.delayLowPassCutoff = delayNode.lowPassCutoff
        
        // Filter
        state.filterBypass = filterNode.bypass
        let filterBands = filterNode.getBands()
        state.filterBassMin = filterBands.bass.min
        state.filterBassMax = filterBands.bass.max
        state.filterMidMin = filterBands.mid.min
        state.filterMidMax = filterBands.mid.max
        state.filterTrebleMin = filterBands.treble.min
        state.filterTrebleMax = filterBands.treble.max
        
        return state
    }
    
    func tearDown() {
        
        // Stop the player and release the audio engine resources
        stop()
        audioEngine.stop()
    }
}
