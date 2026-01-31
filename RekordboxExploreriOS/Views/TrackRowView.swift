//
//  TrackRowView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

/// Reusable track row view for lists
struct TrackRowView: View {
    let track: Track
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .fontSizePreference(fontSizeMultiplier, baseSize: .body)
                .lineLimit(1)
            
            Text("\(track.artist) • \(track.album.isEmpty ? "—" : track.album)")
                .fontSizePreference(fontSizeMultiplier, baseSize: .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }
}
