//
//  PDFExportHelpers.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

// MARK: - Sheet Item Models

struct PDFPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preview Sheet

struct PDFPreviewSheet: View {
    let url: URL
    let onShare: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PDFPreviewController(url: url)
                .ignoresSafeArea()
                .navigationTitle("PDF Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                            // Small delay to allow dismiss animation to complete
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                await MainActor.run {
                                    onShare(url)
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
