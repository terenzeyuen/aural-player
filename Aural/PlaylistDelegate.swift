import Cocoa

class PlaylistDelegate: AuralPlaylistDelegate {
    
    // The current player playlist
    private var playlist: Playlist
    
    func appLoaded() -> UIAppState {
        
        if (preferences.playlistOnStartup == .rememberFromLastAppLaunch) {
            EventRegistry.publishEvent(.startedAddingTracks, StartedAddingTracksEvent.instance)
            loadPlaylistFromSavedState()
        }
        
        return UIAppState(appState, preferences)
    }
    
    // This is called when the app loads initially. Loads the playlist from the app state file on disk. Only meant to be called once.
    private func loadPlaylistFromSavedState() {
        
        // Add tracks async, notifying the UI one at a time
        DispatchQueue.global(qos: .userInteractive).async {
            
            // NOTE - Assume that all entries are valid tracks (supported audio files), not playlists and not directories. i.e. assume that saved state file has not been corrupted.
            
            var errors: [InvalidTrackError] = [InvalidTrackError]()
            let autoplay: Bool = self.preferences.autoplayOnStartup
            var autoplayed: Bool = false
            
            let tracks = self.appState.playlistState.tracks
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
                    try self.addTrack(resolvedFileInfo.resolvedURL, progress)
                    
                    if (autoplay && !autoplayed) {
                        self.autoplay()
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
 
    // This method should only be called from outside this class. For adding tracks within this class, always call the private method addFiles_sync().
    func addFiles(_ files: [URL]) {
        
        // Move to a background thread to unblock the main thread
        DispatchQueue.global(qos: .userInteractive).async {
            
            let autoplayPref: Bool = self.preferences.autoplayAfterAddingTracks
            let alwaysAutoplay: Bool = self.preferences.autoplayAfterAddingOption == .always
            let noPlayingTrack: Bool = self.playingTrack == nil
            
            // Autoplay if the preference is selected AND either the "always" option is selected or no track is currently playing
            let autoplay: Bool = autoplayPref && (alwaysAutoplay || noPlayingTrack)
            
            // Progress
            let progress = TrackAddOperationProgress(0, files.count, [InvalidTrackError](), false)
            
            self.addFiles_sync(files, autoplay, progress)
            
            EventRegistry.publishEvent(.doneAddingTracks, DoneAddingTracksEvent.instance)
            
            // If errors > 0, send event to UI
            if (progress.errors.count > 0) {
                EventRegistry.publishEvent(.tracksNotAdded, TracksNotAddedEvent(progress.errors))
            }
        }
    }
    
    // Adds a bunch of files synchronously
    // The autoplay argument indicates whether or not autoplay is enabled. Make sure to pass it into functions that call back here recursively (addPlaylist() or addDirectory()).
    // The autoplayed argument indicates whether or not autoplay, if enabled, has already been executed. This value is passed by reference so that recursive calls back here will all see the same value.
    private func addFiles_sync(_ files: [URL], _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
        
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
                    addDirectory(file, autoplay, progress)
                    
                } else {
                    
                    // Single file - playlist or track
                    let fileExtension = file.pathExtension.lowercased()
                    
                    if (AppConstants.supportedPlaylistFileTypes.contains(fileExtension)) {
                        
                        // Playlist
                        addPlaylist(file, autoplay, progress)
                        
                    } else if (AppConstants.supportedAudioFileTypes.contains(fileExtension)) {
                        
                        // Track
                        do {
                            
                            progress.tracksAdded += 1
                            
                            let eventProgress = TrackAddedEventProgress(progress.tracksAdded, progress.totalTracks)
                            let index = try addTrack(file, eventProgress)
                            
                            if (autoplay && !progress.autoplayed && index >= 0) {
                                
                                self.autoplay(index)
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
            prepareNextTracksForPlayback()
        }
        return newTrackIndex
    }
    
    private func addPlaylist(_ playlistFile: URL, _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
        
        let loadedPlaylist = PlaylistIO.loadPlaylist(playlistFile)
        if (loadedPlaylist != nil) {
            
            progress.totalTracks -= 1
            progress.totalTracks += (loadedPlaylist?.tracks.count)!
            
            addFiles_sync(loadedPlaylist!.tracks, autoplay, progress)
        }
    }
    
    private func addDirectory(_ dir: URL, _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
        
        let dirContents = FileSystemUtils.getContentsOfDirectory(dir)
        if (dirContents != nil) {
            
            progress.totalTracks -= 1
            progress.totalTracks += (dirContents?.count)!
            
            // Add them
            addFiles_sync(dirContents!, autoplay, progress)
        }
    }
    
    // Publishes a notification that a new track has been added to the playlist
    func notifyTrackAdded(_ trackIndex: Int, _ progress: TrackAddedEventProgress) {
        
        let trackAddedEvent = TrackAddedEvent(trackIndex, progress)
        EventRegistry.publishEvent(.trackAdded, trackAddedEvent)
    }
    
    func removeTrack(_ index: Int) -> Int? {
        
        let removingPlayingTrack: Bool = (index == playlist.cursor())
        playlist.removeTrack(index)
        
        // If the removed track is not the playing track, continue playing !
        if (removingPlayingTrack) {
            stopPlayback()
        }
        
        // Update playing track index (which may have changed)
        playingTrack?.index = playlist.cursor()
        
        if (playlist.size() > 0) {
            prepareNextTracksForPlayback()
        }
        
        return playlist.cursor()
    }
    
    func moveTrackDown(_ index: Int) -> Int {
        
        var newIndex = index
        
        if (index < (playlist.size() - 1)) {
            playlist.shiftTrackDown(index)
            
            // Update playing track index (which may have changed)
            playingTrack?.index = playlist.cursor()
            
            newIndex = index + 1
        }
        
        prepareNextTracksForPlayback()
        return newIndex
    }
    
    func moveTrackUp(_ index: Int) -> Int {
        
        var newIndex = index
        
        if (index > 0) {
            playlist.shiftTrackUp(index)
            
            // Update playing track index (which may have changed)
            playingTrack?.index = playlist.cursor()
            
            newIndex = index - 1
        }
        
        prepareNextTracksForPlayback()
        return newIndex
    }
    
    func clearPlaylist() {
        stopPlayback()
        playlist.clear()
        
        // This may not be needed
        trackPrepQueue.cancelAllOperations()
    }
    
    private func stopPlayback() {
        PlaybackSession.endCurrent()
        player.stop()
        playbackState = .noTrack
        playingTrack = nil
    }
    
    func savePlaylist(_ file: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            PlaylistIO.savePlaylist(file)
        }
    }
    
    func getPlayingTrack() -> IndexedTrack? {
        return playingTrack
    }
    
    func getPlaylistSummary() -> (numTracks: Int, totalDuration: Double) {
        return (playlist.size(), playlist.totalDuration())
    }
    
    
    func searchPlaylist(searchQuery: SearchQuery) -> SearchResults {
        return playlist.searchPlaylist(searchQuery: searchQuery)
    }
    
    func sortPlaylist(sort: Sort) {
        playlist.sortPlaylist(sort: sort)
        
        // Update playing track index (which may have changed)
        playingTrack?.index = playlist.cursor()
        
        prepareNextTracksForPlayback()
    }
}

// Indicates current progress for an operation that adds tracks to the playlist
class TrackAddOperationProgress {
    
    var tracksAdded: Int
    var totalTracks: Int
    var errors: [InvalidTrackError]
    var autoplayed: Bool
    
    init(_ tracksAdded: Int, _ totalTracks: Int, _ errors: [InvalidTrackError], _ autoplayed: Bool) {
        self.tracksAdded = tracksAdded
        self.totalTracks = totalTracks
        self.errors = errors
        self.autoplayed = autoplayed
    }
}
