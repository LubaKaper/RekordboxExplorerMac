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
    @State private var pdfURL: URL?
    @State private var showPreview = false
    @State private var showShare = false
    @State private var exportErrorMessage: String?
    @State private var isExporting = false
    @State private var showCopiedToast = false

    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    // MARK: - Computed Properties

    /// Returns tracks in the playlist's stored order
    private var playlistTracks: [Track] {
        let map: [Int: Track] = Dictionary(uniqueKeysWithValues: db.tracks.map { ($0.id, $0) })
        return playlist.trackIds.compactMap { map[$0] }
    }

    /// Filtered tracks based on search query
    private var visibleTracks: [Track] {
        TrackFilterHelpers.filtered(playlistTracks, searchText: searchText)
    }

    /// Binding for error alert
    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar outside the list (stable position)
            searchBar

            // List of tracks
            List {
                // Show empty state as a row, not replacing the whole view
                if visibleTracks.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Results")
                            .font(.title3)
                            .fontWeight(.medium)
                        Text("Try a different search term")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleTracks) { track in
                        NavigationLink {
                            TrackDetailView(track: track)
                        } label: {
                            TrackRowView(track: track)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                copyTrackInfo(track)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                exportButton
            }
        }
        .sheet(isPresented: $showPreview) {
            if let url = pdfURL {
                PDFPreviewSheet(url: url) { sharedURL in
                    showPreview = false
                    pdfURL = sharedURL
                    showShare = true
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Export Failed", isPresented: showErrorAlert) {
            Button("Retry", role: .none) {
                exportPDF(tracks: visibleTracks)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if isExporting {
                ProgressView("Generating PDF...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .toast("Copied", isShowing: $showCopiedToast)
    }

    // MARK: - View Components

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("Search title / artist / album...", text: $searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var exportButton: some View {
        Button {
            exportPDF(tracks: visibleTracks)
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Image(systemName: "doc.fill")
            }
        }
        .disabled(visibleTracks.isEmpty || isExporting)
        .accessibilityLabel("Export PDF")
        .accessibilityHint("Creates and shares a PDF of \(visibleTracks.count) tracks from \(playlist.name)")
    }

    // MARK: - Actions

    private func exportPDF(tracks: [Track]) {
        guard !isExporting else { return }

        isExporting = true
        exportErrorMessage = nil

        // Capture data before async work to avoid actor isolation issues
        let capturedPlaylistName = playlist.name
        let capturedTracks = tracks

        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try PDFExportService.exportTracksPDF(
                        title: capturedPlaylistName,
                        subtitle: "\(capturedTracks.count) tracks",
                        tracks: capturedTracks
                    )
                }.value

                await MainActor.run {
                    pdfURL = url
                    showPreview = true
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

    private func copyTrackInfo(_ track: Track) {
        let parts = [
            track.title.trimmingCharacters(in: .whitespacesAndNewlines),
            track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        var text = parts.joined(separator: " - ")

        let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !album.isEmpty {
            text += " (\(album))"
        }

        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        showCopiedToast = true
    }
}
