import Foundation

protocol BasicPlayerDelegateProtocol {
    
    func play(_ track: IndexedTrack, _ interruptPlayingTrack: Bool)
    
    func stop()
}
