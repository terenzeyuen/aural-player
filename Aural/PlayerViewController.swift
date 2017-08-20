import Cocoa

class PlayerViewController: NSViewController, EventSubscriber, MessageSubscriber {
    
    @IBOutlet weak var btnPlayPause: NSButton!
    
    // Now playing track info
    @IBOutlet weak var lblTrackArtist: NSTextField!
    @IBOutlet weak var lblTrackTitle: NSTextField!
    @IBOutlet weak var bigLblTrack: NSTextField!
    
    @IBOutlet weak var musicArtView: NSImageView!
    
    @IBOutlet weak var seekSlider: NSSlider!
    @IBOutlet weak var lblPlayingTime: NSTextField!
    
    // Timer that periodically updates the seek slider bar and playing time
    private var seekTimer: ScheduledTaskExecutor? = nil
    
    @IBOutlet weak var btnMoreInfo: NSButton!
    
    private let player: PlayerDelegateProtocol = ObjectGraph.getPlayerDelegate()
    
    // Popover view that displays detailed track info
    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .semitransient
        let ctrlr = PopoverController(nibName: "PopoverController", bundle: Bundle.main)
        popover.contentViewController = ctrlr
        return popover
    }()
    
    override func viewDidLoad() {
        print("FAAK YOU, ASSHOLLLLLLLLLE")
        
        let appState = ObjectGraph.getUIAppState()
        
        seekTimer = ScheduledTaskExecutor(intervalMillis: appState.seekTimerInterval, task: {self.updatePlayingTime()}, queue: DispatchQueue.main)
        
        // Register self as a subscriber to various event notifications
        EventRegistry.subscribe(.trackChanged, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.trackNotPlayed, subscriber: self, dispatchQueue: DispatchQueue.main)
        
        // Register self as a subscriber to various UI message notifications
        UIMessenger.subscribe(.trackPlaybackRequest, subscriber: self)
        UIMessenger.subscribe(.stopPlaybackRequest, subscriber: self)
    }
    
    @IBAction func playPauseAction(_ sender: Any) {
        
        print("Play or pause, mothafuckaaaa ?!!!!")
        
        do {
            
            let playbackInfo = try player.togglePlayPause()
            
            switch playbackInfo.playbackState {
                
            case .noTrack, .paused: setSeekTimerState(false)
                                    setPlayPauseImage(UIConstants.imgPlay)
                
            case .playing:
                
                if (playbackInfo.trackChanged) {
                    trackChange(playbackInfo.playingTrack)
                } else {
                    // Resumed the same track
                    setSeekTimerState(true)
                    setPlayPauseImage(UIConstants.imgPause)
                }
            }
            
        } catch let error as Error {
            
            if (error is InvalidTrackError) {
//                handleTrackNotPlayedError(error as! InvalidTrackError)
            }
        }
    }
    
    private func setSeekTimerState(_ timerOn: Bool) {
        
        if (timerOn) {
            seekSlider.isEnabled = true
            seekTimer?.startOrResume()
        } else {
            seekTimer?.pause()
            seekSlider.isEnabled = false
        }
    }
    
    private func setPlayPauseImage(_ image: NSImage) {
        btnPlayPause.image = image
    }
    
    // The "errorState" arg indicates whether the player is in an error state (i.e. the new track cannot be played back). If so, update the UI accordingly.
    func trackChange(_ newTrack: IndexedTrack?, _ errorState: Bool = false) {
        
        if (newTrack != nil) {
            
            showNowPlayingInfo(newTrack!.track!)
            
            if (!errorState) {
                setSeekTimerState(true)
                setPlayPauseImage(UIConstants.imgPause)
                btnMoreInfo.isHidden = false
                
                if (popover.isShown) {
                    player.getMoreInfo()
                    (popover.contentViewController as! PopoverController).refresh()
                }
                
            } else {
                
                // Error state
                
                setSeekTimerState(false)
                setPlayPauseImage(UIConstants.imgPlay)
                btnMoreInfo.isHidden = true
                
                hidePopover()
            }
            
        } else {
            
            setSeekTimerState(false)
            clearNowPlayingInfo()
        }
        
        resetPlayingTime()
        
        let trackChangedMessage = TrackChangedNotification(newTrack)
        UIMessenger.publishMessage(trackChangedMessage)
    }
    
    func showNowPlayingInfo(_ track: Track) {
        
        if (track.longDisplayName != nil) {
            
            if (track.longDisplayName!.artist != nil) {
                
                // Both title and artist
                lblTrackArtist.stringValue = "Artist:  " + track.longDisplayName!.artist!
                lblTrackTitle.stringValue = "Title:  " + track.longDisplayName!.title!
                
                bigLblTrack.isHidden = true
                lblTrackArtist.isHidden = false
                lblTrackTitle.isHidden = false
                
            } else {
                
                // Title only
                bigLblTrack.isHidden = false
                lblTrackArtist.isHidden = true
                lblTrackTitle.isHidden = true
                
                bigLblTrack.stringValue = track.longDisplayName!.title!
            }
            
        } else {
            
            // Short display name
            bigLblTrack.isHidden = false
            lblTrackArtist.isHidden = true
            lblTrackTitle.isHidden = true
            
            bigLblTrack.stringValue = track.shortDisplayName!
        }
        
        if (track.metadata!.art != nil) {
            musicArtView.image = track.metadata!.art!
        } else {
            musicArtView.image = UIConstants.imgMusicArt
        }
    }
    
    func clearNowPlayingInfo() {
        lblTrackArtist.stringValue = ""
        lblTrackTitle.stringValue = ""
        bigLblTrack.stringValue = ""
        lblPlayingTime.stringValue = UIConstants.zeroDurationString
        seekSlider.floatValue = 0
        musicArtView.image = UIConstants.imgMusicArt
        btnMoreInfo.isHidden = true
        setPlayPauseImage(UIConstants.imgPlay)
        hidePopover()
    }
    
    func updatePlayingTime() {
        
        if (player.getPlaybackState() == .playing) {
            
            let seekPosn = player.getSeekPosition()
            
            lblPlayingTime.stringValue = Utils.formatDuration(seekPosn.seconds)
            seekSlider.doubleValue = seekPosn.percentage
        }
    }
    
    func resetPlayingTime() {
        
        lblPlayingTime.stringValue = UIConstants.zeroDurationString
        seekSlider.floatValue = 0
    }
    
    @IBAction func seekBackwardAction(_ sender: AnyObject) {
        player.seekBackward()
        updatePlayingTime()
    }
    
    @IBAction func seekForwardAction(_ sender: AnyObject) {
        player.seekForward()
        updatePlayingTime()
    }
    
    @IBAction func seekSliderAction(_ sender: AnyObject) {
        player.seekToPercentage(seekSlider.doubleValue)
        updatePlayingTime()
    }
    
    @IBAction func moreInfoAction(_ sender: AnyObject) {
        
        let playingTrack = player.getMoreInfo()
        if (playingTrack == nil) {
            return
        }
        
        if (popover.isShown) {
            popover.performClose(nil)
            
        } else {
            
            let positioningRect = NSZeroRect
            let preferredEdge = NSRectEdge.maxX
            
            (popover.contentViewController as! PopoverController).refresh()
            popover.show(relativeTo: positioningRect, of: btnMoreInfo as NSView, preferredEdge: preferredEdge)
        }
    }
    
    private func hidePopover() {
        if (popover.isShown) {
            popover.performClose(nil)
        }
    }
    
    @IBAction func previousTrackAction(_ sender: AnyObject) {
        
        do {
         
            let track = try player.previousTrack()
            if (track?.track != nil) {
                trackChange(track)
            }
            
        } catch let error as Error {
            
            if (error is InvalidTrackError) {
                //                handleTrackNotPlayedError(error as! InvalidTrackError)
            }
        }
    }
    
    @IBAction func nextTrackAction(_ sender: AnyObject) {
        
        do {
            
            let track = try player.nextTrack()
            if (track?.track != nil) {
                trackChange(track)
            }
            
        } catch let error as Error {
            
            if (error is InvalidTrackError) {
                //                handleTrackNotPlayedError(error as! InvalidTrackError)
            }
        }
    }
    
    private func playTrack(_ index: Int) {
        
        do {
            
            let newTrack = try player.play(index)
            trackChange(newTrack)
            
        } catch let error as Error {
            
            if (error is InvalidTrackError) {
                //                handleTrackNotPlayedError(error as! InvalidTrackError)
            }
        }
    }
    
    @IBAction func togglePlayPauseMenuItemAction(_ sender: Any) {
        playPauseAction(sender as AnyObject)
    }
    
    @IBAction func nextTrackMenuItemAction(_ sender: Any) {
        nextTrackAction(sender as AnyObject)
    }
    
    @IBAction func previousTrackMenuItemAction(_ sender: Any) {
        previousTrackAction(sender as AnyObject)
    }
    
    @IBAction func trackInfoMenuItemAction(_ sender: Any) {
        moreInfoAction(sender as AnyObject)
    }
    
    @IBAction func seekForwardMenuItemAction(_ sender: Any) {
        seekForwardAction(sender as AnyObject)
    }
    
    @IBAction func seekBackwardMenuItemAction(_ sender: Any) {
        seekBackwardAction(sender as AnyObject)
    }
    
    // Playlist info changed, need to reset the UI
    func consumeEvent(_ event: Event) {
        
        if event is TrackChangedEvent {
            setSeekTimerState(false)
            let _event = event as! TrackChangedEvent
            trackChange(_event.newTrack)
            
            return
        }
        
        if event is TrackNotPlayedEvent {
            let _evt = event as! TrackNotPlayedEvent
            handleTrackNotPlayedError(_evt.error)
            
            return
        }
    }
    
    func handleTrackNotPlayedError(_ error: InvalidTrackError) {
        
        // This needs to be done async. Otherwise, other open dialogs could hang.
        DispatchQueue.main.async {
            
            // First, select the problem track and update the now playing info
            let playingTrack = self.player.getPlayingTrack()
            self.trackChange(playingTrack, true)
            
            // Position and display the dialog with info
            let alert = UIElements.trackNotPlayedAlertWithError(error)
            
//            let orig = NSPoint(x: self.window.frame.origin.x, y: min(self.window.frame.origin.y + 227, self.window.frame.origin.y + self.window.frame.height - alert.window.frame.height))
//            
//            alert.window.setFrameOrigin(orig)
            alert.window.setIsVisible(true)
            
            alert.runModal()
        }
    }
    
    func consumeMessage(_ message: Message) {
        
        if (message is TrackPlaybackRequest) {
            let _msg = message as! TrackPlaybackRequest
            let trackIndex = _msg.trackIndex
            playTrack(trackIndex)
            
            return
        }
        
        if (message is StopPlaybackRequest) {
            
        }
    }
}
