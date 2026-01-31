//
//  MacSettingsView.swift
//  RekordboxExplorerMac
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

struct MacSettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreference: AppPreferences.ColorSchemePreference = .dark
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            Form {
                // Appearance Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Appearance", systemImage: "paintbrush.fill")
                            .font(.headline)

                        Picker("Color Scheme", selection: $colorSchemePreference) {
                            ForEach(AppPreferences.ColorSchemePreference.allCases) { scheme in
                                HStack {
                                    Image(systemName: scheme.icon)
                                    Text(scheme.rawValue)
                                }
                                .tag(scheme)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(colorSchemeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // Font Size Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Font Size", systemImage: "textformat.size")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(fontSizeMultiplier * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        HStack(spacing: 12) {
                            Text("A")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Slider(
                                value: $fontSizeMultiplier,
                                in: AppPreferences.minFontSize...AppPreferences.maxFontSize,
                                step: 0.05
                            )

                            Text("A")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        // Preview
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sample Artist")
                                        .fontSizePreference(fontSizeMultiplier, baseSize: .body)
                                    Text("Sample Track Title")
                                        .fontSizePreference(fontSizeMultiplier, baseSize: .caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("123.5")
                                        .fontSizePreference(fontSizeMultiplier, baseSize: .body)
                                        .monospacedDigit()
                                    Text("BPM")
                                        .fontSizePreference(fontSizeMultiplier, baseSize: .caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Text("Adjust text size in the table for better readability.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // Compatibility Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("CDJ Compatibility", systemImage: "hifispeaker.2.fill")
                            .font(.headline)

                        Text("Rekordbox exports are compatible with Pioneer DJ equipment that supports the Performance mode export format.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            compatibilityRow("CDJ-3000", supported: true)
                            compatibilityRow("CDJ-2000NXS2", supported: true)
                            compatibilityRow("CDJ-2000NXS", supported: true)
                            compatibilityRow("XDJ-RX3 / XDJ-XZ", supported: true)
                            compatibilityRow("XDJ-1000MK2", supported: true)
                            compatibilityRow("DDJ Controllers", supported: true)
                        }
                        .padding(12)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)

                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Version")
                                    .foregroundStyle(.secondary)
                                Text("1.0")
                            }

                            GridRow {
                                Text("Database Format")
                                    .foregroundStyle(.secondary)
                                Text("Rekordbox PDB")
                            }

                            GridRow {
                                Text("Platform")
                                    .foregroundStyle(.secondary)
                                Text("macOS")
                            }
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // Reset Section
                Section {
                    Button {
                        resetToDefaults()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 500, height: 700)
    }

    private var colorSchemeDescription: String {
        switch colorSchemePreference {
        case .light:
            return "Light mode for bright environments."
        case .dark:
            return "Dark mode for low-light environments."
        case .colorful:
            return "Dark mode with vibrant cyan accents."
        }
    }

    private func compatibilityRow(_ device: String, supported: Bool) -> some View {
        HStack {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
            Text(device)
                .font(.callout)
        }
    }

    private func resetToDefaults() {
        withAnimation {
            colorSchemePreference = .dark
            fontSizeMultiplier = 1.0
        }
    }
}

#Preview {
    MacSettingsView()
}
