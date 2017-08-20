import Cocoa
import AVFoundation

class AudioGraph {
 
    let audioEngine: AVAudioEngine
    let mainMixer: AVAudioMixerNode
    
    // Audio graph nodes
    let playerNode: AVAudioPlayerNode
    let eqNode: ParametricEQNode
    let pitchNode: AVAudioUnitTimePitch
    let reverbNode: AVAudioUnitReverb
    let filterNode: MultiBandStopFilterNode
    let delayNode: AVAudioUnitDelay
    let timeNode: AVAudioUnitTimePitch
    let auxMixer: AVAudioMixerNode  // Used for conversions of sample rates / channel counts
    
    // Helper
    let audioEngineHelper: AudioEngineHelper
    
    let nodeForRecorderTap: AVAudioNode
    
    // Sets up the audio engine
    init() {
        
        playerNode = AVAudioPlayerNode()
        
        audioEngine = AVAudioEngine()
        mainMixer = audioEngine.mainMixerNode
        eqNode = ParametricEQNode()
        pitchNode = AVAudioUnitTimePitch()
        reverbNode = AVAudioUnitReverb()
        delayNode = AVAudioUnitDelay()
        filterNode = MultiBandStopFilterNode()
        timeNode = AVAudioUnitTimePitch()
        auxMixer = AVAudioMixerNode()
        nodeForRecorderTap = mainMixer
        
        audioEngineHelper = AudioEngineHelper(engine: audioEngine)
        
        audioEngineHelper.addNodes([playerNode, auxMixer, eqNode, filterNode, pitchNode, reverbNode, delayNode, timeNode])
        audioEngineHelper.connectNodes()
        audioEngineHelper.prepareAndStart()
        
//        loadState(AppState.defaults.playerState)
    }
    
    func reconnectPlayerNodeWithFormat(_ format: AVAudioFormat) {
        audioEngineHelper.reconnectNodes(playerNode, outputNode: auxMixer, format: format)
    }
}
