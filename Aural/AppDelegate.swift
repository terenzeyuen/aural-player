/*
    Entry point for the Aural Player application. Performs all interaction with the UI and delegates music player operations to PlayerDelegate.
 */
import Cocoa
import AVFoundation

// TODO: Can I have multiple app delegates ?
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Set up key press handler
        KeyPressHandler.initialize(self)
        NSEvent.addLocalMonitorForEvents(matching: NSEventMask.keyDown, handler: {(evt: NSEvent!) -> NSEvent in
            KeyPressHandler.handle(evt)
            return evt;
        });
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        tearDown()
    }
    
    func tearDown() {
        
//        let uiState = UIState()
//        uiState.windowLocationX = Float(window.frame.origin.x)
//        uiState.windowLocationY = Float(window.frame.origin.y)
        //        uiState.showPlaylist = isPlaylistShown()
        //        uiState.showEffects = isEffectsShown()
        
//        player.appExiting(uiState)
    }
}
