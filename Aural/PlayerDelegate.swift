import Cocoa

/*
 Concrete implementation of a middleman/facade between AppDelegate (UI) and Player. Accepts all requests originating from AppDelegate, converts/marshals them into lower-level requests suitable for Player, and forwards them to Player. Also, notifies AppDelegate when important events (such as playback completion) have occurred in Player.
 
 See AuralPlayerDelegate, AuralSoundTuningDelegate, and EventSubscriber protocols to learn more about the public functions implemented here.
 */
class PlayerDelegate: AuralPlayerDelegate, PlaybackControl, EventSubscriber {
    
    private var preferences: Preferences
    
    // The actual audio player
    private var player: AuralPlayer
    
    // The current player playlist
    private var playlist: PlaybackSequenceAccessor
    
    // Currently playing track
    private var playingTrack: IndexedTrack?
    
    // Serial queue for track prep tasks (to prevent concurrent prepping of the same track which could cause contention and is unnecessary to begin with)
    private var trackPrepQueue: OperationQueue
    
    // See PlaybackState
    private var playbackState: PlaybackState = .noTrack
    
    init(_ player: Player, _ appState: AppState, _ playlist: Playlist) {
        
        self.player = player
        self.playlist = playlist
        self.appState = appState
        
        self.trackPrepQueue = OperationQueue()
        trackPrepQueue.underlyingQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        trackPrepQueue.maxConcurrentOperationCount = 1
        
        EventRegistry.subscribe(EventType.playbackCompleted, subscriber: self, dispatchQueue: DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive))
    }
    
    func appLoaded() -> UIAppState {
        
        if (preferences.playlistOnStartup == .rememberFromLastAppLaunch) {
            EventRegistry.publishEvent(.startedAddingTracks, StartedAddingTracksEvent.instance)
            loadPlaylistFromSavedState()
        }
        
        return UIAppState(appState, preferences)
    }
    
    func autoplay() {
        
        DispatchQueue.main.async {
            
            do {
                
                try self.continuePlaying()
                
            } catch let error as Error {
                
                if (error is InvalidTrackError) {
                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
                }
            }
            
            // Notify the UI that a track has started playing
            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(self.playingTrack))
        }
    }
    
    func autoplay(_ trackIndex: Int) {
        
        DispatchQueue.main.async {
            
            do {
                try self.play(trackIndex)
                
            } catch let error as Error {
                
                if (error is InvalidTrackError) {
                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
                }
            }
            
            // Notify the UI that a track has started playing
            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(self.playingTrack))
        }
    }
    
    func getMoreInfo() -> IndexedTrack? {
        
        if (playingTrack == nil) {
            return nil
        }
        
        TrackIO.loadDetailedTrackInfo(playingTrack!.track!)
        return playingTrack
    }
    
    func togglePlayPause() throws -> (playbackState: PlaybackState, playingTrack: IndexedTrack?, trackChanged: Bool) {
        
        var trackChanged = false
        
        // Determine current state of player, to then toggle it
        switch playbackState {
            
        case .noTrack: try continuePlaying()
        if (playingTrack != nil) {
            trackChanged = true
        }
            
        case .paused: resume()
            
        case .playing: pause()
    
        }
        
        return (playbackState, playingTrack, trackChanged)
    }

    // Assume valid index
    func play(_ index: Int) throws -> IndexedTrack {
        
        let track = playlist.selectTrackAt(index)!
        try play(track)
        
        return playingTrack!
    }
    
    func continuePlaying() throws -> IndexedTrack? {
        try play(playlist.continuePlaying())
        return playingTrack
    }

    func nextTrack() throws -> IndexedTrack? {
    
        let nextTrack = playlist.next()
        if (nextTrack != nil) {
            try play(nextTrack)
        }
        
        return nextTrack
    }
    
    func previousTrack() throws -> IndexedTrack? {
        
        let prevTrack = playlist.previous()
        if (prevTrack != nil) {
            try play(prevTrack)
        }
        
        return prevTrack
    }
    
    private func play(_ track: IndexedTrack?) throws {
        
        // Stop if currently playing
        if (playbackState == .paused || playbackState == .playing) {
            stopPlayback()
        }
        
        playingTrack = track
        if (track != nil) {
            
            let session = PlaybackSession.start(track!)
            
            let actualTrack = track!.track!
            TrackIO.prepareForPlayback(actualTrack)
            
            if (actualTrack.preparationFailed) {
                throw actualTrack.preparationError!
            }
            
            player.play(session)
            playbackState = .playing
            
            // Prepare next possible tracks for playback
            prepareNextTracksForPlayback()
        }
    }
    
    // Computes which tracks are likely to play next (based on the playback sequence and user actions), and eagerly loads metadata for those tracks in preparation for their future playback. This significantly speeds up playback start time when the track is actually played back.
    private func prepareNextTracksForPlayback() {
        
        // Set of all tracks that need to be prepped
        let nextTracksSet = NSMutableSet()
        
        // The three possible tracks that could play next
        let peekContinue = self.playlist.peekContinuePlaying()?.track
        let peekNext = self.playlist.peekNext()?.track
        let peekPrevious = self.playlist.peekPrevious()?.track
        
        // Add each of the three tracks to the set of tracks to be prepped, as long as they're non-nil and not equal to the playing track (which has already been prepped, since it is playing)
        if (peekContinue != nil && playingTrack?.track !== peekContinue) {
            nextTracksSet.add(peekContinue!)
        }
        
        if (peekNext != nil) {
            nextTracksSet.add(peekNext!)
        }
        
        if (peekPrevious != nil) {
            nextTracksSet.add(peekPrevious!)
        }
        
        if (nextTracksSet.count > 0) {
            
            for _track in nextTracksSet {
                
                let track = _track as! Track
                
                // If track has not already been prepped, add a serial async task (to avoid concurrent prepping of the same track by two threads) to the trackPrepQueue
                
                // Async execution is important here, because reading from disk could be expensive and this info is not needed immediately.
                if (!track.preparedForPlayback) {
                    
                    let prepOp = BlockOperation(block: {
                        TrackIO.prepareForPlayback(track)
                    })
                    
                    trackPrepQueue.addOperation(prepOp)
                }
            }
        }
    }
    
    private func pause() {
        player.pause()
        playbackState = .paused
    }
    
    private func resume() {
        player.resume()
        playbackState = .playing
    }
    
    func getPlaybackState() -> PlaybackState {
        return playbackState
    }
    
    func getSeekSecondsAndPercentage() -> (seconds: Double, percentage: Double) {
        
        let seconds = playingTrack != nil ? player.getSeekPosition() : 0
        let percentage = playingTrack != nil ? seconds * 100 / playingTrack!.track!.duration! : 0
        
        return (seconds, percentage)
    }
    
    func seekForward() {
        
        if (playbackState != .playing) {
            return
        }
        
        // Calculate the new start position
        let curPosn = player.getSeekPosition()
        let trackDuration = playingTrack!.track!.duration!
        let newPosn = min(trackDuration, curPosn + Double(preferences.seekLength))
        
        // If this seek takes the track to its end, stop playback and proceed to the next track
        if (newPosn < trackDuration) {
            let session = PlaybackSession.start(playingTrack!)
            player.seekToTime(session, newPosn)
        } else {
            trackPlaybackCompleted()
        }
    }
    
    func seekBackward() {
        
        if (playbackState != .playing) {
            return
        }
        
        // Calculate the new start position
        let curPosn = player.getSeekPosition()
        let newPosn = max(0, curPosn - Double(preferences.seekLength))
        
        let session = PlaybackSession.start(playingTrack!)
        player.seekToTime(session, newPosn)
    }
    
    func seekToPercentage(_ percentage: Double) {
        
        if (playbackState != .playing) {
            return
        }
        
        // Calculate the new start position
        let newPosn = percentage * playingTrack!.track!.duration! / 100
        let trackDuration = playingTrack!.track!.duration!
        
        // If this seek takes the track to its end, stop playback and proceed to the next track
        if (newPosn < trackDuration) {
            let session = PlaybackSession.start(playingTrack!)
            player.seekToTime(session, newPosn)
        } else {
            trackPlaybackCompleted()
        }
    }
    
    // Returns the index of the currently playing track in the playlist
    func getPlayingTrack() -> IndexedTrack? {
        return playlist.getPlayingTrack()
    }
    
    func getVolume() -> Float {
        return round(player.getVolume() * AppConstants.volumeConversion_playerToUI)
    }
    
    func setVolume(_ volumePercentage: Float) {
        player.setVolume(volumePercentage * AppConstants.volumeConversion_UIToPlayer)
    }
    
    func increaseVolume() -> Float {
        let curVolume = player.getVolume()
        let newVolume = min(1, curVolume + preferences.volumeDelta)
        player.setVolume(newVolume)
        return round(newVolume * AppConstants.volumeConversion_playerToUI)
    }
    
    func decreaseVolume() -> Float {
        let curVolume = player.getVolume()
        let newVolume = max(0, curVolume - preferences.volumeDelta)
        player.setVolume(newVolume)
        return round(newVolume * AppConstants.volumeConversion_playerToUI)
    }
    
    func toggleMute() -> Bool {
        
        let muted = isMuted()
        if muted {
            player.unmute()
        } else {
            player.mute()
        }
        
        return !muted
    }
    
    func isMuted() -> Bool {
        return player.isMuted()
    }
    
    func getBalance() -> Float {
        return round(player.getBalance() * AppConstants.panConversion_playerToUI)
    }
    
    func setBalance(_ balance: Float) {
        player.setBalance(balance * AppConstants.panConversion_UIToPlayer)
    }
    
    func panLeft() -> Float {
        
        let curBalance = player.getBalance()
        var newBalance = max(-1, curBalance - preferences.panDelta)
        
        // Snap to center
        if (curBalance > 0 && newBalance < 0) {
            newBalance = 0
        }
        
        player.setBalance(newBalance)
        
        return round(newBalance * AppConstants.panConversion_playerToUI)
    }
    
    func panRight() -> Float {
        
        let curBalance = player.getBalance()
        var newBalance = min(1, curBalance + preferences.panDelta)
        
        // Snap to center
        if (curBalance < 0 && newBalance > 0) {
            newBalance = 0
        }
        
        player.setBalance(newBalance)
        
        return round(newBalance * AppConstants.panConversion_playerToUI)
    }
    
    // Called when playback of the current track completes
    func consumeEvent(_ event: Event) {
        
        let _evt = event as! PlaybackCompletedEvent
        
        // Do not accept duplicate/old events
        if (PlaybackSession.isCurrent(_evt.session)) {
            trackPlaybackCompleted()
        }
    }
    
    private func trackPlaybackCompleted() {
        
        // Stop playback of the old track
        stopPlayback()
        
        // Continue the playback sequence
        do {
            try continuePlaying()
            
            playbackState = playingTrack != nil ? .playing : .noTrack
            
            // Notify the UI about this track change event
            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(playingTrack))
            
        } catch let error as Error {
            
            if (error is InvalidTrackError) {
                EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
            }
        }
    }
    
    private func stopPlayback() {
        PlaybackSession.endCurrent()
        player.stop()
        playbackState = .noTrack
        playingTrack = nil
    }
    
    func play(_ track: IndexedTrack, _ interruptPlayingTrack: Bool) {
        
        let shouldPlay: Bool = interruptPlayingTrack || playingTrack == nil
        
        if (shouldPlay) {
            
            do {
                play(track)
            } catch let error as Error {
                
                if (error is InvalidTrackError) {
                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
                }
            }
        }
    }
    
    func stop() {
        stopPlayback()
    }
    
    func appExiting(_ uiState: UIState) {
        
        player.tearDown()
        
        let playerState = player.getState()
        
        let playlistState = playlist.getState()
        
        let appState = AppState(uiState, playerState, playlistState)
        
        AppStateIO.save(appState)
    }
}

// Indicates current progress for an operation that adds tracks to the playlist
class TrackAddOperationProgress {
    
    var tracksAdded: Int
    var totalTracks: Int
    var errors: [InvalidTrackError]
    var autoplayed: Bool
    
    init(_ tracksAdded: Int, _ totalTracks: Int, _ errors: [InvalidTrackError], _ autoplayed: Bool) {
        self.tracksAdded = tracksAdded
        self.totalTracks = totalTracks
        self.errors = errors
        self.autoplayed = autoplayed
    }
}
