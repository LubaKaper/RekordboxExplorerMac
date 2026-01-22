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
    @State private var previewItem: PreviewItem?
    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?

    var body: some View {
        let tracksForPlaylist = playlistTracksInOrder()
        let visibleTracks = filtered(tracksForPlaylist)

        List {
            Section {
                ForEach(visibleTracks) { t in
                    NavigationLink {
                        TrackDetailView(track: t)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).lineLimit(1)
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
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportPDF(tracks: visibleTracks)
                } label: {
                    Image(systemName: "doc.fill")
                }
                .disabled(visibleTracks.isEmpty)
            }
        }
        // Preview first
        .sheet(item: $previewItem) { item in
            PreviewSheet(url: item.url) { url in
                shareItem = ShareItem(url: url)
            }
        }
        // Then Share
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Export failed", isPresented: .constant(exportErrorMessage != nil)) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    /// Returns tracks in the playlist's stored order (trackIds order).
    private func playlistTracksInOrder() -> [Track] {
        // Fast lookup: trackId -> Track
        let map: [Int: Track] = Dictionary(uniqueKeysWithValues: db.tracks.map { ($0.id, $0) })

        // Preserve playlist order (and skip missing IDs)
        return playlist.trackIds.compactMap { map[$0] }
    }

    private func filtered(_ tracks: [Track]) -> [Track] {
        let q = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }

    private func exportPDF(tracks: [Track]) {
        do {
            let url = try PDFExportService.exportTracksPDF(
                title: playlist.name,
                subtitle: "\(tracks.count) tracks",
                tracks: tracks
            )
            previewItem = PreviewItem(url: url)   // ✅ preview first
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sheet Items

private struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preview sheet wrapper (dismiss preview, then share)

private struct PreviewSheet: View {
    let url: URL
    let onShare: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFPreviewController(url: url)
                .ignoresSafeArea()
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onShare(url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}
