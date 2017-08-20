import Foundation

/*
    Contract for all subscribers of messages
 */
protocol MessageSubscriber {
  
    // Every message subscriber must implement this method to consume a message it is interested in
    func consumeMessage(_ message: Message)
}

/*
    Defines a inter-view message, sent from one view to another, in response to state changes or user actions. Messages could be either 1 - notifications, indicating that some change has occurred (e.g. the playlist has been cleared), OR 2 - requests for the execution of a function (e.g. track playback) from a different view.
 */
protocol Message {
    var messageType: MessageType {get}
}

// Enumeration of the different message types. See the various Message structs below, for descriptions of each message type.
enum MessageType {
    
    case trackChangedNotification
    case trackPlaybackRequest
    case stopPlaybackRequest
    case seekTimerIntervalChangeRequest
}

// Notification from the player that the playing track has changed (for instance, "next track" or when a track has finished playing)
struct TrackChangedNotification: Message {
    
    var messageType: MessageType = .trackChangedNotification
    var newTrack: IndexedTrack?
    
    init(_ newTrack: IndexedTrack?) {
        self.newTrack = newTrack
    }
}

// Request from the playlist to play back the user-selected track (for instance, when the user double clicks a track in the playlist)
struct TrackPlaybackRequest: Message {
    
    var messageType: MessageType = .trackPlaybackRequest
    var trackIndex: Int
    
    init(_ trackIndex: Int) {
        self.trackIndex = trackIndex
    }
}

// Request from the playlist to stop playback (for instance, when the playlist is cleared, or the playing track has been removed)
struct StopPlaybackRequest: Message {
    
    var messageType: MessageType = .stopPlaybackRequest
    static let instance: StopPlaybackRequest = StopPlaybackRequest()
    
    private init() {}
}

// Request from the Time effects unit to change the seek timer interval, in response to the user changing the playback rate.
struct SeekTimerIntervalChangeRequest: Message {
    
    var messageType: MessageType = .seekTimerIntervalChangeRequest
    var newIntervalMillis: Int
    
    init(_ newIntervalMillis: Int) {
        self.newIntervalMillis = newIntervalMillis
    }
}
