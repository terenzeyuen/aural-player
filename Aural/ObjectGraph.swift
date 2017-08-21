/*
    Initializes the app, alongside AppDelegate. Takes care of configuring logging, loading all app state from disk, and constructing the critical high level objects in the app's object tree - player, playlist, playerDelegate.
 */

import Foundation

class ObjectGraph {
    
    // Object graph
    
    private static var playlistDelegate: PlaylistDelegate?
    
    private static var playerDelegate: PlayerDelegate?
    
    private static var audioGraphDelegate: AudioGraphDelegate?
    
    private static var recorderDelegate: RecorderDelegate?
    
    private static var playlist: Playlist?
    
    private static var player: Player?
    
    private static var audioGraph: AudioGraph?
    
    private static var recorder: Recorder?
    
    // Persistent state
    
    private static var appState: AppState?
    
    private static var uiAppState: UIAppState?
    
    private static var preferences: Preferences?
    
    // Hack to run initialization code only once
    private static var initialized: Bool = false
    
    private static func initialize() {
        
        if (initialized) {
            return
        }
        
        preferences = Preferences.instance()
        
        // Load saved player state from app config file, and initialize with that state
        appState = AppStateIO.load()
        
        if (appState == nil) {
            appState = AppState.defaults
        }
        
        uiAppState = UIAppState(appState!, preferences!)
        
        // Initialize playlist with playback sequence (repeat/shuffle) and track list
        
        let repeatMode = appState!.playlistState.repeatMode
        let shuffleMode = appState!.playlistState.shuffleMode
        
        playlist = Playlist(repeatMode, shuffleMode)
        
        audioGraph = AudioGraph(appState!.audioGraphState)
        if (preferences!.volumeOnStartup == .specific) {
            audioGraph?.setVolume(preferences!.startupVolumeValue)
        }
        
        player = Player(audioGraph!)
        
        recorder = Recorder(audioGraph!)
        
        playerDelegate = PlayerDelegate(player!, playlist!, preferences!)
        
        playlistDelegate = PlaylistDelegate(playlist!, playerDelegate!, [playerDelegate!], appState!.playlistState, preferences!)
        
        audioGraphDelegate = AudioGraphDelegate(audioGraph!, preferences!)
        
        recorderDelegate = RecorderDelegate(recorder!)
        
        initialized = true
    }
    
    static func getUIAppState() -> UIAppState {
        
        if (!initialized) {
            initialize()
        }
        
        return uiAppState!
    }
    
    static func getAppState() -> AppState {
        
        if (!initialized) {
            initialize()
        }
        
        return appState!
    }
    
    static func getPlayerDelegate() -> PlayerDelegateProtocol {
        
        if (!initialized) {
            initialize()
        }
        
        return playerDelegate!
    }
    
    static func getPlaylistDelegate() -> PlaylistDelegateProtocol {
        
        if (!initialized) {
            initialize()
        }
        
        return playlistDelegate!
    }
    
    static func getAudioGraphDelegate() -> AudioGraphDelegateProtocol {
        
        if (!initialized) {
            initialize()
        }
        
        return audioGraphDelegate!
    }
    
    static func getRecorderDelegate() -> RecorderDelegateProtocol {
        
        if (!initialized) {
            initialize()
        }
        
        return recorderDelegate!
    }
    
    static func getPlaylistAccessor() -> PlaylistAccessor {
        
        if (!initialized) {
            initialize()
        }
        
        return playlist!
    }
    
    static func getPreferences() -> Preferences {
        
        if (!initialized) {
            initialize()
        }
        
        return preferences!
    }
    
    static func tearDown() {
        AppStateIO.save(appState!)
    }
}
