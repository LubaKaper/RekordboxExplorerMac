//
//  Playlist.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import Foundation

struct Playlist: Identifiable, Hashable {
    let id: Int
    var name: String
    var parentId: Int?
    var isFolder: Bool
    var children: [Playlist]
    var trackIds: [Int]
}
