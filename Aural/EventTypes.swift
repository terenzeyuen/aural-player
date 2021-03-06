import Cocoa

/*
    An enumeration of all event types
*/
enum EventType {
    
    case playbackCompleted

    case trackChanged
    
    case trackInfoUpdated
    
    case trackAdded
    
    case trackNotPlayed
    
    case tracksNotAdded
    
    case startedAddingTracks
    
    case doneAddingTracks
}

// Event indicating that the currently playing track has changed and the UI needs to be refreshed with the new track information
class TrackChangedEvent: Event {
    
    // The track that is now playing (may be nil, meaning no track playing)
    var newTrack: IndexedTrack?
    
    init(_ newTrack: IndexedTrack?) {
        self.newTrack = newTrack
    }
}

// Event indicating that playback of the currently playing track has completed
class PlaybackCompletedEvent: Event {
    
    // The PlaybackSession associated with this event. This is required in order to determine if the session is still current. If another session has started before this event occurs, this event is no longer relevant because its session has been invalidated. For instance, if the user selects "Next track" before the previous track completes playing, this playback completion event no longer needs to be processed.
    let session: PlaybackSession
    init(_ session: PlaybackSession) {self.session = session}
}

// Event indicating that some new information has been loaded for a track (e.g. duration/display name, etc), and that the UI should refresh itself to show the new information
class TrackInfoUpdatedEvent: Event {
    
    var trackIndex: Int
    
    init(trackIndex: Int) {
        self.trackIndex = trackIndex
    }
}

// Event indicating that a new track has been added to the playlist, and that the UI should refresh itself to show the new information
class TrackAddedEvent: Event {
    
    var trackIndex: Int
    var progress: TrackAddedEventProgress
    
    init(_ trackIndex: Int, _ progress: TrackAddedEventProgress) {
        self.trackIndex = trackIndex
        self.progress = progress
    }
}

// Indicates current progress associated with a TrackAddedEvent
class TrackAddedEventProgress {
    
    var tracksAdded: Int
    var totalTracks: Int
    
    // Computed property
    var percentage: Double
    
    init(_ tracksAdded: Int, _ totalTracks: Int) {
        self.tracksAdded = tracksAdded
        self.totalTracks = totalTracks
        self.percentage = totalTracks > 0 ? Double(tracksAdded) * 100 / Double(totalTracks) : 0
    }
}

// Event indicating that an error was encountered while attempting to play back a track
class TrackNotPlayedEvent: Event {
 
    // An error object containing detailed information such as the track file and the root cause
    var error: InvalidTrackError
    
    init(_ error: InvalidTrackError) {
        self.error = error
    }
}

// Event indicating that some selected files were not loaded into the playlist
class TracksNotAddedEvent: Event {
    
    // An array of error objects containing detailed information such as the track file and the root cause
    var errors: [InvalidTrackError]
    
    init(_ errors: [InvalidTrackError]) {
        self.errors = errors
    }
}

// Event indicating that tracks are now being added to the playlist in a background thread
class StartedAddingTracksEvent: Event {
    static let instance = StartedAddingTracksEvent()
}

// Event indicating that tracks are done being added to the playlist in a background thread
class DoneAddingTracksEvent: Event {
    static let instance = DoneAddingTracksEvent()
}
