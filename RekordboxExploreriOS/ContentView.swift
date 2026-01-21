//
//  ContentView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var loader = IOSLibraryLoader()
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                Button {
                    showingPicker = true
                } label: {
                    Label("Select export.pdb (USB / Files)", systemImage: "externaldrive")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    loader.openLast()
                } label: {
                    Label("Open Last USB", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(!BookmarkStore.hasLastImported()
                )

                if !loader.status.isEmpty {
                    Text(loader.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let db = loader.db {
                    LibraryRootView(db: db)
                } else {
                    ContentUnavailableView(
                        "Select a Rekordbox export",
                        systemImage: "externaldrive",
                        description: Text("Choose export.pdb from Files (iCloud / On My iPhone / USB).")
                    )
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Rekordbox Explorer")
        }
        .sheet(isPresented: $showingPicker) {
            PDBDocumentPicker { url in
                showingPicker = false
                if url.lastPathComponent.lowercased() == "export.pdb" {
                    loader.importAndLoad(pickedURL: url)
                } else {
                    loader.status = "Please select export.pdb"
                }
            }
        }
    }
}
