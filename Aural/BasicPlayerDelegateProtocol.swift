import Foundation

protocol BasicPlayerDelegateProtocol {
    
    func play(_ trackIndex: Int, _ interruptPlayingTrack: Bool)
    
    func stop()
}
