/*
    Entry point for the Aural Player application. Performs all interaction with the UI and delegates music player operations to PlayerDelegate.
 */
import Cocoa
import AVFoundation

// TODO: Can I have multiple app delegates ?
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, EventSubscriber {
    
    @IBOutlet weak var window: NSWindow!
    
    // Effects panel tab view buttons
    @IBOutlet weak var eqTabViewButton: NSButton!
    @IBOutlet weak var pitchTabViewButton: NSButton!
    @IBOutlet weak var timeTabViewButton: NSButton!
    @IBOutlet weak var reverbTabViewButton: NSButton!
    @IBOutlet weak var delayTabViewButton: NSButton!
    @IBOutlet weak var filterTabViewButton: NSButton!
    @IBOutlet weak var recorderTabViewButton: NSButton!
    
    private var fxTabViewButtons: [NSButton]?
    
    // Pitch controls
    @IBOutlet weak var btnPitchBypass: NSButton!
    @IBOutlet weak var pitchSlider: NSSlider!
    @IBOutlet weak var pitchOverlapSlider: NSSlider!
    @IBOutlet weak var lblPitchValue: NSTextField!
    @IBOutlet weak var lblPitchOverlapValue: NSTextField!
    
    // Time controls
    @IBOutlet weak var timeSlider: NSSlider!
    @IBOutlet weak var timeOverlapSlider:
    NSSlider!
    @IBOutlet weak var lblTimeStretchRateValue: NSTextField!
    @IBOutlet weak var lblTimeOverlapValue: NSTextField!
    
    // Reverb controls
    @IBOutlet weak var btnReverbBypass: NSButton!
    @IBOutlet weak var reverbMenu: NSPopUpButton!
    @IBOutlet weak var reverbSlider: NSSlider!
    @IBOutlet weak var lblReverbAmountValue: NSTextField!
    
    // Delay controls
    @IBOutlet weak var btnDelayBypass: NSButton!
    @IBOutlet weak var delayTimeSlider: NSSlider!
    @IBOutlet weak var delayAmountSlider: NSSlider!
    @IBOutlet weak var btnTimeBypass: NSButton!
    @IBOutlet weak var delayCutoffSlider: NSSlider!
    @IBOutlet weak var delayFeedbackSlider: NSSlider!
    
    @IBOutlet weak var lblDelayTimeValue: NSTextField!
    @IBOutlet weak var lblDelayAmountValue: NSTextField!
    @IBOutlet weak var lblDelayFeedbackValue: NSTextField!
    @IBOutlet weak var lblDelayLowPassCutoffValue: NSTextField!
    
    // Filter controls
    @IBOutlet weak var btnFilterBypass: NSButton!
    @IBOutlet weak var filterBassSlider: RangeSlider!
    @IBOutlet weak var filterMidSlider: RangeSlider!
    @IBOutlet weak var filterTrebleSlider: RangeSlider!
    
    @IBOutlet weak var lblFilterBassRange: NSTextField!
    @IBOutlet weak var lblFilterMidRange: NSTextField!
    @IBOutlet weak var lblFilterTrebleRange: NSTextField!
    
    // Recorder controls
    @IBOutlet weak var btnRecord: NSButton!
    @IBOutlet weak var lblRecorderDuration: NSTextField!
    @IBOutlet weak var lblRecorderFileSize: NSTextField!
    @IBOutlet weak var recordingInfoBox: NSBox!
    
    // Parametric equalizer controls
    @IBOutlet weak var eqGlobalGainSlider: NSSlider!
    @IBOutlet weak var eqSlider1k: NSSlider!
    @IBOutlet weak var eqSlider64: NSSlider!
    @IBOutlet weak var eqSlider16k: NSSlider!
    @IBOutlet weak var eqSlider8k: NSSlider!
    @IBOutlet weak var eqSlider4k: NSSlider!
    @IBOutlet weak var eqSlider2k: NSSlider!
    @IBOutlet weak var eqSlider32: NSSlider!
    @IBOutlet weak var eqSlider512: NSSlider!
    @IBOutlet weak var eqSlider256: NSSlider!
    @IBOutlet weak var eqSlider128: NSSlider!
    @IBOutlet weak var eqPresets: NSPopUpButton!
    
    // PlayerDelegate accepts all requests originating from the UI
    let player: PlayerDelegate = PlayerDelegate.instance()
    
    // Timer that periodically updates the recording duration (only when recorder is active)
    var recorderTimer: ScheduledTaskExecutor?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
//        userDefaults.
        
        window.setIsVisible(false)
        
        // Initialize UI with presentation settings (colors, sizes, etc)
        // No app state is needed here
        initStatelessUI()
        
        // Set up key press handler
        KeyPressHandler.initialize(self)
        NSEvent.addLocalMonitorForEvents(matching: NSEventMask.keyDown, handler: {(evt: NSEvent!) -> NSEvent in
            KeyPressHandler.handle(evt)
            return evt;
        });
        
        // Load saved state (sound settings + playlist) from app config file and adjust UI elements according to that state
        let appState = player.appLoaded()
        initStatefulUI(appState)
        
        // TODO: Where/when should this be done ?
        positionWindow(appState.windowLocation)
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(self)
    }
    
    func positionWindow(_ location: NSPoint) {
        window.setFrameOrigin(location)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        tearDown()
    }
    
    func initStatelessUI() {
        
        
        recorderTimer = ScheduledTaskExecutor(intervalMillis: UIConstants.recorderTimerIntervalMillis, task: {self.updateRecordingInfo()}, queue: DispatchQueue.main)
        
        // Set up the filter control sliders
        
        filterBassSlider.minValue = AppConstants.bass_min
        filterBassSlider.maxValue = AppConstants.bass_max
        filterBassSlider.onControlChanged = {
            (slider: RangeSlider) -> Void in
            
            self.filterBassChanged()
        }
        
        filterMidSlider.minValue = AppConstants.mid_min
        filterMidSlider.maxValue = AppConstants.mid_max
        filterMidSlider.onControlChanged = {
            (slider: RangeSlider) -> Void in
            
            self.filterMidChanged()
        }
        
        filterTrebleSlider.minValue = AppConstants.treble_min
        filterTrebleSlider.maxValue = AppConstants.treble_max
        filterTrebleSlider.onControlChanged = {
            (slider: RangeSlider) -> Void in
            
            self.filterTrebleChanged()
        }
        
        fxTabViewButtons = [eqTabViewButton, pitchTabViewButton, timeTabViewButton, reverbTabViewButton, delayTabViewButton, filterTabViewButton, recorderTabViewButton]
    }
    
    func initStatefulUI(_ appState: UIAppState) {
        
        // Set controls to reflect player state
        
        eqGlobalGainSlider.floatValue = appState.eqGlobalGain
        updateEQSliders(appState.eqBands)
        
        (eqTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = true
        
        btnPitchBypass.image = appState.pitchBypass ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
        (pitchTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !appState.pitchBypass
        
        pitchSlider.floatValue = appState.pitch
        lblPitchValue.stringValue = appState.formattedPitch
        
        pitchOverlapSlider.floatValue = appState.pitchOverlap
        lblPitchOverlapValue.stringValue = appState.formattedPitchOverlap
        
        btnTimeBypass.image = appState.timeBypass ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
        (timeTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !appState.timeBypass
        
        timeSlider.floatValue = appState.timeStretchRate
        lblTimeStretchRateValue.stringValue = appState.formattedTimeStretchRate
        
        timeOverlapSlider.floatValue = appState.timeOverlap
        lblTimeOverlapValue.stringValue = appState.formattedTimeOverlap
        
        btnReverbBypass.image = appState.reverbBypass ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
        (reverbTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !appState.reverbBypass
        
        reverbMenu.select(reverbMenu.item(withTitle: appState.reverbPreset))
        
        reverbSlider.floatValue = appState.reverbAmount
        lblReverbAmountValue.stringValue = appState.formattedReverbAmount
        
        btnDelayBypass.image = appState.delayBypass ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
        (delayTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !appState.delayBypass
        
        delayAmountSlider.floatValue = appState.delayAmount
        lblDelayAmountValue.stringValue = appState.formattedDelayAmount
        
        delayTimeSlider.doubleValue = appState.delayTime
        lblDelayTimeValue.stringValue = appState.formattedDelayTime
        
        delayFeedbackSlider.floatValue = appState.delayFeedback
        lblDelayFeedbackValue.stringValue = appState.formattedDelayFeedback
        
        delayCutoffSlider.floatValue = appState.delayLowPassCutoff
        lblDelayLowPassCutoffValue.stringValue = appState.formattedDelayLowPassCutoff
        
        btnFilterBypass.image = appState.filterBypass ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
        (filterTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !appState.filterBypass
        
        filterBassSlider.start = appState.filterBassMin
        filterBassSlider.end = appState.filterBassMax
        lblFilterBassRange.stringValue = appState.formattedFilterBassRange
        
        filterMidSlider.start = appState.filterMidMin
        filterMidSlider.end = appState.filterMidMax
        lblFilterMidRange.stringValue = appState.formattedFilterMidRange
        
        filterTrebleSlider.start = appState.filterTrebleMin
        filterTrebleSlider.end = appState.filterTrebleMax
        lblFilterTrebleRange.stringValue = appState.formattedFilterTrebleRange
        
        for btn in fxTabViewButtons! {
            (btn.cell as! EffectsUnitButtonCell).highlightColor = btn === recorderTabViewButton ? Colors.tabViewRecorderButtonHighlightColor : Colors.tabViewEffectsButtonHighlightColor
            btn.needsDisplay = true
        }

        // Select EQ by default
        eqTabViewAction(self)
        
        // Don't select any items from the EQ presets menu
        eqPresets.selectItem(at: -1)
        
    }
    
    private func updateEQSliders(_ eqBands: [Int: Float]) {
        
        eqSlider32.floatValue = eqBands[32]!
        eqSlider64.floatValue = eqBands[64]!
        eqSlider128.floatValue = eqBands[128]!
        eqSlider256.floatValue = eqBands[256]!
        eqSlider512.floatValue = eqBands[512]!
        eqSlider1k.floatValue = eqBands[1024]!
        eqSlider2k.floatValue = eqBands[2048]!
        eqSlider4k.floatValue = eqBands[4096]!
        eqSlider8k.floatValue = eqBands[8192]!
        eqSlider16k.floatValue = eqBands[16384]!
    }
    
    func tearDown() {
        
        let uiState = UIState()
        uiState.windowLocationX = Float(window.frame.origin.x)
        uiState.windowLocationY = Float(window.frame.origin.y)
//        uiState.showPlaylist = isPlaylistShown()
//        uiState.showEffects = isEffectsShown()
        
        player.appExiting(uiState)
    }
    
    @IBAction func eqPresetsAction(_ sender: AnyObject) {
        
        let preset = EQPresets.fromDescription((eqPresets.selectedItem?.title)!)
        
        let eqBands: [Int: Float] = preset.bands
        player.setEQBands(eqBands)
        updateEQSliders(eqBands)
        
        eqPresets.selectItem(at: -1)
    }
    
    @IBAction func closeAction(_ sender: AnyObject) {
        
        if let _ = player.getRecordingInfo() {
            
            // Recording ongoing, prompt the user to save/discard it
            let response = UIElements.saveRecordingAlert.runModal()
            
            switch response {
                
            case RecordingAlertResponse.dontExit.rawValue: return
            case RecordingAlertResponse.saveAndExit.rawValue: stopRecording()
            case RecordingAlertResponse.discardAndExit.rawValue: player.deleteRecording()
                
            // Impossible
            default: return
                
            }
        }
        
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func hideAction(_ sender: AnyObject) {
        window.miniaturize(self)
    }
    
    @IBAction func pitchBypassAction(_ sender: AnyObject) {
        
        let newBypassState = player.togglePitchBypass()
        
        (pitchTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !newBypassState
        pitchTabViewButton.needsDisplay = true
        
        btnPitchBypass.image = newBypassState ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
    }
    
    @IBAction func pitchAction(_ sender: AnyObject) {
        
        let pitchValueStr = player.setPitch(pitchSlider.floatValue)
        lblPitchValue.stringValue = pitchValueStr
    }
    
    @IBAction func pitchOverlapAction(_ sender: AnyObject) {
        let pitchOverlapValueStr = player.setPitchOverlap(pitchOverlapSlider.floatValue)
        lblPitchOverlapValue.stringValue = pitchOverlapValueStr
    }
    
    @IBAction func timeBypassAction(_ sender: AnyObject) {
        
        let newBypassState = player.toggleTimeBypass()
        
        (timeTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !newBypassState
        timeTabViewButton.needsDisplay = true
        
        btnTimeBypass.image = newBypassState ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
//        
//        let interval = newBypassState ? UIConstants.seekTimerIntervalMillis : Int(1000 / (2 * timeSlider.floatValue))
//        
//        if (interval != seekTimer?.getInterval()) {
//            
//            seekTimer?.stop()
//            
//            seekTimer = ScheduledTaskExecutor(intervalMillis: interval, task: {self.updatePlayingTime()}, queue: DispatchQueue.main)
//            
//            if (player.getPlaybackState() == .playing) {
//                setSeekTimerState(true)
//            }
//        }
    }
    
    @IBAction func timeStretchAction(_ sender: AnyObject) {
        
        let rateValueStr = player.setTimeStretchRate(timeSlider.floatValue)
        lblTimeStretchRateValue.stringValue = rateValueStr
        
        let timeStretchActive = !player.isTimeBypass()
        if (timeStretchActive) {
            
//            let interval = Int(1000 / (2 * timeSlider.floatValue))
//            
//            seekTimer?.stop()
//            
//            seekTimer = ScheduledTaskExecutor(intervalMillis: interval, task: {self.updatePlayingTime()}, queue: DispatchQueue.main)
//            
//            if (player.getPlaybackState() == .playing) {
//                setSeekTimerState(true)
//            }
        }
    }
    
    @IBAction func timeOverlapAction(_ sender: Any) {
        
        let timeOverlapValueStr = player.setTimeOverlap(timeOverlapSlider.floatValue)
        lblTimeOverlapValue.stringValue = timeOverlapValueStr
    }
    
    @IBAction func reverbBypassAction(_ sender: AnyObject) {
        
        let newBypassState = player.toggleReverbBypass()
        
        (reverbTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !newBypassState
        reverbTabViewButton.needsDisplay = true
        
        btnReverbBypass.image = newBypassState ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
    }
    
    @IBAction func reverbAction(_ sender: AnyObject) {
        
        let preset: ReverbPresets = ReverbPresets.fromDescription((reverbMenu.selectedItem?.title)!)
        player.setReverb(preset)
    }
    
    @IBAction func reverbAmountAction(_ sender: AnyObject) {
        let reverbAmountValueStr = player.setReverbAmount(reverbSlider.floatValue)
        lblReverbAmountValue.stringValue = reverbAmountValueStr
    }
    
    @IBAction func delayBypassAction(_ sender: AnyObject) {
        
        let newBypassState = player.toggleDelayBypass()
        
        (delayTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !newBypassState
        delayTabViewButton.needsDisplay = true
        
        btnDelayBypass.image = newBypassState ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
    }
    
    @IBAction func delayAmountAction(_ sender: AnyObject) {
        let delayAmountValueStr = player.setDelayAmount(delayAmountSlider.floatValue)
        lblDelayAmountValue.stringValue = delayAmountValueStr
    }
    
    @IBAction func delayTimeAction(_ sender: AnyObject) {
        let delayTimeValueStr = player.setDelayTime(delayTimeSlider.doubleValue)
        lblDelayTimeValue.stringValue = delayTimeValueStr
    }
    
    @IBAction func delayFeedbackAction(_ sender: AnyObject) {
        let delayFeedbackValueStr = player.setDelayFeedback(delayFeedbackSlider.floatValue)
        lblDelayFeedbackValue.stringValue = delayFeedbackValueStr
    }
    
    @IBAction func delayCutoffAction(_ sender: AnyObject) {
        let delayCutoffValueStr = player.setDelayLowPassCutoff(delayCutoffSlider.floatValue)
        lblDelayLowPassCutoffValue.stringValue = delayCutoffValueStr
    }
    
    @IBAction func filterBypassAction(_ sender: AnyObject) {
        
        let newBypassState = player.toggleFilterBypass()
        
        (filterTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = !newBypassState
        filterTabViewButton.needsDisplay = true
        
        btnFilterBypass.image = newBypassState ? UIConstants.imgSwitchOff : UIConstants.imgSwitchOn
    }
    
    @IBAction func eqGlobalGainAction(_ sender: AnyObject) {
        player.setEQGlobalGain(eqGlobalGainSlider.floatValue)
    }
    
    @IBAction func eqSlider32Action(_ sender: AnyObject) {
        player.setEQBand(32, gain: eqSlider32.floatValue)
    }
    
    @IBAction func eqSlider64Action(_ sender: AnyObject) {
        player.setEQBand(64, gain: eqSlider64.floatValue)
    }
    
    @IBAction func eqSlider128Action(_ sender: AnyObject) {
        player.setEQBand(128, gain: eqSlider128.floatValue)
    }
    
    @IBAction func eqSlider256Action(_ sender: AnyObject) {
        player.setEQBand(256, gain: eqSlider256.floatValue)
    }
    
    @IBAction func eqSlider512Action(_ sender: AnyObject) {
        player.setEQBand(512, gain: eqSlider512.floatValue)
    }
    
    @IBAction func eqSlider1kAction(_ sender: AnyObject) {
        player.setEQBand(1024, gain: eqSlider1k.floatValue)
    }
    
    @IBAction func eqSlider2kAction(_ sender: AnyObject) {
        player.setEQBand(2048, gain: eqSlider2k.floatValue)
    }
    
    @IBAction func eqSlider4kAction(_ sender: AnyObject) {
        player.setEQBand(4096, gain: eqSlider4k.floatValue)
    }
    
    @IBAction func eqSlider8kAction(_ sender: AnyObject) {
        player.setEQBand(8192, gain: eqSlider8k.floatValue)
    }
    
    @IBAction func eqSlider16kAction(_ sender: AnyObject) {
        player.setEQBand(16384, gain: eqSlider16k.floatValue)
    }
    
    // Playlist info changed, need to reset the UI
    func consumeEvent(_ event: Event) {
        
        if event is TrackChangedEvent {
//            setSeekTimerState(false)
//            let _event = event as! TrackChangedEvent
//            trackChange(_event.newTrack)
        }
        
        if event is TrackAddedEvent {
            let _evt = event as! TrackAddedEvent
            playlistView.noteNumberOfRowsChanged()
            updatePlaylistSummary(_evt.progress)
        }
        
        if event is TrackNotPlayedEvent {
            let _evt = event as! TrackNotPlayedEvent
//            handleTrackNotPlayedError(_evt.error)
        }
        
        if event is TracksNotAddedEvent {
            let _evt = event as! TracksNotAddedEvent
//            handleTracksNotAddedError(_evt.errors)
        }
        
        if event is StartedAddingTracksEvent {
            startedAddingTracks()
        }
        
        if event is DoneAddingTracksEvent {
            doneAddingTracks()
        }
        
        // Not being used yet (to be used when duration is updated)
        if event is TrackInfoUpdatedEvent {
            let _event = event as! TrackInfoUpdatedEvent
            playlistView.reloadData(forRowIndexes: IndexSet([_event.trackIndex]), columnIndexes: UIConstants.playlistViewColumnIndexes)
        }
    }
    
    @IBAction func recorderAction(_ sender: Any) {
        
        let isRecording: Bool = player.getRecordingInfo() != nil
        
        if (isRecording) {
            stopRecording()
        } else {
            
            // Only AAC format works for now
            player.startRecording(RecordingFormat.aac)
            btnRecord.image = UIConstants.imgRecorderStop
            recorderTimer?.startOrResume()
            lblRecorderDuration.stringValue = UIConstants.zeroDurationString
            lblRecorderFileSize.stringValue = Size.ZERO.toString()
            recordingInfoBox.isHidden = false
            
            (recorderTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = true
            recorderTabViewButton.needsDisplay = true
        }
    }
    
    func stopRecording() {
        
        player.stopRecording()
        btnRecord.image = UIConstants.imgRecord
        recorderTimer?.pause()
        
        (recorderTabViewButton.cell as! EffectsUnitButtonCell).shouldHighlight = false
        recorderTabViewButton.needsDisplay = true
        
        saveRecording()
        recordingInfoBox.isHidden = true
    }
    
    func saveRecording() {
        
        let dialog = UIElements.saveRecordingDialog
        let modalResponse = dialog.runModal()
        
        if (modalResponse == NSModalResponseOK) {
            player.saveRecording(dialog.url!)
        } else {
            player.deleteRecording()
        }
    }
    
    func updateRecordingInfo() {
        
        let recInfo = player.getRecordingInfo()!
        lblRecorderDuration.stringValue = Utils.formatDuration(recInfo.duration)
        lblRecorderFileSize.stringValue = recInfo.fileSize.toString()
    }
    
    // Called by KeyPressHandler to determine if any modal dialog is open
    func modalDialogOpen() -> Bool {
        
//        return searchPanel.isVisible || sortPanel.isVisible || prefsPanel.isVisible || UIElements.openDialog.isVisible || UIElements.savePlaylistDialog.isVisible || UIElements.saveRecordingDialog.isVisible
        
        // TODO: Can the above be done with NSApp.checkIfModalOpen() ???
        
        return false
    }
    
    func dismissModalDialog() {
        NSApp.stopModal()
    }
    
    func filterBassChanged() {
        let filterBassRangeStr = player.setFilterBassBand(Float(filterBassSlider.start), Float(filterBassSlider.end))
        lblFilterBassRange.stringValue = filterBassRangeStr
    }
    
    func filterMidChanged() {
        let filterMidRangeStr = player.setFilterMidBand(Float(filterMidSlider.start), Float(filterMidSlider.end))
        lblFilterMidRange.stringValue = filterMidRangeStr
    }
    
    func filterTrebleChanged() {
        let filterTrebleRangeStr = player.setFilterTrebleBand(Float(filterTrebleSlider.start), Float(filterTrebleSlider.end))
        lblFilterTrebleRange.stringValue = filterTrebleRangeStr
    }
    
    @IBAction func eqTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        eqTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 0)
    }
    
    @IBAction func pitchTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        pitchTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 1)
    }
    
    @IBAction func timeTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        timeTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 2)
    }
    
    @IBAction func reverbTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        reverbTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 3)
    }
    
    @IBAction func delayTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        delayTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 4)
    }
    
    @IBAction func filterTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        filterTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 5)
    }
    
    @IBAction func recorderTabViewAction(_ sender: Any) {
        
        for button in fxTabViewButtons! {
            button.state = 0
        }
        
        recorderTabViewButton.state = 1
        fxTabView.selectTabViewItem(at: 6)
    }

    @IBAction func onlineUserGuideAction(_ sender: Any) {
        NSWorkspace.shared().open(AppConstants.onlineUserGuideURL)
    }
    
    @IBAction func pdfUserGuideAction(_ sender: Any) {
        NSWorkspace.shared().openFile(AppConstants.pdfUserGuidePath)
    }
}

// Int to Bool conversion
extension Bool {
    init<T: Integer>(_ num: T) {
        self.init(num != 0)
    }
}
