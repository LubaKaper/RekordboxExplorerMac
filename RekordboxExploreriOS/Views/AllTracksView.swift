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
    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?

    var body: some View {
        let visibleTracks = filtered(tracks)

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
        .navigationTitle("All Tracks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportPDF(tracks: visibleTracks)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(visibleTracks.isEmpty)
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
                title: "All Tracks",
                subtitle: "\(tracks.count) tracks",
                tracks: tracks
            )
            shareItem = ShareItem(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
