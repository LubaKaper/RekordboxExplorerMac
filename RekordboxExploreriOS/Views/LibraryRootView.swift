//
//  LibraryRootView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct LibraryRootView: View {
    @Binding var database: RekordboxDatabase?

    @State private var pdfURL: URL?
    @State private var showShare = false
    @State private var exportErrorMessage: String?
    @State private var isExporting = false

    // MARK: - Computed Properties

    private var db: RekordboxDatabase {
        database ?? RekordboxDatabase(tracks: [], playlists: [])
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    // MARK: - Body

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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    database = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Close")
                    }
                }
                .accessibilityLabel("Close Library")
                .accessibilityHint("Returns to the home screen")
            }

            ToolbarItem(placement: .topBarTrailing) {
                exportButton
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Export Failed", isPresented: showErrorAlert) {
            Button("Retry", role: .none) {
                exportLibraryPDF()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if isExporting {
                ProgressView("Exporting Library...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - View Components

    private var exportButton: some View {
        Button {
            exportLibraryPDF()
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(db.tracks.isEmpty || isExporting)
        .accessibilityLabel("Export Library")
        .accessibilityHint("Creates a PDF of the entire library")
    }

    // MARK: - Helpers

    /// Total tracks for a playlist; for folders, includes all descendants.
    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }

    /// Build top-level sections and export a sectioned PDF
    private func exportLibraryPDF() {
        guard !isExporting else { return }

        isExporting = true
        exportErrorMessage = nil

        // Capture data before async work
        let playlists = db.playlists
        let tracks = db.tracks

        Task {
            do {
                let sections = await Task.detached(priority: .userInitiated) {
                    Self.buildTopLevelSections(playlists: playlists, tracks: tracks)
                }.value

                let total = sections.reduce(0) { $0 + $1.tracks.count }

                let url = try await Task.detached(priority: .userInitiated) {
                    try PDFExportService.exportSectionedTracksPDF(
                        title: "Rekordbox Library",
                        subtitle: "\(total) tracks",
                        sections: sections
                    )
                }.value

                await MainActor.run {
                    pdfURL = url
                    showShare = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    /// Sections = top-level playlists/folders on the left.
    /// - If it's a folder: section contains all tracks under it (all descendants).
    /// - If it's a playlist: section contains that playlist's tracks.
    nonisolated private static func buildTopLevelSections(playlists: [Playlist], tracks: [Track]) -> [(name: String, tracks: [PDFTrackRow])] {
        // fast lookup: track id -> Track
        let map: [Int: Track] = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })

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

        for p in playlists {
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
