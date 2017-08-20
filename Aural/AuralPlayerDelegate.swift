import Cocoa

/*
    Contract for a middleman/facade between AppDelegate (UI) and Player, responsible for all playback control requests (play/pause/next/previous track, etc) originating from AppDelegate
*/
protocol AuralPlayerDelegate {
    
    // Toggles between the play and pause states, as long as a file is available to play. Returns playback state information the UI can use to update itself following the operation.
    // Note - Throws an error if playback begins with a track that cannot be played back
    func togglePlayPause() throws -> (playbackState: PlaybackState, playingTrack: IndexedTrack?, trackChanged: Bool)
    
    // Plays the track at a given index in the player playlist. Returns complete track information for the track.
    // Note - Throws an error if the selected track cannot be played back
    func play(_ index: Int) throws -> IndexedTrack
    
    // Continues playback within the player playlist, according to repeat/shuffle modes. Called either before any tracks are played or after playback of a track has completed. Returns the new track, if any, that is selected for playback
    // Note - Throws an error if the track selected for playback cannot be played back
    func continuePlaying() throws -> IndexedTrack?
    
    // Plays (and returns) the next track, if there is one
    // Note - Throws an error if the next track cannot be played back
    func nextTrack() throws -> IndexedTrack?
    
    // Plays (and returns) the previous track, if there is one
    // Note - Throws an error if the previous track cannot be played back
    func previousTrack() throws -> IndexedTrack?
    
    // Returns the current playback state of the player. See PlaybackState for more details
    func getPlaybackState() -> PlaybackState
    
    // Returns the current playback position of the player, for the current track, in terms of seconds and percentage (of the duration)
    func getSeekSecondsAndPercentage() -> (seconds: Double, percentage: Double)
    
    // Seeks forward a few seconds, within the current track
    func seekForward()

    // Seeks backward a few seconds, within the current track
    func seekBackward()
    
    // Seeks to a specific percentage of the track duration, within the current track
    func seekToPercentage(_ percentage: Double)
    
    // Returns the currently playing track (with its index)
    func getPlayingTrack() -> IndexedTrack?
    
    // Returns the currently playing track, ensuring that detailed info is loaded in it. This is necessary due to lazy loading.
    func getMoreInfo() -> IndexedTrack?
    
    // Retrieves the current player volume
    func getVolume() -> Float
    
    // Sets the player volume, specified as a percentage (0 to 100)
    func setVolume(_ volumePercentage: Float)
    
    // Increases the player volume by a small increment. Returns the new player volume.
    func increaseVolume() -> Float
    
    // Decreases the player volume by a small decrement. Returns the new player volume.
    func decreaseVolume() -> Float
    
    // Toggles mute between on/off. Returns true if muted after method execution, false otherwise
    func toggleMute() -> Bool
    
    // Determines whether player is currently muted
    func isMuted() -> Bool
    
    // Retrieves the current L/R balance (aka pan)
    func getBalance() -> Float
    
    // Sets the L/R balance (aka pan), specified as a percentage value between -100 (L) and 100 (R)
    func setBalance(_ balancePercentage: Float)
    
    // Pans left by a small increment. Returns new balance value.
    func panLeft() -> Float
    
    // Pans right by a small increment. Returns new balance value.
    func panRight() -> Float
}
