import Cocoa

/*
    Contract for an audio player that is responsible for actual execution of playback control requests (play/pause/next/previous track, etc)
*/
protocol AuralPlayer {
    
    // Initializes the player with state remembered from the last app execution
    func loadState(_ state: PlayerState)
    
    // Plays a track associated with a new playback session
    func play(_ playbackSession: PlaybackSession)
    
    // Pauses the currently playing track
    func pause()
    
    // Resumes playback of the currently playing track
    func resume()
    
    // Stops playback of the currently playing track, in preparation for playback of a new track. Releases all resources associated with the currently playing track.
    func stop()
    
    // Seeks to a certain time in the track for the given playback session
    func seekToTime(_ playbackSession: PlaybackSession, _ seconds: Double)
    
    // Gets the playback position (in seconds) of the currently playing track
    func getSeekPosition() -> Double
    
    // Retrieves the current player volume
    func getVolume() -> Float
    
    // Sets the player volume, specified as a value between 0 and 1
    func setVolume(_ volume: Float)
    
    // Retrieves the current L/R balance (aka pan)
    func getBalance() -> Float
    
    // Sets the L/R balance (aka pan), specified as a value between -1 (L) and 1 (R)
    func setBalance(_ balance: Float)
    
    // Mutes the player
    func mute()
    
    // Unmutes the player
    func unmute()
    
    // Determines whether the player is currently muted
    func isMuted() -> Bool
    
    // Encapsulates all current player state in an object and returns it. This is useful when persisting "remembered" player state prior to app shutdown
    func getState() -> PlayerState
    
    // Does anything that needs to be done before the app exits - releasing resources
    func tearDown()
}
