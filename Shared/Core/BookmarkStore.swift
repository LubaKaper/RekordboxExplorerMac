//
//  BookmarkStore.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import Foundation

enum BookmarkStore {
    private static let lastImportedPdbPathKey = "last_imported_export_pdb_path_v1"

    static func saveLastImportedPdbPath(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastImportedPdbPathKey)
    }

    static func loadLastImportedPdbURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: lastImportedPdbPathKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func hasLastImported() -> Bool {
        loadLastImportedPdbURL() != nil
    }
}
