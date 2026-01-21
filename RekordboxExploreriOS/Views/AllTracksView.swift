//
//  AllTracksView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct AllTracksView: View {
    let tracks: [Track]
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                ForEach(filtered(tracks)) { t in
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
                TextField("Search title / artist / album…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .navigationTitle("All Tracks")
    }

    private func filtered(_ tracks: [Track]) -> [Track] {
        let q = searchText.lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }
}
