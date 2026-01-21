//
//  LibraryRootView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct LibraryRootView: View {
    let db: RekordboxDatabase

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AllTracksView(tracks: db.tracks)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Tracks")
                            Text("Full library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(db.tracks.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Section("Playlists") {
                ForEach(db.playlists) { p in
                    NavigationLink {
                        PlaylistView(playlist: p, db: db)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                Text(p.isFolder ? "Folder" : "Playlist")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(totalTrackCount(for: p))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Library")
    }

    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }
}
