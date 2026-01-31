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

    @State private var pdfURL: URL?
    @State private var showPreview = false
    @State private var showShare = false
    @State private var exportErrorMessage: String?
    @State private var isExportingPDF = false
    @State private var exportStatus: String = ""

    // MARK: - Computed Properties

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    // MARK: - Body

    var body: some View {
        Group {
            if playlist.isFolder {
                folderView
            } else {
                PlaylistTracksView(playlist: playlist, db: db)
            }
        }
    }

    // MARK: - View Components

    private var folderView: some View {
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
        .safeAreaInset(edge: .top) {
            if !exportStatus.isEmpty {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
        .alert("Export Failed", isPresented: showErrorAlert) {
            Button("Retry", role: .none) {
                exportFolderPDF()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if isExportingPDF {
                VStack(spacing: 8) {
                    ProgressView()
                    if !exportStatus.isEmpty {
                        Text(exportStatus)
                            .font(.caption)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var exportButton: some View {
        Button {
            exportFolderPDF()
        } label: {
            if isExportingPDF {
                ProgressView()
            } else {
                Image(systemName: "doc.fill")
            }
        }
        .disabled(isExportingPDF || totalTrackCount(for: playlist) == 0)
        .accessibilityLabel("Export Folder PDF")
        .accessibilityHint("Creates a PDF of all playlists in \(playlist.name)")
    }

    // MARK: - Folder Helpers

    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }

    /// Folder export: sections for every descendant playlist with headings.
    private func exportFolderPDF() {
        guard playlist.isFolder else { return }
        guard !isExportingPDF else { return }

        isExportingPDF = true
        exportErrorMessage = nil
        exportStatus = "Preparing PDF..."

        // Capture data before async work to avoid actor isolation issues
        let capturedPlaylist = playlist
        let capturedDb = db

        Task {
            do {
                // 1) Build + map Sendable OFF main thread
                let (pdfTitle, pdfSubtitle, sendableSections) =
                await Task.detached(priority: .userInitiated) { () -> (String, String, [(name: String, tracks: [PDFTrackRow])]) in

                    let sections = SectionBuilder.buildSectionsUnderFolder(capturedPlaylist, db: capturedDb)
                    let total = sections.reduce(0) { $0 + $1.tracks.count }

                    let title = capturedPlaylist.name
                    let subtitle = "\(total) tracks"

                    let mapped: [(name: String, tracks: [PDFTrackRow])] = sections.map { s in
                        (
                            name: s.title,
                            tracks: s.tracks.map { t in
                                PDFTrackRow(
                                    title: t.title,
                                    artist: t.artist,
                                    album: t.album,
                                    bpm: t.bpm,
                                    duration: t.duration
                                )
                            }
                        )
                    }

                    return (title, subtitle, mapped)
                }.value

                await MainActor.run { exportStatus = "Rendering PDF..." }

                // 2) Export PDF on MainActor (UIKit renderer)
                let url = try await MainActor.run {
                    try PDFExportService.exportSectionedTracksPDF(
                        title: pdfTitle,
                        subtitle: pdfSubtitle,
                        sections: sendableSections
                    )
                }

                // 3) Show PREVIEW
                await MainActor.run {
                    pdfURL = url
                    showPreview = true
                    isExportingPDF = false
                    exportStatus = ""
                }

            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    isExportingPDF = false
                    exportStatus = ""
                }
            }
        }
    }
}
