//
//  SectionBuilder.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/21/26.
//

import Foundation

struct TrackSection {
    let title: String
    let tracks: [Track]
}

enum SectionBuilder {

    /// Builds sections for a folder playlist by walking all descendants.
    /// Each leaf playlist becomes a section titled "Folder / Subfolder / Playlist".
    static func buildSectionsUnderFolder(_ folder: Playlist, db: RekordboxDatabase) -> [TrackSection] {

        // Fast lookup by Int id (important: keep Int everywhere)
        let trackById: [Int: Track] = Dictionary(uniqueKeysWithValues: db.tracks.map { ($0.id, $0) })

        // Preserve playlist order
        func tracksForPlaylist(_ p: Playlist) -> [Track] {
            p.trackIds.compactMap { trackById[$0] }
        }

        var result: [TrackSection] = []

        func walk(_ node: Playlist, path: [String]) {
            if node.isFolder {
                // Recurse into children
                for child in node.children {
                    walk(child, path: path + [child.name])
                }
            } else {
                let tracks = tracksForPlaylist(node)
                if !tracks.isEmpty {
                    let title = path.joined(separator: " / ")
                    result.append(TrackSection(title: title, tracks: tracks))
                }
            }
        }

        // Start with folder name included in the section title path
        walk(folder, path: [folder.name])

        return result
    }
}
