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
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    var body: some View {
        List {
            // Header card
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .fontSizePreference(fontSizeMultiplier, baseSize: .title3)
                                .fontWeight(.semibold)
                                .lineLimit(3)

                            Text(track.artist.isEmpty ? "—" : track.artist)
                                .fontSizePreference(fontSizeMultiplier, baseSize: .body)
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
                        .accessibilityHint("Copies track title, artist, and album to clipboard")
                    }
                }
                .padding(.vertical, 6)
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
        .toast("Copied", isShowing: $showCopiedToast, duration: 1.2)
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

        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        showCopiedToast = true
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .fontSizePreference(fontSizeMultiplier, baseSize: .caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .fontSizePreference(fontSizeMultiplier, baseSize: .body)
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
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(d) {
            return "Today at " + d.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(d) {
            return "Yesterday at " + d.formatted(date: .omitted, time: .shortened)
        } else if let days = calendar.dateComponents([.day], from: d, to: now).day, days < 7 {
            return d.formatted(date: .omitted, time: .omitted) + " " + d.formatted(.dateTime.weekday(.wide).hour().minute())
        } else {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
    }
}
