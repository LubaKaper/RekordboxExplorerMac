//
//  LibraryRootView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct LibraryRootView: View {
    let db: RekordboxDatabase

    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?

    var body: some View {
        List {
            NavigationLink {
                AllTracksView(tracks: db.tracks)
            } label: {
                Label {
                    HStack {
                        Text("All Tracks")
                        Spacer()
                        Text("\(db.tracks.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } icon: {
                    Image(systemName: "music.note.list")
                }
            }

            Section("Playlists") {
                ForEach(db.playlists) { p in
                    NavigationLink {
                        PlaylistView(playlist: p, db: db)
                    } label: {
                        Label {
                            HStack {
                                Text(p.name)
                                Spacer()
                                Text("\(totalTrackCount(for: p))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: p.isFolder ? "folder" : "music.note.list")
                        }
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportLibraryPDF()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(db.tracks.isEmpty)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Export failed", isPresented: .constant(exportErrorMessage != nil)) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    /// Total tracks for a playlist; for folders, includes all descendants.
    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }

    /// Step 2: Build top-level sections and export a sectioned PDF
    private func exportLibraryPDF() {
        do {
            let sections = buildTopLevelSections()
            let total = sections.reduce(0) { $0 + $1.tracks.count }

            let url = try PDFExportService.exportSectionedTracksPDF(
                title: "Rekordbox Library",
                subtitle: "\(total) tracks",
                sections: sections
            )
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    /// Sections = top-level playlists/folders on the left.
    /// - If it's a folder: section contains all tracks under it (all descendants).
    /// - If it's a playlist: section contains that playlist's tracks.
    private func buildTopLevelSections() -> [(name: String, tracks: [PDFTrackRow])] {
        // fast lookup: track id -> Track
        let map: [Int: Track] = Dictionary(uniqueKeysWithValues: db.tracks.map { ($0.id, $0) })

        func tracksForPlaylist(_ p: Playlist) -> [Track] {
            // preserve playlist order
            p.trackIds.compactMap { map[$0] }
        }

        func allTrackIdsUnder(_ p: Playlist) -> [Int] {
            if p.isFolder {
                return p.children.flatMap { allTrackIdsUnder($0) }
            } else {
                return p.trackIds
            }
        }

        func tracksForFolder(_ p: Playlist) -> [Track] {
            // de-dupe but keep a stable order
            var seen = Set<Int>()
            let ids = allTrackIdsUnder(p).filter { seen.insert($0).inserted }
            return ids.compactMap { map[$0] }
        }

        func toRows(_ tracks: [Track]) -> [PDFTrackRow] {
            tracks.map { t in
                PDFTrackRow(
                    title: t.title,
                    artist: t.artist,
                    album: t.album,
                    bpm: t.bpm,
                    duration: t.duration
                )
            }
        }

        var result: [(name: String, tracks: [PDFTrackRow])] = []

        for p in db.playlists {
            if p.isFolder {
                let tracks = tracksForFolder(p)
                let rows = toRows(tracks)
                if !rows.isEmpty { result.append((name: p.name, tracks: rows)) }
            } else {
                let tracks = tracksForPlaylist(p)
                let rows = toRows(tracks)
                if !rows.isEmpty { result.append((name: p.name, tracks: rows)) }
            }
        }

        return result
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
