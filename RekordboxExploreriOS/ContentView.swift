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
    @State private var showingSettings = false

    @AppStorage("colorSchemePreference") private var colorSchemePreference: AppPreferences.ColorSchemePreference = .dark
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    var body: some View {
        NavigationStack {
            Group {
                if loader.db != nil {
                    LibraryRootView(database: $loader.db)
                } else {
                    landingPage
                }
            }
            .navigationTitle("Rekordbox Explorer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings for appearance and preferences")
                }
            }
        }
        .tint(colorSchemePreference.isColorful ? .cyan : nil)
        .preferredColorScheme(colorSchemePreference.colorScheme)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Landing Page

    private var landingPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                // Action Buttons
                actionButtons
                    .padding(.horizontal, 24)

                // Status Message
                if !loader.status.isEmpty {
                    Text(loader.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                        .accessibilityLabel("Status: \(loader.status)")
                }

                Spacer(minLength: 40)

                // Footer Info
                footerInfo
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .background(backgroundGradient)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)

            // Title
            VStack(spacing: 8) {
                Text("Rekordbox Explorer")
                    .font(.title.weight(.bold))

                Text("Browse your DJ library on the go")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rekordbox Explorer. Browse your DJ library on the go.")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Button - Select USB/Files
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select USB or Files")
                            .font(.headline)
                        Text("Choose export.pdb from your library")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.cyan, .teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .cyan.opacity(0.3), radius: 8, y: 4)
            }
            .accessibilityLabel("Select USB or Files")
            .accessibilityHint("Opens file picker to choose your Rekordbox export.pdb file")

            // Secondary Button - Open Last Library
            Button {
                loader.openLast()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.cyan)

                    Text("Open Last Library")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!BookmarkStore.hasLastImported())
            .opacity(BookmarkStore.hasLastImported() ? 1.0 : 0.5)
            .accessibilityLabel("Open Last Library")
            .accessibilityHint(BookmarkStore.hasLastImported()
                ? "Opens the most recently used library"
                : "No previous library available")
        }
    }

    // MARK: - Footer Info

    private var footerInfo: some View {
        VStack(spacing: 16) {
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("Looking for your library?")
                        .font(.subheadline.weight(.medium))
                }

                Text("Connect your Rekordbox USB drive, or navigate to:\nPIONEER → rekordbox → export.pdb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Looking for your library? Connect your Rekordbox USB drive, or navigate to PIONEER, rekordbox, export.pdb")
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95),
                Color.cyan.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
