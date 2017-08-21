/*
 Encapsulates all track information of a playlist. Contains logic to determine playback order for different modes (repeat, shuffle, etc).
 */

import Foundation
import AVFoundation

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

class Playlist: PlaybackSequenceAccessor, PlaylistCRUD, PlaylistAccessor {
    
    private var tracks: [Track] = [Track]()
    private var tracksByFilename: [String: Track] = [String: Track]()
    
    // The playback sequence associated with this playlist
    private var playbackSequence: PlaybackSequence
    
    init(_ repeatMode: RepeatMode, _ shuffleMode: ShuffleMode) {
        playbackSequence = PlaybackSequence(0, repeatMode, shuffleMode)
    }
    
    // ---------------------------------- BEGIN CRUD methods ----------------------------------
    
    // Add a track to this playlist and return its index
    // Assume valid existing and supported file
    func addTrack(_ file: URL) throws -> Int {
        
        if (!trackExists(file.path)) {
            
            let track: Track = try TrackIO.loadTrack(file)
            tracks.append(track)
            tracksByFilename[file.path] = track
            playbackSequence.trackAdded()
            return tracks.count - 1
        }
        
        // This means nothing was added
        return -1
    }
    
    func trackExists(_ filename: String) -> Bool {
        return tracksByFilename[filename] != nil
    }
    
    func removeTrack(_ index: Int) {
        
        let track: Track? = tracks[index]
        
        if (track != nil) {
            tracksByFilename.removeValue(forKey: track!.file!.path)
            tracks.remove(at: index)
            playbackSequence.trackRemoved(index)
        }
    }
    
    func clear() {
        tracks.removeAll()
        tracksByFilename.removeAll()
        playbackSequence.playlistCleared()
    }
    
    
    // Shifts a single track up in the playlist order
    func moveTrackUp(_ index: Int) -> Int {
        
        if (index > 0) {
            let upIndex = index - 1
            swapTracks(index, upIndex)
            playbackSequence.trackReordered(index, upIndex)
            
            return upIndex
        }
        
        return index
    }
    
    // Shifts a single track down in the playlist order
    func moveTrackDown(_ index: Int) -> Int {
        
        if (index < (tracks.count - 1)) {
            let downIndex = index + 1
            swapTracks(index, downIndex)
            playbackSequence.trackReordered(index, downIndex)
            
            return downIndex
        }
        
        return index
    }
    
    // Swaps two tracks in the array of tracks
    private func swapTracks(_ trackIndex1: Int, _ trackIndex2: Int) {
        swap(&tracks[trackIndex1], &tracks[trackIndex2])
    }
    
    func toggleRepeatMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
        return playbackSequence.toggleRepeatMode()
    }
    
    func toggleShuffleMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
        return playbackSequence.toggleShuffleMode()
    }
    
    // Searches the playlist for all tracks matching the specified criteria, and returns a set of results
    func search(_ searchQuery: SearchQuery) -> SearchResults {
        
        var results: [SearchResult] = [SearchResult]()
        
        for i in 0...tracks.count - 1 {
            
            let track = tracks[i]
            let match = trackMatchesQuery(track: track, searchQuery: searchQuery)
            
            if (match.matched) {
                results.append(SearchResult(index: i, match: (match.matchedField!, match.matchedFieldValue!)))
            }
        }
        
        return SearchResults(results: results)
    }
    
    // Checks if a single track matches search criteria, returns information about the match, if there is one
    private func trackMatchesQuery(track: Track, searchQuery: SearchQuery) -> (matched: Bool, matchedField: String?, matchedFieldValue: String?) {
        
        let caseSensitive: Bool = searchQuery.options.caseSensitive
        
        let queryText: String = caseSensitive ? searchQuery.text : searchQuery.text.lowercased()
        
        // Actual track fields to compare to query text
        // FieldName -> (OriginalFieldValue, FieldValueForComparison)
        // FieldValueForComparison is used for the comparison (and may have different case than OriginalFieldValue), while OriginalFieldValue is returned in the result if there is a match
        var trackFields: [String: (original: String, compared: String)] = [String: (String, String)]()
        
        // Add name field if included in search
        if (searchQuery.fields.name) {
            
            // Check both the filename and the display name
            
            let lastPathComponent = track.file!.deletingPathExtension().lastPathComponent
            
            trackFields["Filename"] = (lastPathComponent, caseSensitive ? lastPathComponent : lastPathComponent.lowercased())
            
            let displayName = track.shortDisplayName!
            trackFields["Name"] = (displayName, caseSensitive ? displayName : displayName.lowercased())
        }
        
        // Add artist field if included in search
        if (searchQuery.fields.artist) {
            
            if let artist = track.metadata?.artist {
                trackFields["Artist"] = (artist, caseSensitive ? artist : artist.lowercased())
            }
        }
        
        // Add title field if included in search
        if (searchQuery.fields.title) {
            
            if let title = track.metadata?.title {
                trackFields["Title"] = (title, caseSensitive ? title : title.lowercased())
            }
        }
        
        // Add album field if included in search
        if (searchQuery.fields.album) {
            
            // Make sure album info has been loaded (it is loaded lazily)
            TrackIO.loadExtendedMetadataForSearch(track)
            
            if let album = track.extendedMetadata["albumName"] {
                trackFields["Album"] = (album, caseSensitive ? album : album.lowercased())
            }
        }
        
        // Check each field value against the search query text
        for (key: field, value: (original: original, compared: compared)) in trackFields {
            
            switch searchQuery.type {
                
            case .beginsWith: if compared.hasPrefix(queryText) {
                return (true, field, original)
                }
                
            case .endsWith: if compared.hasSuffix(queryText) {
                return (true, field, original)
                }
                
            case .equals: if compared == queryText {
                return (true, field, original)
                }
                
            case .contains: if compared.range(of: queryText) != nil {
                return (true, field, original)
                }
            }
        }
        
        // Didn't match
        return (false, nil, nil)
    }
    
    func sort(_ sort: Sort) {
        
        let playingTrack = getPlayingTrack()
        
        switch sort.field {
            
        // Sort by name
        case .name: if sort.order == SortOrder.ascending {
            tracks.sort(by: compareTracks_ascendingByName)
        } else {
            tracks.sort(by: compareTracks_descendingByName)
            }
            
        // Sort by duration
        case .duration: if sort.order == SortOrder.ascending {
            tracks.sort(by: compareTracks_ascendingByDuration)
        } else {
            tracks.sort(by: compareTracks_descendingByDuration)
            }
        }
        
        if (playingTrack != nil) {
            playbackSequence.playlistReordered(indexOf(playingTrack!.track))
        } else {
            playbackSequence.playlistReordered(nil)
        }
    }
    
    private func indexOf(_ track: Track?) -> Int?  {
        if (track == nil) {
            return nil
        }
        
        return tracks.index(where: {$0 == track})
    }
    
    // Comparison functions for different sort criteria
    
    private func compareTracks_ascendingByName(aTrack: Track, anotherTrack: Track) -> Bool {
        return aTrack.shortDisplayName?.compare(anotherTrack.shortDisplayName!) == ComparisonResult.orderedAscending
    }
    
    private func compareTracks_descendingByName(aTrack: Track, anotherTrack: Track) -> Bool {
        return aTrack.shortDisplayName?.compare(anotherTrack.shortDisplayName!) == ComparisonResult.orderedDescending
    }
    
    private func compareTracks_ascendingByDuration(aTrack: Track, anotherTrack: Track) -> Bool {
        return aTrack.duration! < anotherTrack.duration!
    }
    
    private func compareTracks_descendingByDuration(aTrack: Track, anotherTrack: Track) -> Bool {
        return aTrack.duration! > anotherTrack.duration!
    }
    
    func isEmpty() -> Bool {
        return tracks.count == 0
    }
    
    func size() -> Int {
        return tracks.count
    }
    
    func totalDuration() -> Double {
        
        var totalDuration: Double = 0
        
        for track in tracks {
            totalDuration += track.duration!
        }
        
        return totalDuration
    }
    
    func getPersistentState() -> PlaylistState {
        
        let state = PlaylistState()
        state.repeatMode = self.playbackSequence.repeatMode
        state.shuffleMode = self.playbackSequence.shuffleMode
        
        for track in tracks {
            state.tracks.append(track.file!.path)
        }
        
        return state
    }
    
    // ---------------------------------- END CRUD methods ----------------------------------
    
    // ---------------------------------- BEGIN sequence accessor methods ----------------------------------
    
    // Determines which track will play next if subsequentTrack() is invoked, if any. This is used to eagerly prep tracks for future playback. Nil return value indicates no track.
    func peekSubsequentTrack() -> IndexedTrack? {
        let continueIndex = playbackSequence.peekContinuePlaying()
        return continueIndex == nil ? nil : IndexedTrack(tracks[continueIndex!], continueIndex)
    }
    
    func subsequentTrack() -> IndexedTrack? {
        let continueIndex = playbackSequence.continuePlaying()
        return continueIndex == nil ? nil : IndexedTrack(tracks[continueIndex!], continueIndex)
    }
    
    // Determines which track will play next if previousTrack() is invoked, if any. This is used to eagerly prep tracks for future playback. Nil return value indicates no track.
    func peekPreviousTrack() -> IndexedTrack? {
        let prevIndex = playbackSequence.peekPrevious()
        return prevIndex == nil ? nil : IndexedTrack(tracks[prevIndex!], prevIndex)
    }
    
    func previousTrack() -> IndexedTrack? {
        let prevIndex = playbackSequence.previous()
        return prevIndex == nil ? nil : IndexedTrack(tracks[prevIndex!], prevIndex)
    }
    
    // Determines which track will play next if nextTrack() is invoked, if any. This is used to eagerly prep tracks for future playback. Nil return value indicates no track.
    func peekNextTrack() -> IndexedTrack? {
        let nextIndex = playbackSequence.peekNext()
        return nextIndex == nil ? nil : IndexedTrack(tracks[nextIndex!], nextIndex)
    }
    
    func nextTrack() -> IndexedTrack? {
        let nextIndex = playbackSequence.next()
        return nextIndex == nil ? nil : IndexedTrack(tracks[nextIndex!], nextIndex)
    }
    
    // Retrieves the track at the given index
    func peekTrackAt(_ index: Int?) -> IndexedTrack? {
        return index == nil || index == -1 ? nil : IndexedTrack(tracks[index!], index)
    }
    
    // Retrieves the track at the given index, and selects it for playback, i.e., moves the cursor to the given index
    func selectTrackAt(_ index: Int?) -> IndexedTrack? {
        
        // Assume index is valid
        let track = peekTrackAt(index)
        playbackSequence.randomTrackSelected(index!)
        return track
    }
    
    // Returns the index of the currently playing track in the playlist
    func getPlayingTrack() -> IndexedTrack? {
        return peekTrackAt(playbackSequence.cursor)
    }
    
    func getRepeatMode() -> RepeatMode {
        return playbackSequence.repeatMode
    }
    
    func getShuffleMode() -> ShuffleMode {
        return playbackSequence.shuffleMode
    }
    
    // ---------------------------------- END sequence accessor methods ----------------------------------
    
    func getTracks() -> [Track] {
        return tracks
    }
}
