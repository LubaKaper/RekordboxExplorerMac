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

    @State private var previewItem: PreviewItem?
    @State private var shareItem: ShareItem?
    @State private var exportErrorMessage: String?
    @State private var isExportingPDF = false
    @State private var exportStatus: String = ""

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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
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
                .safeAreaInset(edge: .top) {
                    if !exportStatus.isEmpty {
                        Text(exportStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                }
                .alert("Export failed", isPresented: .constant(exportErrorMessage != nil)) {
                    Button("OK") { exportErrorMessage = nil }
                } message: {
                    Text(exportErrorMessage ?? "")
                }

            } else {
                PlaylistTracksView(playlist: playlist, db: db)
            }
        }
    }

    // MARK: - Folder helpers

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
        exportStatus = "Preparing PDF…"

        Task {
            do {
                // 1) Build + map Sendable OFF main thread
                let (pdfTitle, pdfSubtitle, sendableSections) =
                await Task.detached(priority: .userInitiated) { () -> (String, String, [(name: String, tracks: [PDFTrackRow])]) in

                    let sections = SectionBuilder.buildSectionsUnderFolder(playlist, db: db)
                    let total = sections.reduce(0) { $0 + $1.tracks.count }

                    let title = playlist.name
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

                await MainActor.run { exportStatus = "Rendering PDF…" }

                // 2) Export PDF on MainActor (UIKit renderer)
                let url = try await MainActor.run {
                    try PDFExportService.exportSectionedTracksPDF(
                        title: pdfTitle,
                        subtitle: pdfSubtitle,
                        sections: sendableSections
                    )
                }

                // 3) Show PREVIEW (not share)
                await MainActor.run {
                    previewItem = PreviewItem(url: url)
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

// MARK: - Sheet items

private struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preview wrapper (dismiss preview, then share)

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

