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
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isExportingPDF || totalTrackCount(for: playlist) == 0)
                    }
                }
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
                .sheet(item: $shareItem) { item in
                    ShareSheet(items: [item.url])
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
    
    // MARK: - Folder PDF Export Helpers (iOS)
    
    private func totalTrackCount(for playlist: Playlist) -> Int {
        if playlist.isFolder {
            return playlist.children.reduce(0) { $0 + totalTrackCount(for: $1) }
        } else {
            return playlist.trackIds.count
        }
    }
    
    /// Folder export: sections for every descendant playlist/folder with headings.
    private func exportFolderPDF() {
        guard playlist.isFolder else { return }
        guard !isExportingPDF else { return }
        
        isExportingPDF = true
        exportErrorMessage = nil
        
        Task {
            do {
                // 1) Build + map to Sendable OFF main thread
                let (pdfTitle, pdfSubtitle, sendableSections) =
                await Task.detached(priority: .userInitiated) { () -> (String, String, [(name: String, tracks: [PDFTrackRow])]) in
                    
                    let sections = SectionBuilder.buildSectionsUnderFolder(playlist, db: db)
                    let total = sections.reduce(0) { $0 + $1.tracks.count }
                    
                    let title = playlist.name
                    let subtitle = "\(total) tracks"
                    
                    let mapped: [(name: String, tracks: [PDFTrackRow])] = sections.map { s in
                        (
                            name: s.title, // <-- keep s.title if that's your TrackSection field
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
                
                // 2) EXPORT PDF on MainActor (UIKit PDF renderer => MainActor)
                let url = try await MainActor.run {
                    try PDFExportService.exportSectionedTracksPDF(
                        title: pdfTitle,
                        subtitle: pdfSubtitle,
                        sections: sendableSections
                    )
                }
                
                // 3) Update UI on main thread
                await MainActor.run {
                    shareItem = ShareItem(url: url)
                    isExportingPDF = false
                }
                
            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    isExportingPDF = false
                }
                print("PDF export failed:", error)
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}


