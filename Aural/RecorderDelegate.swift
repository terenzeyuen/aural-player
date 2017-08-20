import Foundation

class RecorderDelegate: AuralRecorderDelegate {
    
    func startRecording(_ format: RecordingFormat) {
        player.startRecording(format)
    }
    
    func stopRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.player.stopRecording()
        }
    }
    
    func saveRecording(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.player.saveRecording(url)
        }
    }
    
    func deleteRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.player.deleteRecording()
        }
    }
    
    func getRecordingInfo() -> RecordingInfo? {
        return player.getRecordingInfo()
    }
}
