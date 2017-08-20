import Foundation

protocol PlaybackControl {
    
    func play(_ track: IndexedTrack, _ interruptPlayingTrack: Bool)
    
    func stop()
}
