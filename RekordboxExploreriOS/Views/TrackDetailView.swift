//
//  TrackDetailView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct TrackDetailView: View {
    let track: Track

    @State private var showCopiedToast = false

    var body: some View {
        List {
            // Header card
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(3)

                            Text(track.artist.isEmpty ? "—" : track.artist)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            copySummary()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Copy track info")
                    }
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    if showCopiedToast {
                        Text("Copied")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 6)
                            .transition(.opacity)
                    }
                }
            }

            // Details (Album only appears here)
            Section("Details") {
                infoRow("Album", track.album.isEmpty ? "—" : track.album)
                infoRow("Genre", track.genre.isEmpty ? "—" : track.genre)
                infoRow("BPM", track.bpm > 0 ? String(format: "%.1f", track.bpm) : "—")
                infoRow("Duration", formatDuration(track.duration))
                infoRow("Rating", track.rating > 0 ? "\(track.rating)" : "—")
                infoRow("Bitrate", track.bitrate > 0 ? "\(track.bitrate) kbps" : "—")
                infoRow("Date Added", formatDate(track.dateAdded))
            }
        }
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
    }

    private func copySummary() {
        let parts = [
            track.title.trimmingCharacters(in: .whitespacesAndNewlines),
            track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        var text = parts.joined(separator: " — ")

        let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !album.isEmpty {
            text += " (\(album))"
        }

        UIPasteboard.general.string = text

        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showCopiedToast = false
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: d)
    }
}
