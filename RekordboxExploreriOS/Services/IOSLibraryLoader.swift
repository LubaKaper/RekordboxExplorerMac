//
//  IOSLibraryLoader.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import Foundation
import Combine

//@MainActor
final class IOSLibraryLoader: ObservableObject {
    @Published var status: String = ""
    @Published var db: RekordboxDatabase?

    private let parser = PDBParser()

    /// One-tap shortcut. Works only if the USB (or source) is accessible.
    func openLast() {
        guard let url = BookmarkStore.loadLastImportedPdbURL() else {
            status = "No saved library yet. Import export.pdb first."
            return
        }
        load(exportPdbURL: url)
    }

    func load(exportPdbURL: URL) {
        status = "Loading…"

        let parser = self.parser  // capture locally so detached can use it

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let ok = exportPdbURL.startAccessingSecurityScopedResource()
            defer { if ok { exportPdbURL.stopAccessingSecurityScopedResource() } }

            do {
                let db = try parser.parseExportPDB(exportPdbURL)
                await MainActor.run {
                    self.db = db
                    self.status = "Loaded."
                }
            } catch {
                await MainActor.run {
                    self.status = "Parse failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func importAndLoad(pickedURL: URL) {
        status = "Importing…"

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let ok = pickedURL.startAccessingSecurityScopedResource()
            defer { if ok { pickedURL.stopAccessingSecurityScopedResource() } }

            do {
                // 1) Read file
                let data = try Data(contentsOf: pickedURL)

                // 2) Save inside app Documents
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let folder = docs.appendingPathComponent("ImportedLibraries", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                // Create a stable filename (timestamp-based)
                let filename = "export-\(Int(Date().timeIntervalSince1970)).pdb"
                let dest = folder.appendingPathComponent(filename)

                try data.write(to: dest, options: .atomic)

                // 3) Remember + load from the imported file (no USB needed anymore)
                BookmarkStore.saveLastImportedPdbPath(dest)

                let db = try self.parser.parseExportPDB(dest)

                await MainActor.run {
                    self.db = db
                    self.status = "Loaded (imported)."
                }
            } catch {
                await MainActor.run {
                    self.status = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
