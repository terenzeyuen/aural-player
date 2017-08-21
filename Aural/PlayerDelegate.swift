import Cocoa

/*
 Concrete implementation of a middleman/facade between AppDelegate (UI) and Player. Accepts all requests originating from AppDelegate, converts/marshals them into lower-level requests suitable for Player, and forwards them to Player. Also, notifies AppDelegate when important events (such as playback completion) have occurred in Player.
 
 See AuralPlayerDelegate, AuralSoundTuningDelegate, and EventSubscriber protocols to learn more about the public functions implemented here.
 */
class PlayerDelegate: PlayerDelegateProtocol, BasicPlayerDelegateProtocol, PlaylistChangeListener, EventSubscriber {
    
    // The actual audio player
    private var player: PlayerProtocol
    
    // The current player playlist
    private var playlist: PlaybackSequenceAccessor
    
    private var preferences: Preferences
    
    // Serial queue for track prep tasks (to prevent concurrent prepping of the same track which could cause contention and is unnecessary to begin with)
    private var trackPrepQueue: OperationQueue
    
    // See PlaybackState
    private var playbackState: PlaybackState = .noTrack
    
    init(_ player: PlayerProtocol, _ playlist: PlaybackSequenceAccessor, _ preferences: Preferences) {
        
        self.player = player
        self.playlist = playlist
        self.preferences = preferences
        
        self.trackPrepQueue = OperationQueue()
        trackPrepQueue.underlyingQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        trackPrepQueue.maxConcurrentOperationCount = 1
        
        EventRegistry.subscribe(EventType.playbackCompleted, subscriber: self, dispatchQueue: DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive))
    }
    
    func getMoreInfo() -> IndexedTrack? {
        
        let playingTrack = playlist.getPlayingTrack()
        if (playingTrack == nil) {
            return nil
        }
        
        TrackIO.loadDetailedTrackInfo(playingTrack!.track!)
        return playingTrack
    }
    
    func togglePlayPause() throws -> (playbackState: PlaybackState, playingTrack: IndexedTrack?, trackChanged: Bool) {
        
        var trackChanged = false
        var playingTrack: IndexedTrack?
        
        // Determine current state of player, to then toggle it
        switch playbackState {
            
        case .noTrack: let playingTrack = try continuePlaying()
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
        
        return track
    }
    
    func continuePlaying() throws -> IndexedTrack? {
        try play(playlist.subsequentTrack())
        return playlist.getPlayingTrack()
    }

    func nextTrack() throws -> IndexedTrack? {
    
        let nextTrack = playlist.nextTrack()
        if (nextTrack != nil) {
            try play(nextTrack)
        }
        
        return nextTrack
    }
    
    func previousTrack() throws -> IndexedTrack? {
        
        let prevTrack = playlist.previousTrack()
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
        let peekSubsequent = self.playlist.peekSubsequentTrack()?.track
        let peekNext = self.playlist.peekNextTrack()?.track
        let peekPrevious = self.playlist.peekPreviousTrack()?.track
        
        // Add each of the three tracks to the set of tracks to be prepped, as long as they're non-nil and not equal to the playing track (which has already been prepped, since it is playing)
        let playingTrack = playlist.getPlayingTrack()
        
        if (peekSubsequent != nil && playingTrack?.track !== peekSubsequent) {
            nextTracksSet.add(peekSubsequent!)
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
    
    func getSeekPosition() -> (seconds: Double, percentage: Double) {
        let playingTrack = playlist.getPlayingTrack()
        let seconds = playingTrack != nil ? player.getSeekPosition() : 0
        let percentage = playingTrack != nil ? seconds * 100 / playingTrack!.track!.duration! : 0
        
        return (seconds, percentage)
    }
    
    func seekForward() {
        
        if (playbackState != .playing) {
            return
        }
        
        // Calculate the new start position
        let playingTrack = playlist.getPlayingTrack()
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
        let playingTrack = playlist.getPlayingTrack()
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
        let playingTrack = playlist.getPlayingTrack()
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
    
    func handleTrackRemovedNotification(_ message: TrackRemovedNotification) {
        
        let index = message.removedTrackIndex
        let playingTrack = playlist.getPlayingTrack()
        
        if (playingTrack?.index == index) {
            
            stopPlayback()
        
            // Notify the UI about this track change event
            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(nil))
        }
    }
    
    // Called when playback of the current track completes
    func consumeEvent(_ event: Event) {
        
        let _evt = event as! PlaybackCompletedEvent
        
        // Do not accept duplicate/old events
        if (PlaybackSession.isCurrent(_evt.session)) {
            trackPlaybackCompleted()
        }
    }
    
    func consumeMessage(_ message: Message) {
        
        if (message is TrackRemovedNotification) {
            handleTrackRemovedNotification(message as! TrackRemovedNotification)
        }
    }
    
    private func trackPlaybackCompleted() {
        
        // Stop playback of the old track
        stopPlayback()
        
        // Continue the playback sequence
        do {
            let playingTrack = try continuePlaying()
            
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
    }
    
    // Assume valid index
    func play(_ trackIndex: Int, _ interruptPlayingTrack: Bool) {
        
        let shouldPlay: Bool = interruptPlayingTrack || playlist.getPlayingTrack() == nil
        
        if (shouldPlay) {
            
            do {
                let track = playlist.selectTrackAt(trackIndex)
                try play(track)
                EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(track))
            } catch let error as Error {
                
                if (error is InvalidTrackError) {
                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
                }
            }
        }
    }
    
    func stop() {
        if (playbackState != .noTrack) {
            stopPlayback()
        }
    }
    
    func trackRemoved(_ removedTrackIndex: Int) {
        
        let playingTrack = playlist.getPlayingTrack()
        if (playingTrack?.index == removedTrackIndex) {
            // Stop playback and let the UI know
            stopPlayback()
            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(nil))
        }
    }
    
    // Signals a reordering of the playlist (e.g. sorting)
    func playlistReordered(_ newTrackIndex: Int?) {
    }
    
    func playlistCleared() {
        stop()
    }
    
    // A random track has been selected for playback
    func randomTrackSelected(_ trackIndex: Int) {}
    
    // A single new track has been added
    func trackAdded() {}
    
    // A single track has been moved, from a particular index to another
    func trackReordered(_ oldIndex: Int, _ newIndex: Int) {
    }
    
    func appExiting(_ uiState: UIState) {
//        player.tearDown()
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
