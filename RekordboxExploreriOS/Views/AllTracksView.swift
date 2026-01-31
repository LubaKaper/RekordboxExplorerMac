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
    @State private var pdfURL: URL?
    @State private var showPreview = false
    @State private var showShare = false
    @State private var exportErrorMessage: String?
    @State private var isExporting = false
    @State private var showCopiedToast = false
    
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    // MARK: - Computed Properties
    
    /// Filtered tracks based on search query
    private var visibleTracks: [Track] {
        TrackFilterHelpers.filtered(tracks, searchText: searchText)
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
        List {
            Section {
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
            } header: {
                TextField("Search title / artist / album…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                    .autocorrectionDisabled()
            }
        }
        .listStyle(.plain)
        .navigationTitle("All Tracks")
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
    
    private var exportButton: some View {
        Button {
            exportPDF(tracks: visibleTracks)
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .disabled(visibleTracks.isEmpty || isExporting)
        .accessibilityLabel("Export PDF")
        .accessibilityHint("Creates and shares a PDF of \(visibleTracks.count) tracks")
    }

    // MARK: - Actions

    private func exportPDF(tracks: [Track]) {
        guard !isExporting else { return }
        
        isExporting = true
        exportErrorMessage = nil
        
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try PDFExportService.exportTracksPDF(
                        title: "All Tracks",
                        subtitle: "\(tracks.count) tracks",
                        tracks: tracks
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
        
        var text = parts.joined(separator: " — ")
        
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
