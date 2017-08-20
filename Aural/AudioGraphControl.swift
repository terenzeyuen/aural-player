import Foundation
import AVFoundation

protocol PlayerGraph {
    
    let playerNode: AVAudioPlayerNode
    
    func reconnectPlayerNodeWithFormat(_ format: AVAudioFormat)
}

protocol EffectsGraph {
    
    let eqNode: ParametricEQNode
    let pitchNode: AVAudioUnitTimePitch
    let reverbNode: AVAudioUnitReverb
    let filterNode: MultiBandStopFilterNode
    let delayNode: AVAudioUnitDelay
    let timeNode: AVAudioUnitTimePitch
}

protocol RecorderGraph {
    
    let nodeForRecorderTap: AVAudioNode
}
