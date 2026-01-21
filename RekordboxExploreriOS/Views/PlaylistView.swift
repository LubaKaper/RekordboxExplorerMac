//
//  PlaylistView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct PlaylistView: View {
    let playlist: Playlist
    let db: RekordboxDatabase

    var body: some View {
        Group {
            if playlist.isFolder {
                List(playlist.children) { child in
                    NavigationLink {
                        PlaylistView(playlist: child, db: db)
                    } label: {
                        Label {
                            HStack {
                                Text(child.name)
                                Spacer()
                                Text("\(totalTrackCount(for: child))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: child.isFolder ? "folder" : "music.note.list")
                        }
                    }
                }
                .navigationTitle(playlist.name)

            } else {
                PlaylistTracksView(playlist: playlist, db: db)
                    .navigationTitle(playlist.name)
            }
        }
    }

    /// A) Folder = sum of all descendant playlist counts (duplicates allowed).
    /// Playlist = its own trackIds.count
    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }
}
