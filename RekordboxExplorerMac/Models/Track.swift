//
//  Track.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/17/26.
//

import Foundation

struct Track: Identifiable, Hashable {
    let id: Int
    var title: String
    var artist: String
    var album: String
    var genre: String
    var duration: Int
    var bpm: Double
    var key: String
    var rating: Int
    var bitrate: Int
    var filePath: String
    var dateAdded: Date
}
