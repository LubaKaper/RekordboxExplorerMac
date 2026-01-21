//
//  PlaylistTracksView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct PlaylistTracksView: View {
    let playlist: Playlist
    let db: RekordboxDatabase
    @State private var searchText = ""

    private var playlistTracks: [Track] {
        let set = Set(playlist.trackIds)
        return db.tracks.filter { set.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                ForEach(filtered(playlistTracks)) { t in
                    NavigationLink {
                        TrackDetailView(track: t)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title)
                                .lineLimit(1)

                            Text("\(t.artist) • \(t.album.isEmpty ? "—" : t.album)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(playlistTracks.count) tracks")
                        .font(.headline)

                    TextField("Search title / artist / album…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.vertical, 8)
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
    }

    private func filtered(_ tracks: [Track]) -> [Track] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }
}
