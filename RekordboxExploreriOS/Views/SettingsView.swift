//
//  SettingsView.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreference: AppPreferences.ColorSchemePreference = .dark
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    // Color Scheme Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Appearance", systemImage: "paintbrush.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            ForEach(AppPreferences.ColorSchemePreference.allCases) { scheme in
                                ColorSchemeButton(
                                    scheme: scheme,
                                    isSelected: colorSchemePreference == scheme
                                ) {
                                    withAnimation(.spring(duration: 0.3)) {
                                        colorSchemePreference = scheme
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                } header: {
                    Text("Display")
                } footer: {
                    Text(colorSchemeDescription)
                }

                // Font Size Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Font Size", systemImage: "textformat.size")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(fontSizeMultiplier * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        // Font size slider
                        HStack(spacing: 12) {
                            Text("A")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Slider(
                                value: $fontSizeMultiplier,
                                in: AppPreferences.minFontSize...AppPreferences.maxFontSize,
                                step: 0.05
                            )
                            .tint(.cyan)

                            Text("A")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        // Preview text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Sample Artist - Track Title")
                                .fontSizePreference(fontSizeMultiplier, baseSize: .body)

                            Text("Album: Sample Album - 5:20")
                                .fontSizePreference(fontSizeMultiplier, baseSize: .caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 8)

                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Adjust text size for better readability. Changes apply to all track listings.")
                }

                // CDJ Compatibility Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("CDJ Compatibility", systemImage: "hifispeaker.2.fill")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            compatibilityRow("CDJ-3000", supported: true)
                            compatibilityRow("CDJ-2000NXS2", supported: true)
                            compatibilityRow("CDJ-2000NXS", supported: true)
                            compatibilityRow("XDJ-RX3 / XDJ-XZ", supported: true)
                            compatibilityRow("XDJ-1000MK2", supported: true)
                            compatibilityRow("DDJ Controllers", supported: true)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Compatibility")
                } footer: {
                    Text("Rekordbox exports are compatible with Pioneer DJ equipment that supports Performance mode.")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Database Format", systemImage: "cylinder")
                        Spacer()
                        Text("Rekordbox PDB")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            resetToDefaults()
                        }
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
        colorSchemePreference = .dark
        fontSizeMultiplier = 1.0
    }
}

// MARK: - Color Scheme Button

private struct ColorSchemeButton: View {
    let scheme: AppPreferences.ColorSchemePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.cyan : Color.clear, lineWidth: 3)
                        )

                    Image(systemName: scheme.icon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }

                Text(scheme.rawValue)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch scheme {
        case .light:
            return Color(.systemBackground)
        case .dark:
            return Color(.systemGray6)
        case .colorful:
            return Color.cyan.opacity(0.3)
        }
    }

    private var iconColor: Color {
        switch scheme {
        case .light:
            return .orange
        case .dark:
            return .indigo
        case .colorful:
            return .cyan
        }
    }
}

#Preview {
    SettingsView()
}
