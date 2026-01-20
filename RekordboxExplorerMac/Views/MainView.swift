//
//  MainView.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import SwiftUI

enum LibrarySelection: Hashable {
    case home
    case allTracks
    case browseFiles
    case playlist(id: Int)
}

struct MainView: View {
    @State private var status = "Select a Rekordbox USB folder."
    @State private var isLoading = false
    @State private var exportPdbURL: URL?
    @State private var exportExtURL: URL?
    @State private var db: RekordboxDatabase?
    
    @State private var selection: LibrarySelection = .home
    @State private var searchText: String = ""
    
    // Table sorting
    @State private var sortOrder: [KeyPathComparator<Track>] = [
        .init(\.title, order: .forward)
    ]
    
    private let folderAccess = FolderAccessService()
    private let scanner = RekordboxScanner()
    private let parser = PDBParser()
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("RekordboxExplorerMac")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    selection = .home
                    searchText = ""
                } label: {
                    Label("Home", systemImage: "house")
                }
                
                Button("Select Rekordbox Folder") { selectFolderAndLoad() }
                
                if isLoading { ProgressView().scaleEffect(0.8) }
            }
            
            ToolbarItem(placement: .automatic) {
                if selection != .home {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        searchField
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("Export") {
                    Button("Export CSV…") {
                        ExportService.exportTracks(visibleTracks(), format: .csv)
                    }
                    Button("Export JSON…") {
                        ExportService.exportTracks(visibleTracks(), format: .json)
                    }
                }
                .disabled(db == nil)
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selection = .home
                searchText = ""
            } label: {
                Text("Library")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            List(selection: $selection) {
                HStack {
                    Image(systemName: "music.note")
                    Text("All Tracks")
                    Spacer()
                    Text("\(db?.tracks.count ?? 0)")
                        .foregroundStyle(.secondary)
                }
                .tag(LibrarySelection.allTracks)
                
                HStack {
                    Image(systemName: "folder")
                    Text("Browse Files")
                }
                .tag(LibrarySelection.browseFiles)
                
                if selection != .home, let roots = db?.playlists, !roots.isEmpty {
                    Section("PLAYLISTS") {
                        ForEach(roots) { node in
                            PlaylistRow(node: node, selection: $selection)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            VStack(alignment: .leading, spacing: 4) {
                if let url = exportPdbURL {
                    Text("export.pdb: \(url.lastPathComponent)")
                    if let ext = exportExtURL {
                        Text("exportExt.pdb: \(ext.lastPathComponent)")
                    } else {
                        Text("exportExt.pdb: not found")
                    }
                } else {
                    Text(status)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Detail
    
    private var detail: some View {
        Group {
            switch selection {
            case .home:
                emptyState
            default:
                if db == nil {
                    emptyState
                } else {
                    tracksView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 44))
                .foregroundStyle(.cyan)
            
            Text("RekordboxExplorerMac")
                .font(.system(size: 34, weight: .semibold))
            
            Text("Browse your Rekordbox USB library without opening the full Rekordbox app.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            
            Button {
                selectFolderAndLoad()
            } label: {
                Text("Select USB or Folder")
                    .frame(width: 320)
            }
            .controlSize(.large)
            
            Text("Looks for  PIONEER/rekordbox/export.pdb")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
    
    private var tracksView: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBar
            
            Table(filteredAndSortedTracks, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.title) { t in
                    Text(t.title)
                        .lineLimit(1)
                }
                TableColumn("Artist", value: \.artist) { t in
                    Text(t.artist)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TableColumn("Album") { t in
                    Text(t.album.isEmpty ? "—" : t.album)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TableColumn("Duration") { t in
                    Text(Formatters.duration(t.duration))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                TableColumn("BPM") { t in
                    Text(String(format: "%.1f", t.bpm))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            // The Table header is pinned automatically (this satisfies your requirement).
        }
        .padding(16)
    }
    
    private var headerBar: some View {
        let title: String
        let count: Int
        
        switch selection {
        case .home:
            title = "Library"
            count = 0
            
        case .allTracks:
            title = "All Tracks"
            count = filteredAndSortedTracks.count
            
        case .browseFiles:
            title = "Browse Files"
            count = 0
            
        case .playlist(let id):
            title = playlistName(id) ?? "Playlist"
            count = filteredAndSortedTracks.count
        }
        
        return HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text("\(count) tracks")
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tracks…", text: $searchText)
                .textFieldStyle(.plain)
                .frame(width: 260)
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
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
        )
    }
    
    // MARK: - Data pipeline (filtering + playlist selection + sorting)
    
    private var filteredAndSortedTracks: [Track] {
        guard let db else { return [] }
        
        // base set based on selection
        let base: [Track]
        switch selection {
        case .home:
            base = []   // Home shows no tracks
            
        case .allTracks:
            base = db.tracks
            
        case .browseFiles:
            base = db.tracks // later: replace with file-tree logic
            
        case .playlist(let pid):
            let ids = trackIdsForPlaylist(pid)
            let set = Set(ids)
            base = db.tracks.filter { set.contains($0.id) }
        }
        
        // search filter (title/artist/album)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? base : base.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q) ||
            $0.genre.lowercased().contains(q) ||
            $0.key.lowercased().contains(q)
        }
        
        // sort according to Table sortOrder
        return filtered.sorted(using: sortOrder)
    }
    
    private func playlistName(_ id: Int) -> String? {
        func find(_ nodes: [Playlist]) -> Playlist? {
            for n in nodes {
                if n.id == id { return n }
                if let found = find(n.children) { return found }
            }
            return nil
        }
        return find(db?.playlists ?? [])?.name
    }
    
    private func trackIdsForPlaylist(_ id: Int) -> [Int] {
        func find(_ nodes: [Playlist]) -> Playlist? {
            for n in nodes {
                if n.id == id { return n }
                if let found = find(n.children) { return found }
            }
            return nil
        }
        
        func collectTrackIds(_ node: Playlist) -> [Int] {
            // include this node’s ids, plus all children ids
            var out = node.trackIds
            for c in node.children {
                out.append(contentsOf: collectTrackIds(c))
            }
            return out
        }
        
        guard let node = find(db?.playlists ?? []) else { return [] }
        return collectTrackIds(node)
    }
    
    // MARK: - Loading
    
    private func selectFolderAndLoad() {
        do {
            let folderURL = try folderAccess.pickFolder()
            loadFromFolder(folderURL)
        } catch {
            status = "Cancelled."
        }
    }
    
    private func loadFromFolder(_ folderURL: URL) {
        isLoading = true
        status = "Scanning for export.pdb…"

        DispatchQueue.global(qos: .userInitiated).async {
            guard folderURL.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async {
                    self.status = "No permission (sandbox). Reselect the folder."
                    self.isLoading = false
                }
                return
            }
            defer { folderURL.stopAccessingSecurityScopedResource() }

            guard let scan = scanner.scan(in: folderURL) else {
                DispatchQueue.main.async {
                    self.status = "export.pdb not found."
                    self.isLoading = false
                }
                return
            }

            do {
                let db = try parser.parseExportPDB(scan.exportPdb)

                DispatchQueue.main.async {
                    self.exportPdbURL = scan.exportPdb
                    self.exportExtURL = scan.exportExtPdb
                    self.db = db
                    self.isLoading = false
                    self.selection = .allTracks

                    if scan.exportExtPdb != nil {
                        self.status = "Loaded (exportExt.pdb found)."
                    } else {
                        self.status = "Loaded."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "Parse failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Returns the tracks currently visible in the table (after search, playlist selection, and sorting).
    private func visibleTracks() -> [Track] {
        filteredAndSortedTracks
    }
}

// Sidebar playlist rows (indented tree)
private struct PlaylistRow: View {
    let node: Playlist
    @Binding var selection: LibrarySelection
    
    var body: some View {
        if node.children.isEmpty {
            Button {
                selection = .playlist(id: node.id)
            } label: {
                rowLabel(icon: "music.note.list")
            }
            .buttonStyle(.plain)
            .tag(LibrarySelection.playlist(id: node.id))
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    PlaylistRow(node: child, selection: $selection)
                        .padding(.leading, 10)
                }
            } label: {
                Button {
                    // IMPORTANT: folders are selectable too
                    selection = .playlist(id: node.id)
                } label: {
                    rowLabel(icon: "folder")
                }
                .buttonStyle(.plain)
            }
            .tag(LibrarySelection.playlist(id: node.id))
        }
    }
    
    private func rowLabel(icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(node.name)
            Spacer()
            Text("\(node.trackIds.count)")
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
