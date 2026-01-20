//
//  ExportService.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/19/26.
//

import Foundation
import AppKit
internal import UniformTypeIdentifiers

enum ExportFormat {
    case csv
    case json
}

enum ExportService {

    static func exportTracks(
        _ tracks: [Track],
        format: ExportFormat,
        suggestedName: String = "rekordbox-library"
    ) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        switch format {
        case .csv:
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = suggestedName + ".csv"
        case .json:
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = suggestedName + ".json"
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data: Data
                switch format {
                case .csv:
                    let csv = makeCSV(tracks)
                    data = Data(csv.utf8)
                case .json:
                    data = try makeJSON(tracks)
                }
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    // MARK: - CSV

    private static func makeCSV(_ tracks: [Track]) -> String {
        let header = [
            "row",
            "id",
            "title",
            "artist",
            "album",
            "genre",
            "duration",
            "bpm",
            "rating",
            "bitrate",
            "filePath",
            "dateAdded"
        ].joined(separator: ",")

        let rows = tracks.enumerated().map { (idx, t) in
            [
                "\(idx + 1)",
                "\(t.id)",
                csv(t.title),
                csv(t.artist),
                csv(t.album),
                csv(t.genre),
                "\(t.duration)",
                String(format: "%.2f", t.bpm),
                "\(t.rating)",
                "\(t.bitrate)",
                csv(t.filePath),
                csv(iso8601(t.dateAdded))
            ].joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private static func csv(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func iso8601(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }

    // MARK: - JSON

    private struct TrackExport: Codable {
        let id: Int
        let title: String
        let artist: String
        let album: String
        let genre: String
        let duration: Int
        let bpm: Double
        let rating: Int
        let bitrate: Int
        let filePath: String
        let dateAdded: String
    }

    private static func makeJSON(_ tracks: [Track]) throws -> Data {
        let payload = tracks.map { t in
            TrackExport(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
                genre: t.genre,
                duration: t.duration,
                bpm: t.bpm,
                rating: t.rating,
                bitrate: t.bitrate,
                filePath: t.filePath,
                dateAdded: iso8601(t.dateAdded)
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}
