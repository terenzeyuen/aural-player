/*
    Encapsulates all application state, with values that are marshaled into a format directly usable by the UI, based on user preferences.
 */

import Foundation

class UIAppState {
    
    var hidePlaylist: Bool
    var hideEffects: Bool
    
    var windowLocation: NSPoint
    
    var repeatMode: RepeatMode
    var shuffleMode: ShuffleMode
    
    var volume: Float
    var muted: Bool
    var balance: Float
    
    var eqGlobalGain: Float
    var eqBands: [Int: Float] = [Int: Float]()
    
    var pitchBypass: Bool
    var pitch: Float
    var pitchOverlap: Float
    
    var formattedPitch: String
    var formattedPitchOverlap: String
    
    var timeBypass: Bool
    var timeStretchRate: Float
    var timeOverlap: Float
    
    var formattedTimeStretchRate: String
    var formattedTimeOverlap: String
    
    var seekTimerInterval: Int
    
    var reverbBypass: Bool
    var reverbPreset: String
    var reverbAmount: Float
    
    var formattedReverbAmount: String
    
    var delayBypass: Bool
    var delayAmount: Float
    var delayTime: Double
    var delayFeedback: Float
    var delayLowPassCutoff: Float
    
    var formattedDelayAmount: String
    var formattedDelayTime: String
    var formattedDelayFeedback: String
    var formattedDelayLowPassCutoff: String
    
    var filterBypass: Bool
    var filterBassMin: Double
    var filterBassMax: Double
    var filterMidMin: Double
    var filterMidMax: Double
    var filterTrebleMin: Double
    var filterTrebleMax: Double
    
    var formattedFilterBassRange: String
    var formattedFilterMidRange: String
    var formattedFilterTrebleRange: String
    
    init(_ appState: AppState, _ preferences: Preferences) {
        
        if (preferences.viewOnStartup.option == .rememberFromLastAppLaunch) {
            
            self.hidePlaylist = !appState.uiState.showPlaylist
            self.hideEffects = !appState.uiState.showEffects
            
        } else {
            
            let viewType = preferences.viewOnStartup.viewType
            self.hidePlaylist = viewType == .effectsOnly || viewType == .compact
            self.hideEffects = viewType == .playlistOnly || viewType == .compact
        }
        
        if (preferences.windowLocationOnStartup.option == .rememberFromLastAppLaunch) {
            
            self.windowLocation = NSPoint(x: CGFloat(appState.uiState.windowLocationX), y: CGFloat(appState.uiState.windowLocationY))
            
        } else {
            
            let windowWidth = UIConstants.windowWidth
            var windowHeight: CGFloat
            
            let showPlaylist = !self.hidePlaylist
            let showEffects = !self.hideEffects
            
            if (showPlaylist && showEffects) {
                windowHeight = UIConstants.windowHeight_playlistAndEffects
            } else if (showPlaylist) {
                windowHeight = UIConstants.windowHeight_playlistOnly
            } else if (showEffects) {
                windowHeight = UIConstants.windowHeight_effectsOnly
            } else {
                windowHeight = UIConstants.windowHeight_compact
            }
        
            self.windowLocation = UIUtils.windowPositionRelativeToScreen(windowWidth, windowHeight, preferences.windowLocationOnStartup.windowLocation)
        }
        
        self.repeatMode = appState.playlistState.repeatMode
        self.shuffleMode = appState.playlistState.shuffleMode
        
        let audioGraphState = appState.audioGraphState
        
        if (preferences.volumeOnStartup == .rememberFromLastAppLaunch) {
            self.volume = round(audioGraphState.volume * AppConstants.volumeConversion_graphToUI)
        } else {
            self.volume = round(preferences.startupVolumeValue * AppConstants.volumeConversion_graphToUI)
        }
        
        self.muted = audioGraphState.muted
        self.balance = round(audioGraphState.balance * AppConstants.panConversion_graphToUI)
        
        self.eqGlobalGain = audioGraphState.eqGlobalGain
        for (freq,gain) in audioGraphState.eqBands {
            self.eqBands[freq] = gain
        }
        
        self.pitchBypass = audioGraphState.pitchBypass
        self.pitch = audioGraphState.pitch * AppConstants.pitchConversion_graphToUI
        self.pitchOverlap = audioGraphState.pitchOverlap
        
        self.formattedPitch = ValueFormatter.formatPitch(self.pitch)
        self.formattedPitchOverlap = ValueFormatter.formatOverlap(audioGraphState.pitchOverlap)
        
        self.timeBypass = audioGraphState.timeBypass
        self.timeStretchRate = audioGraphState.timeStretchRate
        self.timeOverlap = audioGraphState.timeOverlap
        
        self.formattedTimeStretchRate = ValueFormatter.formatTimeStretchRate(audioGraphState.timeStretchRate)
        self.formattedTimeOverlap = ValueFormatter.formatOverlap(audioGraphState.timeOverlap)
        
        self.seekTimerInterval = audioGraphState.timeBypass ? UIConstants.seekTimerIntervalMillis : Int(1000 / (2 * audioGraphState.timeStretchRate))
        
        self.reverbBypass = audioGraphState.reverbBypass
        self.reverbPreset = audioGraphState.reverbPreset.description
        self.reverbAmount = audioGraphState.reverbAmount
        
        self.formattedReverbAmount = ValueFormatter.formatReverbAmount(audioGraphState.reverbAmount)
        
        self.delayBypass = audioGraphState.delayBypass
        self.delayTime = audioGraphState.delayTime
        self.delayAmount = audioGraphState.delayAmount
        self.delayFeedback = audioGraphState.delayFeedback
        self.delayLowPassCutoff = audioGraphState.delayLowPassCutoff
        
        self.formattedDelayTime = ValueFormatter.formatDelayTime(audioGraphState.delayTime)
        self.formattedDelayAmount = ValueFormatter.formatDelayAmount(audioGraphState.delayAmount)
        self.formattedDelayFeedback = ValueFormatter.formatDelayFeedback(audioGraphState.delayFeedback)
        self.formattedDelayLowPassCutoff = ValueFormatter.formatDelayLowPassCutoff(audioGraphState.delayLowPassCutoff)
         
        self.filterBypass = audioGraphState.filterBypass
        self.filterBassMin = Double(audioGraphState.filterBassMin)
        self.filterBassMax = Double(audioGraphState.filterBassMax)
        self.filterMidMin = Double(audioGraphState.filterMidMin)
        self.filterMidMax = Double(audioGraphState.filterMidMax)
        self.filterTrebleMin = Double(audioGraphState.filterTrebleMin)
        self.filterTrebleMax = Double(audioGraphState.filterTrebleMax)
        
        self.formattedFilterBassRange = ValueFormatter.formatFilterFrequencyRange(audioGraphState.filterBassMin, audioGraphState.filterBassMax)
        self.formattedFilterMidRange = ValueFormatter.formatFilterFrequencyRange(audioGraphState.filterMidMin, audioGraphState.filterMidMax)
        self.formattedFilterTrebleRange = ValueFormatter.formatFilterFrequencyRange(audioGraphState.filterTrebleMin, audioGraphState.filterTrebleMax)
    }
}
