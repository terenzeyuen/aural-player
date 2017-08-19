import Cocoa

class CollapsibleViewController: NSViewController {
    
    @IBOutlet weak var window: NSWindow!
    
    // Buttons to toggle (collapsible) playlist/effects views
    @IBOutlet weak var btnToggleEffects: NSButton!
    @IBOutlet weak var btnTogglePlaylist: NSButton!
    
    @IBOutlet weak var viewPlaylistMenuItem: NSMenuItem!
    @IBOutlet weak var viewEffectsMenuItem: NSMenuItem!
    
    // Views that are collapsible (hide/show)
    @IBOutlet weak var playlistControlsBox: NSBox!
    @IBOutlet weak var fxTabView: NSTabView!
    @IBOutlet weak var fxBox: NSBox!
    @IBOutlet weak var playlistBox: NSBox!
    
    var playlistCollapsibleView: CollapsibleView?
    var fxCollapsibleView: CollapsibleView?
 
    override func viewDidLoad() {
        
        playlistCollapsibleView = CollapsibleView(views: [playlistBox, playlistControlsBox])
        fxCollapsibleView = CollapsibleView(views: [fxBox])
        
        let appState = AppInitializer.getUIAppState()
        
        if (appState.hidePlaylist) {
            toggleViewPlaylistAction(self)
        }
        
        if (appState.hideEffects) {
            toggleViewEffectsAction(self)
        }
    }
    
    // View menu item action
    @IBAction func toggleViewEffectsAction(_ sender: AnyObject) {
        
        if (fxCollapsibleView?.hidden)! {
            resizeWindow(playlistShown: !(playlistCollapsibleView?.hidden)!, effectsShown: true, sender !== self)
            fxCollapsibleView!.show()
            btnToggleEffects.state = 1
            btnToggleEffects.image = UIConstants.imgEffectsOn
            viewEffectsMenuItem.state = 1
        } else {
            fxCollapsibleView!.hide()
            resizeWindow(playlistShown: !(playlistCollapsibleView?.hidden)!, effectsShown: false, sender !== self)
            btnToggleEffects.state = 0
            btnToggleEffects.image = UIConstants.imgEffectsOff
            viewEffectsMenuItem.state = 0
        }
        
        //        showPlaylistSelectedRow()
    }
    
    // View menu item action
    @IBAction func toggleViewPlaylistAction(_ sender: AnyObject) {
        
        // Set focus on playlist view if it's visible after the toggle
        
        if (playlistCollapsibleView?.hidden)! {
            resizeWindow(playlistShown: true, effectsShown: !(fxCollapsibleView?.hidden)!, sender !== self)
            playlistCollapsibleView!.show()
            window.makeFirstResponder(playlistView)
            btnTogglePlaylist.state = 1
            btnTogglePlaylist.image = UIConstants.imgPlaylistOn
            viewPlaylistMenuItem.state = 1
        } else {
            playlistCollapsibleView!.hide()
            resizeWindow(playlistShown: false, effectsShown: !(fxCollapsibleView?.hidden)!, sender !== self)
            btnTogglePlaylist.state = 0
            btnTogglePlaylist.image = UIConstants.imgPlaylistOff
            viewPlaylistMenuItem.state = 0
        }
        
        //        showPlaylistSelectedRow()
    }
    
    // Called when toggling views
    func resizeWindow(playlistShown: Bool, effectsShown: Bool, _ animate: Bool) {
        
        var wFrame = window.frame
        let oldOrigin = wFrame.origin
        
        var newHeight: CGFloat
        
        if (effectsShown && playlistShown) {
            newHeight = UIConstants.windowHeight_playlistAndEffects
        } else if (effectsShown) {
            newHeight = UIConstants.windowHeight_effectsOnly
        } else if (playlistShown) {
            newHeight = UIConstants.windowHeight_playlistOnly
        } else {
            newHeight = UIConstants.windowHeight_compact
        }
        
        let oldHeight = wFrame.height
        let shrinking: Bool = newHeight < oldHeight
        
        wFrame.size = NSMakeSize(window.frame.width, newHeight)
        wFrame.origin = NSMakePoint(oldOrigin.x, shrinking ? oldOrigin.y + (oldHeight - newHeight) : oldOrigin.y - (newHeight - oldHeight))
        
        window.setFrame(wFrame, display: true, animate: animate)
    }
    
    // Toggle button action
    @IBAction func togglePlaylistAction(_ sender: AnyObject) {
        toggleViewPlaylistAction(sender)
    }
    
    // Toggle button action
    @IBAction func toggleEffectsAction(_ sender: AnyObject) {
        toggleViewEffectsAction(sender)
    }
    
    private func isEffectsShown() -> Bool {
        return fxCollapsibleView?.hidden == false
    }
    
    private func isPlaylistShown() -> Bool {
        return playlistCollapsibleView?.hidden == false
    }
}
