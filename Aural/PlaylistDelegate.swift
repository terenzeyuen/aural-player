import Cocoa

class PlaylistDelegate: PlaylistDelegateProtocol, MessageSubscriber {
    
    private var playlist: PlaylistCRUD
    private var changeListeners: [PlaylistChangeListener]
    private var player: BasicPlayerDelegateProtocol
    
    private var playlistState: PlaylistState
    private var preferences: Preferences
    
    init(_ playlist: PlaylistCRUD, _ player: BasicPlayerDelegateProtocol, _ changeListeners: [PlaylistChangeListener], _ playlistState: PlaylistState, _ preferences: Preferences) {
        
        self.playlist = playlist
        self.player = player
        self.changeListeners = changeListeners
        
        self.playlistState = playlistState
        self.preferences = preferences
        
        SyncMessenger.subscribe(.appLoadedNotification, subscriber: self)
        SyncMessenger.subscribe(.appExitNotification, subscriber: self)
    }
    
    // This is called when the app loads initially. Loads the playlist from the app state file on disk. Only meant to be called once.
    private func loadPlaylist() {
        
        if (preferences.playlistOnStartup == .rememberFromLastAppLaunch) {
            
            EventRegistry.publishEvent(.startedAddingTracks, StartedAddingTracksEvent.instance)
            
            // Add tracks async, notifying the UI one at a time
            DispatchQueue.global(qos: .userInteractive).async {
                
                // NOTE - Assume that all entries are valid tracks (supported audio files), not playlists and not directories. i.e. assume that saved state file has not been corrupted.
                
                var errors: [InvalidTrackError] = [InvalidTrackError]()
                let autoplay: Bool = self.preferences.autoplayOnStartup
                var autoplayed: Bool = false
                
                let tracks = self.playlistState.tracks
                let totalTracks = tracks.count
                var tracksAdded = 0
                
                for trackPath in tracks {
                    
                    tracksAdded += 1
                    
                    // Playlists might contain broken file references
                    if (!FileSystemUtils.fileExists(trackPath)) {
                        errors.append(FileNotFoundError(URL(fileURLWithPath: trackPath)))
                        continue
                    }
                    
                    let resolvedFileInfo = FileSystemUtils.resolveTruePath(URL(fileURLWithPath: trackPath))
                    
                    do {
                        
                        let progress = TrackAddedEventProgress(tracksAdded, totalTracks)
                        let index = try self.addTrack(resolvedFileInfo.resolvedURL, progress)
                        
                        if (autoplay && !autoplayed) {
                            self.autoplay(index, false)
                            autoplayed = true
                        }
                        
                    } catch let error as Error {
                        
                        if (error is InvalidTrackError) {
                            errors.append(error as! InvalidTrackError)
                        }
                    }
                }
                
                EventRegistry.publishEvent(.doneAddingTracks, DoneAddingTracksEvent.instance)
                
                // If errors > 0, send event to UI
                if (errors.count > 0) {
                    EventRegistry.publishEvent(.tracksNotAdded, TracksNotAddedEvent(errors))
                }
            }
        }
    }
    
    func autoplay(_ trackIndex: Int, _ interruptPlayingTrack: Bool) {
        
        DispatchQueue.main.async {
            self.player.play(trackIndex, interruptPlayingTrack)
        }
    }
    
    
    // This method should only be called from outside this class. For adding tracks within this class, always call the private method addFiles_sync().
    func addFiles(_ files: [URL]) {
        
        // Move to a background thread to unblock the main thread
        DispatchQueue.global(qos: .userInteractive).async {
            
            let autoplay: Bool = self.preferences.autoplayAfterAddingTracks
            let interruptPlayback: Bool = self.preferences.autoplayAfterAddingOption == .always
            
            // Progress
            let progress = TrackAddOperationProgress(0, files.count, [InvalidTrackError](), false)
            
            self.addFiles_sync(files, autoplay, interruptPlayback, progress)
            
            EventRegistry.publishEvent(.doneAddingTracks, DoneAddingTracksEvent.instance)
            
            // If errors > 0, send event to UI
            if (progress.errors.count > 0) {
                EventRegistry.publishEvent(.tracksNotAdded, TracksNotAddedEvent(progress.errors))
            }
            
            // TODO: Autoplay
        }
    }
    
    // Adds a bunch of files synchronously
    // The autoplay argument indicates whether or not autoplay is enabled. Make sure to pass it into functions that call back here recursively (addPlaylist() or addDirectory()).
    // The autoplayed argument indicates whether or not autoplay, if enabled, has already been executed. This value is passed by reference so that recursive calls back here will all see the same value.
    private func addFiles_sync(_ files: [URL], _ autoplay: Bool, _ interruptPlayback: Bool, _ progress: TrackAddOperationProgress) {
        
        if (files.count > 0) {
            
            for _file in files {
                
                // Playlists might contain broken file references
                if (!FileSystemUtils.fileExists(_file)) {
                    progress.errors.append(FileNotFoundError(_file))
                    continue
                }
                
                // Always resolve sym links and aliases before reading the file
                let resolvedFileInfo = FileSystemUtils.resolveTruePath(_file)
                let file = resolvedFileInfo.resolvedURL
                
                if (resolvedFileInfo.isDirectory) {
                    
                    // Directory
                    addDirectory(file, autoplay, interruptPlayback, progress)
                    
                } else {
                    
                    // Single file - playlist or track
                    let fileExtension = file.pathExtension.lowercased()
                    
                    if (AppConstants.supportedPlaylistFileTypes.contains(fileExtension)) {
                        
                        // Playlist
                        addPlaylist(file, autoplay, interruptPlayback, progress)
                        
                    } else if (AppConstants.supportedAudioFileTypes.contains(fileExtension)) {
                        
                        // Track
                        do {
                            
                            progress.tracksAdded += 1
                            
                            let eventProgress = TrackAddedEventProgress(progress.tracksAdded, progress.totalTracks)
                            let index = try addTrack(file, eventProgress)
                            
                            if (autoplay && !progress.autoplayed && index >= 0) {
                                
                                self.autoplay(index, interruptPlayback)
                                progress.autoplayed = true
                            }
                            
                        }  catch let error as Error {
                            
                            if (error is InvalidTrackError) {
                                progress.errors.append(error as! InvalidTrackError)
                            }
                        }
                        
                    } else {
                        
                        // Unsupported file type, ignore
                        NSLog("Ignoring unsupported file: %@", file.path)
                    }
                }
            }
        }
    }
    
    // Returns index of newly added track
    private func addTrack(_ file: URL, _ progress: TrackAddedEventProgress) throws -> Int {
        
        let newTrackIndex = try playlist.addTrack(file)
        if (newTrackIndex >= 0) {
            notifyTrackAdded(newTrackIndex, progress)
        }
        return newTrackIndex
    }
    
    private func addPlaylist(_ playlistFile: URL, _ autoplay: Bool, _ interruptPlayback: Bool, _ progress: TrackAddOperationProgress) {
        
        let loadedPlaylist = PlaylistIO.loadPlaylist(playlistFile)
        if (loadedPlaylist != nil) {
            
            progress.totalTracks -= 1
            progress.totalTracks += (loadedPlaylist?.tracks.count)!
            
            addFiles_sync(loadedPlaylist!.tracks, autoplay, interruptPlayback, progress)
        }
    }
    
    private func addDirectory(_ dir: URL, _ autoplay: Bool, _ interruptPlayback: Bool, _ progress: TrackAddOperationProgress) {
        
        let dirContents = FileSystemUtils.getContentsOfDirectory(dir)
        if (dirContents != nil) {
            
            progress.totalTracks -= 1
            progress.totalTracks += (dirContents?.count)!
            
            // Add them
            addFiles_sync(dirContents!, autoplay, interruptPlayback, progress)
        }
    }
    
    // Publishes a notification that a new track has been added to the playlist
    private func notifyTrackAdded(_ trackIndex: Int, _ progress: TrackAddedEventProgress) {
        
        let trackAddedEvent = TrackAddedEvent(trackIndex, progress)
        EventRegistry.publishEvent(.trackAdded, trackAddedEvent)
        
        // TODO: publish message
    }
    
    func removeTrack(_ index: Int) {
        playlist.removeTrack(index)
        for listener in changeListeners {
            listener.trackRemoved(index)
        }
    }
    
    func moveTrackUp(_ index: Int) -> Int {
        
        var newIndex = playlist.moveTrackUp(index)
            
        if (newIndex != index) {
            
            for listener in changeListeners {
                listener.trackReordered(index, newIndex)
            }
        }
        
        return newIndex
    }
    
    func moveTrackDown(_ index: Int) -> Int {
        
        let newIndex = playlist.moveTrackDown(index)
        
        if (newIndex != index) {
            
            for listener in changeListeners {
                listener.trackReordered(index, newIndex)
            }
        }
        
        return newIndex
    }
    
    func clear() {
        
        playlist.clear()
        player.stop()
    }
    
    func save(_ file: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            PlaylistIO.savePlaylist(file)
        }
    }
    
    func getSummary() -> (numTracks: Int, totalDuration: Double) {
        return (playlist.size(), playlist.totalDuration())
    }
    
    func search(searchQuery: SearchQuery) -> SearchResults {
        return playlist.search(searchQuery)
    }
    
    func sort(sort: Sort) {
        playlist.sort(sort)
    }
    
    func toggleRepeatMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
        return playlist.toggleRepeatMode()
    }
    
    func toggleShuffleMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
        return playlist.toggleShuffleMode()
    }
    
    func getPlayingTrack() -> IndexedTrack? {
        return playlist.getPlayingTrack()
    }
    
    func consumeMessage(_ message: Message) {
        
        if (message is AppLoadedNotification) {
            loadPlaylist()
        }
        
        if (message is AppExitNotification) {
            savePlaylistState()
        }
    }
    
    private func savePlaylistState() {
        
        let appState = ObjectGraph.getAppState()
        
        let playlistState = playlist.getPersistentState()
        appState.playlistState = playlistState
    }
}
