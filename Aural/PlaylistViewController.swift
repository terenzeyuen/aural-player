import Cocoa

class PlaylistViewController: NSViewController, EventSubscriber, MessageSubscriber {
    
    @IBOutlet weak var window: NSWindow!
    
    private let delegate: AuralPlaylistDelegate = AppInitializer.getPlaylistControlDelegate()
    
    // Displays the playlist and summary
    @IBOutlet weak var playlistView: NSTableView!
    @IBOutlet weak var lblPlaylistSummary: NSTextField!
    @IBOutlet weak var playlistWorkSpinner: NSProgressIndicator!
    
    @IBOutlet weak var btnShuffle: NSButton!
    @IBOutlet weak var btnRepeat: NSButton!
    
    // Search modal dialog fields
    @IBOutlet weak var searchPanel: NSPanel!
    
    @IBOutlet weak var searchField: ColoredCursorSearchField!
    
    @IBOutlet weak var searchResultsSummaryLabel: NSTextField!
    @IBOutlet weak var searchResultMatchInfo: NSTextField!
    
    @IBOutlet weak var btnNextSearch: NSButton!
    @IBOutlet weak var btnPreviousSearch: NSButton!
    
    @IBOutlet weak var searchByName: NSButton!
    @IBOutlet weak var searchByArtist: NSButton!
    @IBOutlet weak var searchByTitle: NSButton!
    @IBOutlet weak var searchByAlbum: NSButton!
    
    @IBOutlet weak var comparisonTypeContains: NSButton!
    @IBOutlet weak var comparisonTypeEquals: NSButton!
    @IBOutlet weak var comparisonTypeBeginsWith: NSButton!
    @IBOutlet weak var comparisonTypeEndsWith: NSButton!
    
    @IBOutlet weak var searchCaseSensitive: NSButton!
    
    // Sort modal dialog fields
    @IBOutlet weak var sortPanel: NSPanel!
    
    @IBOutlet weak var sortByName: NSButton!
    @IBOutlet weak var sortByDuration: NSButton!
    
    @IBOutlet weak var sortAscending: NSButton!
    @IBOutlet weak var sortDescending: NSButton!
    
    // Current playlist search results
    var searchResults: SearchResults?
    
    override func viewDidLoad() {
        
        print("DILLON !!! YOUUUUUUUUUUUUUU SON OF A BITCH !")
        
        let appState = AppInitializer.getUIAppState()
        
        // Enable drag n drop into the playlist view
        playlistView.register(forDraggedTypes: [String(kUTTypeFileURL)])
        
        searchPanel.titlebarAppearsTransparent = true
        sortPanel.titlebarAppearsTransparent = true
        
        switch appState.repeatMode {
            
            case .off: btnRepeat.image = UIConstants.imgRepeatOff
            case .one: btnRepeat.image = UIConstants.imgRepeatOne
            case .all: btnRepeat.image = UIConstants.imgRepeatAll
            
        }
        
        switch appState.shuffleMode {
            
            case .off: btnShuffle.image = UIConstants.imgShuffleOff
            case .on: btnShuffle.image = UIConstants.imgShuffleOn
            
        }
        
        // Register self as a subscriber to various event notifications
        EventRegistry.subscribe(.trackChanged, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.trackAdded, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.trackNotPlayed, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.tracksNotAdded, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.startedAddingTracks, subscriber: self, dispatchQueue: DispatchQueue.main)
        EventRegistry.subscribe(.doneAddingTracks, subscriber: self, dispatchQueue: DispatchQueue.main)
        
        // Register self as a subscriber to various message notifications
        UIMessenger.subscribe(.trackChangedNotification, subscriber: self)
    }
    
    @IBAction func addAction(_ sender: Any) {
        
        let selRow = playlistView.selectedRow
        let dialog = UIElements.openDialog
        
        let modalResponse = dialog.runModal()
        
        if (modalResponse == NSModalResponseOK) {
            addFiles(dialog.urls)
        }
        
        selectTrack(selRow)
    }
    
    func addFiles(_ files: [URL]) {
       // TODO startedAddingTracks()
        delegate.addFiles(files)
    }
    
    @IBAction func removeAction(_ sender: Any) {
        removeSingleTrack(playlistView.selectedRow)
    }
    
    func removeSingleTrack(_ index: Int) {
        
        if (index >= 0) {
            
            let newPlayingTrackIndex = delegate.removeTrack(index)
            
            // The new number of rows (after track removal) is one less than the size of the playlist view, because the view has not yet been updated
            let numRows = playlistView.numberOfRows - 1
            
            if (numRows > index) {
                
                // Update all rows from the selected row down to the end of the playlist
                let rowIndexes = IndexSet(index...(numRows - 1))
                playlistView.reloadData(forRowIndexes: rowIndexes, columnIndexes: UIConstants.playlistViewColumnIndexes)
            }
            
            // Tell the playlist view to remove one row
            playlistView.noteNumberOfRowsChanged()
            
            updatePlaylistSummary()
            selectTrack(newPlayingTrackIndex)
            
            if (newPlayingTrackIndex == nil) {
//                clearNowPlayingInfo()
            }
        }
        
        showPlaylistSelectedRow()
    }
    
    // If tracks are currently being added to the playlist, the optional progress argument contains progress info that the spinner control uses for its animation
    func updatePlaylistSummary(_ trackAddProgress: TrackAddedEventProgress? = nil) {
        
        let summary = delegate.getPlaylistSummary()
        let numTracks = summary.numTracks
        
        lblPlaylistSummary.stringValue = String(format: "%d %@   %@", numTracks, numTracks == 1 ? "track" : "tracks", Utils.formatDuration(summary.totalDuration))
        
        // TODO Update spinner
        if (trackAddProgress != nil) {
            repositionSpinner()
            playlistWorkSpinner.doubleValue = trackAddProgress!.percentage
        }
    }
    
    @IBAction func saveAction(_ sender: Any) {
        
        // Make sure there is at least one track to save
        if (playlistView.numberOfRows > 0) {
            
            let dialog = UIElements.savePlaylistDialog
            
            let modalResponse = dialog.runModal()
            
            if (modalResponse == NSModalResponseOK) {
                
                let file = dialog.url
                delegate.savePlaylist(file!)
            }
        }
    }
    
    @IBAction func upAction(_ sender: Any) {
        
        print("Samimuthu")
        
        let curSelectedRow = playlistView.selectedRow
        if (curSelectedRow < 1) {
            return
        }
        
        let newSelectedRow = delegate.moveTrackUp(curSelectedRow)
        swapRows(curSelectedRow, newSelectedRow, newSelectedRow)
        showPlaylistSelectedRow()
    }
    
    @IBAction func downAction(_ sender: Any) {
        
        print("Samimuthupapa")
        
        let curSelectedRow = playlistView.selectedRow
        if (curSelectedRow >= playlistView.numberOfRows - 1) {
            return
        }
        
        let newSelectedRow = delegate.moveTrackDown(curSelectedRow)
        swapRows(curSelectedRow, newSelectedRow, newSelectedRow)
        showPlaylistSelectedRow()
    }
    
    private func swapRows(_ row1: Int, _ row2: Int, _ newSelectedRow: Int) {
        
        // Reload data in the two affected rows
        let rowIndexes = IndexSet([row1, row2])
        playlistView.reloadData(forRowIndexes: rowIndexes, columnIndexes: UIConstants.playlistViewColumnIndexes)
        playlistView.selectRowIndexes(IndexSet(integer: newSelectedRow), byExtendingSelection: false)
    }
    
    @IBAction func clearAction(_ sender: Any) {
        
        print("Papasami")
        
        delegate.clearPlaylist()
        playlistView.reloadData()
        
        UIMessenger.publishMessage(StopPlaybackRequest.instance)
    }
    
    func selectTrack(_ index: Int?) {
        
        if index != nil && index! >= 0 {
            
            playlistView.selectRowIndexes(IndexSet(integer: index!), byExtendingSelection: false)
            showPlaylistSelectedRow()
            
        } else {
            // Select first track in list, if list not empty
            if (playlistView.numberOfRows > 0) {
                
                playlistView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }
    
    func showPlaylistSelectedRow() {
        if (playlistView.numberOfRows > 0) {
            playlistView.scrollRowToVisible(playlistView.selectedRow)
        }
    }
    
    @IBAction func addFilesMenuItemAction(_ sender: Any) {
        addAction(sender as AnyObject)
    }
    
    @IBAction func savePlaylistMenuItemAction(_ sender: Any) {
        saveAction(sender as AnyObject)
    }
    
    @IBAction func playSelectedTrackMenuItemAction(_ sender: Any) {
        playSelectedTrack()
    }
    
    @IBAction func moveTrackUpMenuItemAction(_ sender: Any) {
        upAction(sender as AnyObject)
    }
    
    @IBAction func moveTrackDownMenuItemAction(_ sender: Any) {
        downAction(sender as AnyObject)
    }
    
    @IBAction func removeTrackMenuItemAction(_ sender: Any) {
        removeAction(sender as AnyObject)
    }
    
    @IBAction func clearPlaylistMenuItemAction(_ sender: Any) {
        clearAction(sender as AnyObject)
    }
    
    @IBAction func repeatAction(_ sender: AnyObject) {
        
        let modes = delegate.toggleRepeatMode()
        
        switch modes.repeatMode {
            
        case .off: btnRepeat.image = UIConstants.imgRepeatOff
        case .one: btnRepeat.image = UIConstants.imgRepeatOne
        case .all: btnRepeat.image = UIConstants.imgRepeatAll
            
        }
        
        switch modes.shuffleMode {
            
        case .off: btnShuffle.image = UIConstants.imgShuffleOff
        case .on: btnShuffle.image = UIConstants.imgShuffleOn
            
        }
    }
    
    @IBAction func shuffleAction(_ sender: AnyObject) {
        
        let modes = delegate.toggleShuffleMode()
        
        switch modes.shuffleMode {
            
        case .off: btnShuffle.image = UIConstants.imgShuffleOff
        case .on: btnShuffle.image = UIConstants.imgShuffleOn
            
        }
        
        switch modes.repeatMode {
            
        case .off: btnRepeat.image = UIConstants.imgRepeatOff
        case .one: btnRepeat.image = UIConstants.imgRepeatOne
        case .all: btnRepeat.image = UIConstants.imgRepeatAll
            
        }
    }
    
    @IBAction func toggleRepeatModeMenuItemAction(_ sender: Any) {
        repeatAction(sender as AnyObject)
    }
    
    @IBAction func toggleShuffleModeMenuItemAction(_ sender: Any) {
        shuffleAction(sender as AnyObject)
    }
    
    
    @IBAction func searchPlaylistAction(_ sender: Any) {
        
        // Don't do anything if no tracks in playlist
        if (playlistView.numberOfRows == 0) {
            return
        }
        
        // Position the search modal dialog and show it
        let searchFrameOrigin = NSPoint(x: window.frame.origin.x + 16, y: min(window.frame.origin.y + 227, window.frame.origin.y + window.frame.height - searchPanel.frame.height))
        
        searchField.stringValue = ""
        resetSearchFields()
        
        searchPanel.setFrameOrigin(searchFrameOrigin)
        searchPanel.setIsVisible(true)
        
        searchPanel.makeFirstResponder(searchField)
        
        NSApp.runModal(for: searchPanel)
        searchPanel.close()
    }
    
    // Called when any of the search criteria have changed, performs a new search
    func searchQueryChanged() {
        
        let searchText = searchField.stringValue
        
        if (searchText == "") {
            resetSearchFields()
            return
        }
        
        let searchFields = SearchFields()
        searchFields.name = Bool(searchByName.state)
        searchFields.artist = Bool(searchByArtist.state)
        searchFields.title = Bool(searchByTitle.state)
        searchFields.album = Bool(searchByAlbum.state)
        
        // No fields to compare, don't do the search
        if (searchFields.noFieldsSelected()) {
            resetSearchFields()
            return
        }
        
        let searchOptions = SearchOptions()
        searchOptions.caseSensitive = Bool(searchCaseSensitive.state)
        
        let query = SearchQuery(text: searchText)
        query.fields = searchFields
        query.options = searchOptions
        
        if (comparisonTypeEquals.state == 1) {
            query.type = .equals
        } else if (comparisonTypeContains.state == 1) {
            query.type = .contains
        } else if (comparisonTypeBeginsWith.state == 1) {
            query.type = .beginsWith
        } else {
            query.type = .endsWith
        }
        
        searchResults = delegate.searchPlaylist(searchQuery: query)
        
        if ((searchResults?.count)! > 0) {
            
            // Show the first result
            nextSearchAction(self)
            
        } else {
            resetSearchFields()
        }
    }
    
    func resetSearchFields() {
        
        if (searchField.stringValue.isEmpty) {
            searchResultsSummaryLabel.stringValue = "No results"
        } else {
            searchResultsSummaryLabel.stringValue = "No results found"
        }
        searchResultMatchInfo.stringValue = ""
        btnNextSearch.isHidden = true
        btnPreviousSearch.isHidden = true
    }
    
    // Iterates to the previous search result
    @IBAction func previousSearchAction(_ sender: Any) {
        updateSearchPanelWithResult(searchResult: (searchResults?.previous())!)
    }
    
    // Iterates to the next search result
    @IBAction func nextSearchAction(_ sender: Any) {
        updateSearchPanelWithResult(searchResult: (searchResults?.next())!)
    }
    
    // Updates displayed search results info with the current search result
    func updateSearchPanelWithResult(searchResult: SearchResult) {
        
        // Select the track in the playlist view, to show the user where the track is
        //        selectTrack(searchResult.index)
        
        let resultsText = (searchResults?.count)! == 1 ? "result found" : "results found"
        searchResultsSummaryLabel.stringValue = String(format: "%d %@. Selected %d / %d", (searchResults?.count)!, resultsText, (searchResults?.cursor)! + 1, (searchResults?.count)!)
        
        searchResultMatchInfo.stringValue = String(format: "Matched %@: '%@'", searchResult.match.fieldKey.lowercased(), searchResult.match.fieldValue)
        
        btnNextSearch.isHidden = !searchResult.hasNext
        btnPreviousSearch.isHidden = !searchResult.hasPrevious
    }
    
    @IBAction func searchDoneAction(_ sender: Any) {
        dismissModalDialog()
    }
    
    @IBAction func searchPlaylistMenuItemAction(_ sender: Any) {
        searchPlaylistAction(sender)
    }
    
    @IBAction func searchQueryChangedAction(_ sender: Any) {
        searchQueryChanged()
    }
    
    @IBAction func sortPlaylistAction(_ sender: Any) {
        
        // Don't do anything if no tracks in playlist
        if (playlistView.numberOfRows == 0) {
            return
        }
        
        // Position the sort modal dialog and show it
        let sortFrameOrigin = NSPoint(x: window.frame.origin.x + 73, y: min(window.frame.origin.y + 227, window.frame.origin.y + window.frame.height - sortPanel.frame.height))
        
        sortPanel.setFrameOrigin(sortFrameOrigin)
        sortPanel.setIsVisible(true)
        
        NSApp.runModal(for: sortPanel)
        sortPanel.close()
    }
    
    @IBAction func sortOptionsChangedAction(_ sender: Any) {
        // Do nothing ... this action function is just to get the radio button groups to work
    }
    
    @IBAction func performSortAction(_ sender: Any) {
        
        // Gather field values
        let sortOptions = Sort()
        sortOptions.field = sortByName.state == 1 ? SortField.name : SortField.duration
        sortOptions.order = sortAscending.state == 1 ? SortOrder.ascending : SortOrder.descending
        
        delegate.sortPlaylist(sort: sortOptions)
        dismissModalDialog()
        
        playlistView.reloadData()
        //        selectTrack(player.getPlayingTrack()?.index)
        //        showPlaylistSelectedRow()
    }
    
    @IBAction func cancelSortAction(_ sender: Any) {
        dismissModalDialog()
    }
    
    func dismissModalDialog() {
        NSApp.stopModal()
    }
    
    @IBAction func sortPlaylistMenuItemAction(_ sender: Any) {
        sortPlaylistAction(sender)
    }
    
    func startedAddingTracks() {
        playlistWorkSpinner.doubleValue = 0
        repositionSpinner()
        playlistWorkSpinner.isHidden = false
        playlistWorkSpinner.startAnimation(self)
    }
    
    func doneAddingTracks() {
        playlistWorkSpinner.stopAnimation(self)
        playlistWorkSpinner.isHidden = true
    }
    
    // Move the spinner so it is adjacent to the summary text, on the left
    func repositionSpinner() {
        
        let summaryString: NSString = lblPlaylistSummary.stringValue as NSString
        let size: CGSize = summaryString.size(withAttributes: [NSFontAttributeName: lblPlaylistSummary.font as AnyObject])
        let lblWidth = size.width
        
        let newX = 381 - lblWidth - 10 - playlistWorkSpinner.frame.width
        playlistWorkSpinner.frame.origin.x = newX
    }
    
    @IBAction func playlistDoubleClickAction(_ sender: Any) {
        
        print("YEAH ... I LIKE THAT !")
        playSelectedTrack()
    }
    
//    func playlistDoubleClickAction(_ sender: AnyObject) {
//        
//    }
    
    func playSelectedTrack() {
        
        let selRow = playlistView.selectedRow
        
        if (selRow >= 0) {
            let trackPlaybackRequest = TrackPlaybackRequest(selRow)
            UIMessenger.publishMessage(trackPlaybackRequest)
        }
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
        }
        
        if event is TracksNotAddedEvent {
            let _evt = event as! TracksNotAddedEvent
//                        handleTracksNotAddedError(_evt.errors)
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
    
    func consumeMessage(_ message: Message) {
        
        if message is TrackChangedNotification {
            
            let _msg = message as! TrackChangedNotification
            let newTrack = _msg.newTrack
            let index = newTrack?.index
            selectTrack(index)
        }
    }
    
    func handleTrackNotPlayedError(_ error: InvalidTrackError) {
        
        // This needs to be done async. Otherwise, other open dialogs could hang.
        DispatchQueue.main.async {
            
            // First, select the problem track and update the now playing info
//            let playingTrack = self.delegate.getPlayingTrack()
////            self.trackChange(playingTrack, true)
//            let playingTrackIndex = playingTrack!.index!
//            self.removeSingleTrack(playingTrackIndex)
        }
    }
    
    func handleTracksNotAddedError(_ errors: [InvalidTrackError]) {
        
        // This needs to be done async. Otherwise, the add files dialog hangs.
        DispatchQueue.main.async {
            
            let alert = UIElements.tracksNotAddedAlertWithErrors(errors)
            
//            let orig = NSPoint(x: self.window.frame.origin.x, y: min(self.window.frame.origin.y + 227, self.window.frame.origin.y + self.window.frame.height - alert.window.frame.height))
//            
//            alert.window.setFrameOrigin(orig)
            alert.window.setIsVisible(true)
            
            alert.runModal()
        }
    }
}
