//
//  PDBParser.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import Foundation

// Matches the TS constants from the web app
private let PAGE_TYPE_TRACKS: UInt32 = 0
private let PAGE_TYPE_GENRES: UInt32 = 1
private let PAGE_TYPE_ARTISTS: UInt32 = 2
private let PAGE_TYPE_ALBUMS: UInt32 = 3
private let PAGE_TYPE_LABELS: UInt32 = 4
private let PAGE_TYPE_KEYS: UInt32 = 5
private let PAGE_TYPE_PLAYLIST_TREE: UInt32 = 7
private let PAGE_TYPE_PLAYLIST_ENTRIES: UInt32 = 8

private struct TableInfo {
    let type: UInt32
    let firstPage: UInt32
    let lastPage: UInt32
}

final class PDBParser {

    // Parse the main export.pdb into a full DB
    func parseExportPDB(_ url: URL) throws -> RekordboxDatabase {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try parse(buffer: data)
    }

    // ✅ New: Parse ONLY lookup dictionaries from ANY pdb URL (export.pdb or exportExt.pdb)
    func parseLookupTables(from pdbURL: URL) throws
        -> (artists: [UInt32: String],
            albums: [UInt32: String],
            genres: [UInt32: String],
            keys: [UInt32: String]) {

        let data = try Data(contentsOf: pdbURL, options: [.mappedIfSafe])
        return parseLookupTablesFromBuffer(data)
    }

    // ✅ New: Parse ONLY lookup dictionaries from raw Data
    private func parseLookupTablesFromBuffer(_ buffer: Data)
        -> (artists: [UInt32: String],
            albums: [UInt32: String],
            genres: [UInt32: String],
            keys: [UInt32: String]) {

        let dv = DataView(buffer)

        let lenPage = Int(dv.u32(4))
        let numTables = Int(dv.u32(8))

        // Parse table directory
        var tables: [TableInfo] = []
        var off = 28
        for _ in 0..<numTables {
            guard off + 16 <= dv.count else { break }
            let type = dv.u32(off)
            let firstPage = dv.u32(off + 8)
            let lastPage = dv.u32(off + 12)
            tables.append(.init(type: type, firstPage: firstPage, lastPage: lastPage))
            off += 16
        }

        var artists: [UInt32: String] = [:]
        var albums: [UInt32: String] = [:]
        var genres: [UInt32: String] = [:]
        var keys: [UInt32: String] = [:]
        var labels: [UInt32: String] = [:] // internal; not returned, but parseSimpleRow expects it

        // Same as PASS 1 in parse(buffer:), but only lookups
        for t in tables where
            t.type == PAGE_TYPE_ARTISTS ||
            t.type == PAGE_TYPE_ALBUMS ||
            t.type == PAGE_TYPE_GENRES ||
            t.type == PAGE_TYPE_KEYS ||
            t.type == PAGE_TYPE_LABELS {

            parseTablePages(dv, table: t, lenPage: lenPage) { rowBase, pageType in
                self.parseSimpleRow(
                    dv,
                    rowBase: rowBase,
                    pageType: pageType,
                    artists: &artists,
                    albums: &albums,
                    genres: &genres,
                    keys: &keys,
                    labels: &labels
                )
            }
        }

        return (artists, albums, genres, keys)
    }

    private func parse(buffer: Data) throws -> RekordboxDatabase {
        let dv = DataView(buffer)

        let lenPage = Int(dv.u32(4))
        let numTables = Int(dv.u32(8))

        var tables: [TableInfo] = []
        var off = 28
        for _ in 0..<numTables {
            guard off + 16 <= dv.count else { break }
            let type = dv.u32(off)
            let firstPage = dv.u32(off + 8)
            let lastPage = dv.u32(off + 12)
            tables.append(.init(type: type, firstPage: firstPage, lastPage: lastPage))
            off += 16
        }

        var artists: [UInt32: String] = [:]
        var albums: [UInt32: String] = [:]
        var genres: [UInt32: String] = [:]
        var keys: [UInt32: String] = [:]
        var labels: [UInt32: String] = [:]

        var playlistTree: [UInt32: (name: String, parentId: UInt32, isFolder: Bool, sortOrder: UInt32)] = [:]
        var playlistEntries: [UInt32: [(trackId: UInt32, position: UInt32)]] = [:]
        var trackData: [UInt32: Track] = [:]

        // PASS 1: lookups
        for t in tables where
            t.type == PAGE_TYPE_ARTISTS ||
            t.type == PAGE_TYPE_ALBUMS ||
            t.type == PAGE_TYPE_GENRES ||
            t.type == PAGE_TYPE_KEYS ||
            t.type == PAGE_TYPE_LABELS {

            parseTablePages(dv, table: t, lenPage: lenPage) { rowBase, pageType in
                self.parseSimpleRow(
                    dv,
                    rowBase: rowBase,
                    pageType: pageType,
                    artists: &artists,
                    albums: &albums,
                    genres: &genres,
                    keys: &keys,
                    labels: &labels
                )
            }
        }

        // PASS 2: playlists tree
        for t in tables where t.type == PAGE_TYPE_PLAYLIST_TREE {
            parseTablePages(dv, table: t, lenPage: lenPage) { rowBase, _ in
                self.parsePlaylistTreeRow(dv, rowBase: rowBase, playlistTree: &playlistTree)
            }
        }

        // PASS 3: playlist entries
        for t in tables where t.type == PAGE_TYPE_PLAYLIST_ENTRIES {
            parseTablePages(dv, table: t, lenPage: lenPage) { rowBase, _ in
                self.parsePlaylistEntryRow(dv, rowBase: rowBase, playlistEntries: &playlistEntries)
            }
        }

        // PASS 4: tracks
        for t in tables where t.type == PAGE_TYPE_TRACKS {
            parseTablePages(dv, table: t, lenPage: lenPage) { rowBase, _ in
                self.parseTrackRow(
                    dv,
                    rowBase: rowBase,
                    artists: artists,
                    albums: albums,
                    genres: genres,
                    keys: keys,
                    trackData: &trackData
                )
            }
        }

        let tracks = trackData.values.sorted { $0.id < $1.id }

        // Build playlists (same behavior as web app)
        var playlistMap: [UInt32: Playlist] = [:]
        for (id, node) in playlistTree {
            let entries = playlistEntries[id] ?? []
            let sortedEntries = entries.sorted { $0.position < $1.position }

            playlistMap[id] = Playlist(
                id: Int(id),
                name: node.name,
                parentId: node.parentId == 0 ? nil : Int(node.parentId),
                isFolder: node.isFolder,
                children: [],
                trackIds: sortedEntries.map { Int($0.trackId) }
            )
        }

        func buildChildren(for parent: UInt32) -> [Playlist] {
            let kids = playlistMap.values
                .filter { $0.parentId == Int(parent) }
                .sorted {
                    let aOrder = playlistTree[UInt32($0.id)]?.sortOrder ?? 0
                    let bOrder = playlistTree[UInt32($1.id)]?.sortOrder ?? 0
                    return aOrder < bOrder
                }
            return kids.map { p in
                var p2 = p
                p2.children = buildChildren(for: UInt32(p.id))
                return p2
            }
        }

        let roots = playlistMap.values
            .filter { $0.parentId == nil }
            .sorted {
                let aOrder = playlistTree[UInt32($0.id)]?.sortOrder ?? 0
                let bOrder = playlistTree[UInt32($1.id)]?.sortOrder ?? 0
                return aOrder < bOrder
            }
            .map { p in
                var p2 = p
                p2.children = buildChildren(for: UInt32(p.id))
                return p2
            }

        return RekordboxDatabase(tracks: tracks, playlists: roots)
    }

    // TS: parseTablePages
    private func parseTablePages(
        _ dv: DataView,
        table: TableInfo,
        lenPage: Int,
        rowCallback: (_ rowBase: Int, _ pageType: UInt32) -> Void
    ) {
        var pageIndex = table.firstPage
        var visited = Set<UInt32>()

        while pageIndex > 0 && !visited.contains(pageIndex) {
            visited.insert(pageIndex)

            let pageOffset = Int(pageIndex) * lenPage
            if pageOffset + lenPage > dv.count { break }

            let pageType = dv.u32(pageOffset + 8)
            let nextPageIndex = dv.u32(pageOffset + 12)

            let packedRowInfo = dv.u32(pageOffset + 24)
            let numRowOffsets = Int(packedRowInfo & 0x1FFF) // lower 13 bits
            let pageFlags = dv.u8(pageOffset + 27)
            let isDataPage = (pageFlags & 0x40) == 0

            if isDataPage && pageType == table.type && numRowOffsets > 0 {
                let numRowGroups = Int(ceil(Double(numRowOffsets) / 16.0))
                let heapPos = pageOffset + 40

                for groupIndex in 0..<numRowGroups {
                    let groupBase = pageOffset + lenPage - (groupIndex * 0x24)
                    if groupBase - 4 < pageOffset + 40 { continue }

                    let rowPresentFlags = dv.u16(groupBase - 4)

                    for rowIndex in 0..<16 {
                        let isPresent = ((rowPresentFlags >> rowIndex) & 1) != 0
                        if !isPresent { continue }

                        let ofsRowPos = groupBase - 6 - (rowIndex * 2)
                        if ofsRowPos < pageOffset + 40 { continue }

                        let ofsRow = Int(dv.u16(ofsRowPos))
                        let rowBase = heapPos + ofsRow
                        if rowBase >= pageOffset + lenPage { continue }

                        rowCallback(rowBase, pageType)
                    }
                }
            }

            if nextPageIndex == 0 { break }
            if nextPageIndex >= UInt32(dv.count / lenPage) { break }
            if pageIndex == table.lastPage { break }
            pageIndex = nextPageIndex
        }
    }

    // TS: parseSimpleRow
    private func parseSimpleRow(
        _ dv: DataView,
        rowBase: Int,
        pageType: UInt32,
        artists: inout [UInt32: String],
        albums: inout [UInt32: String],
        genres: inout [UInt32: String],
        keys: inout [UInt32: String],
        labels: inout [UInt32: String]
    ) {
        switch pageType {
        case PAGE_TYPE_ARTISTS:
            let subtype = dv.u16(rowBase)
            let id = dv.u32(rowBase + 4)
            let nameOffset: Int = ((subtype & 0x04) == 0x04) ? Int(dv.u16(rowBase + 0x0a)) : Int(dv.u8(rowBase + 9))
            let name = readDeviceSqlString(dv, offset: rowBase + nameOffset)
            if !name.isEmpty { artists[id] = name }

        case PAGE_TYPE_ALBUMS:
            let subtype = dv.u16(rowBase)
            let id = dv.u32(rowBase + 12)

            // Your export.pdb uses subtype 0x80 where the album name is inline at 0x16
            let name: String
            if subtype == 0x80 {
                name = readDeviceSqlString(dv, offset: rowBase + 0x16)
            } else {
                // fallback for other variants (keep your original logic as a fallback)
                let nameOffset: Int = ((subtype & 0x04) == 0x04)
                    ? Int(dv.u16(rowBase + 0x16))
                    : Int(dv.u8(rowBase + 17))
                name = readDeviceSqlString(dv, offset: rowBase + nameOffset)
            }

            if !name.isEmpty { albums[id] = name }

        case PAGE_TYPE_GENRES:
            let id = dv.u32(rowBase)
            let name = readDeviceSqlString(dv, offset: rowBase + 4)
            if !name.isEmpty { genres[id] = name }

        case PAGE_TYPE_KEYS:
            let id = dv.u32(rowBase)
            let name = readDeviceSqlString(dv, offset: rowBase + 8)
            if !name.isEmpty { keys[id] = name }

        case PAGE_TYPE_LABELS:
            let id = dv.u32(rowBase)
            let name = readDeviceSqlString(dv, offset: rowBase + 4)
            if !name.isEmpty { labels[id] = name }

        default:
            break
        }
    }

    private func parsePlaylistTreeRow(
        _ dv: DataView,
        rowBase: Int,
        playlistTree: inout [UInt32: (name: String, parentId: UInt32, isFolder: Bool, sortOrder: UInt32)]
    ) {
        let parentId = dv.u32(rowBase)
        let sortOrder = dv.u32(rowBase + 8)
        let id = dv.u32(rowBase + 12)
        let rawIsFolder = dv.u32(rowBase + 16)
        let name = readDeviceSqlString(dv, offset: rowBase + 20)

        if !name.isEmpty && id > 0 {
            playlistTree[id] = (name: name, parentId: parentId, isFolder: rawIsFolder != 0, sortOrder: sortOrder)
        }
    }

    private func parsePlaylistEntryRow(
        _ dv: DataView,
        rowBase: Int,
        playlistEntries: inout [UInt32: [(trackId: UInt32, position: UInt32)]]
    ) {
        let entryIndex = dv.u32(rowBase)
        let trackId = dv.u32(rowBase + 4)
        let playlistId = dv.u32(rowBase + 8)
        guard playlistId > 0, trackId > 0 else { return }
        playlistEntries[playlistId, default: []].append((trackId: trackId, position: entryIndex))
    }

    private func parseTrackRow(
        _ dv: DataView,
        rowBase: Int,
        artists: [UInt32: String],
        albums: [UInt32: String],
        genres: [UInt32: String],
        keys: [UInt32: String],
        trackData: inout [UInt32: Track]
    ) {
        let tempo = dv.u32(rowBase + 0x38)     // BPM * 100
        let genreId = dv.u32(rowBase + 0x3C)
        let albumId = dv.u32(rowBase + 0x40)
        let artistId = dv.u32(rowBase + 0x44)
        let id = dv.u32(rowBase + 0x48)
        let duration = Int(dv.u16(rowBase + 0x54))
        let rating = Int(dv.u8(rowBase + 0x59))
        let bitrate = Int(dv.u32(rowBase + 0x30))
        let keyId = dv.u32(rowBase + 0x20)

        var ofsStrings: [UInt16] = []
        ofsStrings.reserveCapacity(21)
        for i in 0..<21 {
            ofsStrings.append(dv.u16(rowBase + 0x5E + (i * 2)))
        }

        let titleOffset = Int(ofsStrings[17])
        let filePathOffset = Int(ofsStrings[20])
        let dateAddedOffset = Int(ofsStrings[10])

        let title = titleOffset > 0
            ? readDeviceSqlString(dv, offset: rowBase + titleOffset)
            : ""

        let filePath = filePathOffset > 0
            ? readDeviceSqlString(dv, offset: rowBase + filePathOffset)
            : ""

        let dateAddedStr = dateAddedOffset > 0
            ? readDeviceSqlString(dv, offset: rowBase + dateAddedOffset)
            : ""

        guard id > 0 else { return }

        let dateAdded = parseDateLoose(dateAddedStr) ?? Date()

        trackData[id] = Track(
            id: Int(id),
            title: title.isEmpty ? "Unknown Title" : title,
            artist: artists[artistId] ?? "Unknown Artist",
            album: albums[albumId] ?? "",
            genre: genres[genreId] ?? "",
            duration: duration,
            bpm: Double(tempo) / 100.0,
            key: keys[keyId] ?? "",
            rating: rating,
            bitrate: bitrate,
            filePath: filePath,
            dateAdded: dateAdded
        )
    }

    private func readDeviceSqlString(_ dv: DataView, offset: Int) -> String {
        if offset < 0 || offset >= dv.count { return "" }
        let lengthAndKind = dv.u8(offset)

        if lengthAndKind == 0x40 {
            let length = Int(dv.u16(offset + 1))
            if length < 4 { return "" }
            return dv.stringASCII(offset + 4, length - 4)
        } else if lengthAndKind == 0x90 {
            let length = Int(dv.u16(offset + 1))
            if length < 4 { return "" }
            return dv.stringUTF16LE(offset + 4, length - 4)
        } else if (lengthAndKind % 2) == 1 {
            let length = Int(lengthAndKind >> 1)
            if length < 1 { return "" }
            return dv.stringASCII(offset + 1, length - 1)
        }
        return ""
    }

    private func parseDateLoose(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: trimmed) { return d }

        let fmts = ["yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd", "yyyy/MM/dd"]
        for f in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: trimmed) { return d }
        }
        return nil
    }
}

// JS DataView-like helper
private struct DataView {
    private let data: Data
    var count: Int { data.count }
    init(_ data: Data) { self.data = data }

    func u8(_ o: Int) -> UInt8 {
        guard o >= 0, o < data.count else { return 0 }
        return data[o]
    }
    func u16(_ o: Int) -> UInt16 {
        guard o >= 0, o + 1 < data.count else { return 0 }
        return UInt16(data[o]) | (UInt16(data[o + 1]) << 8)
    }
    func u32(_ o: Int) -> UInt32 {
        guard o >= 0, o + 3 < data.count else { return 0 }
        return UInt32(data[o]) | (UInt32(data[o + 1]) << 8) | (UInt32(data[o + 2]) << 16) | (UInt32(data[o + 3]) << 24)
    }

    func stringASCII(_ o: Int, _ len: Int) -> String {
        guard o >= 0, len >= 0, o + len <= data.count else { return "" }
        return String(data: data.subdata(in: o..<(o + len)), encoding: .ascii) ?? ""
    }
    func stringUTF16LE(_ o: Int, _ len: Int) -> String {
        guard o >= 0, len >= 0, o + len <= data.count else { return "" }
        return String(data: data.subdata(in: o..<(o + len)), encoding: .utf16LittleEndian) ?? ""
    }
}
