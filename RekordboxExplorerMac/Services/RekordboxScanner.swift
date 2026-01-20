//
//  RekordboxScanner.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import Foundation

struct RekordboxScanResult {
    let exportPdb: URL
    let exportExtPdb: URL?
}

struct RekordboxScanner {

    func scan(in root: URL) -> RekordboxScanResult? {
        guard let export = findFile(named: "export.pdb", preferred: "PIONEER/rekordbox/export.pdb", in: root) else {
            return nil
        }

        let ext = findFile(named: "exportExt.pdb", preferred: "PIONEER/rekordbox/exportExt.pdb", in: root)
        return RekordboxScanResult(exportPdb: export, exportExtPdb: ext)
    }

    private func findFile(named: String, preferred: String, in root: URL) -> URL? {
        let standard = root.appendingPathComponent(preferred)
        if FileManager.default.fileExists(atPath: standard.path) { return standard }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.lastPathComponent == named { return url }
        }
        return nil
    }
}
