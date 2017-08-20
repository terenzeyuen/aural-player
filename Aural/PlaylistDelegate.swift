import Cocoa

class PlaylistDelegate: AuralPlaylistDelegate {
    
    private var playlist: PlaylistCRUD
    private var player: PlaybackControl // ( for play(track) and stop() )
    private var preferences: Preferences
    
    init(_ playlist: PlaylistCRUD, _ player: PlaybackControl, _ preferences: Preferences) {
        self.playlist = playlist
        self.player = player
        self.preferences = preferences
    }
    
    // This method should only be called from outside this class. For adding tracks within this class, always call the private method addFiles_sync().
    func addFiles(_ files: [URL]) {
        
        // Move to a background thread to unblock the main thread
        DispatchQueue.global(qos: .userInteractive).async {
            
            let autoplay: Bool = self.preferences.autoplayAfterAddingTracks
            
            // Progress
            let progress = TrackAddOperationProgress(0, files.count, [InvalidTrackError](), false)
            
            self.addFiles_sync(files, autoplay, progress)
            
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
                                
                                // TODO: Autoplay
//                                self.autoplay(index)
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
    private func notifyTrackAdded(_ trackIndex: Int, _ progress: TrackAddedEventProgress) {
        
        let trackAddedEvent = TrackAddedEvent(trackIndex, progress)
        EventRegistry.publishEvent(.trackAdded, trackAddedEvent)
        
        // TODO: publish message
    }
    
    func removeTrack(_ index: Int) -> Int? {
        playlist.removeTrack()
        
        // TODO: Return playing track index
        // TODO: publish message
        return 0
    }
    
    func moveTrackUp(_ index: Int) -> Int {
        playlist.moveTrackUp(index)
    }
    
    func moveTrackDown(_ index: Int) -> Int {
        playlist.moveTrackDown(index)
    }
    
    func clear() {
        playlist.clear()
        
        // TODO: publish message
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
        return playlist.toggleRepeatMode(repeatMode: repeatMode, shuffleMode: shuffleMode)
    }
    
    func toggleShuffleMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
        return playlist.toggleShuffleMode(repeatMode: repeatMode, shuffleMode: shuffleMode)
    }
}
