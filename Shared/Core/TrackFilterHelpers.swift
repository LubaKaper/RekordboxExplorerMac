//
//  TrackFilterHelpers.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/30/26.
//

import Foundation

/// Shared filtering logic for tracks
enum TrackFilterHelpers {
    
    /// Filters tracks based on fuzzy search query matching title, artist, or album
    /// Uses character-by-character matching to find tracks even with typos or partial matches
    static func filtered(_ tracks: [Track], searchText: String) -> [Track] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        
        // Split query into words for multi-word matching
        let queryWords = query.split(separator: " ").map(String.init)
        
        return tracks.filter { track in
            let title = track.title.lowercased()
            let artist = track.artist.lowercased()
            let album = track.album.lowercased()
            
            // If all words match in any field, include the track
            let allWordsMatch = queryWords.allSatisfy { word in
                fuzzyMatch(word, in: title) ||
                fuzzyMatch(word, in: artist) ||
                fuzzyMatch(word, in: album)
            }
            
            return allWordsMatch
        }
    }
    
    /// Filters tracks for macOS (includes genre and key fields)
    /// Uses the same fuzzy search logic as iOS
    static func filteredMac(_ tracks: [Track], searchText: String) -> [Track] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        
        // Split query into words for multi-word matching
        let queryWords = query.split(separator: " ").map(String.init)
        
        return tracks.filter { track in
            let title = track.title.lowercased()
            let artist = track.artist.lowercased()
            let album = track.album.lowercased()
            let genre = track.genre.lowercased()
            let key = track.key.lowercased()
            
            // If all words match in any field, include the track
            let allWordsMatch = queryWords.allSatisfy { word in
                fuzzyMatch(word, in: title) ||
                fuzzyMatch(word, in: artist) ||
                fuzzyMatch(word, in: album) ||
                fuzzyMatch(word, in: genre) ||
                fuzzyMatch(word, in: key)
            }
            
            return allWordsMatch
        }
    }
    
    /// Fuzzy matching: checks if characters in query appear in target string in order
    /// Example: "dft pnk" matches "Daft Punk"
    private static func fuzzyMatch(_ query: String, in target: String) -> Bool {
        // First try exact substring match (faster and more intuitive)
        if target.contains(query) {
            return true
        }
        
        // Then try fuzzy character-by-character matching
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        // If we've matched all query characters, it's a match
        return queryIndex == query.endIndex
    }
}
