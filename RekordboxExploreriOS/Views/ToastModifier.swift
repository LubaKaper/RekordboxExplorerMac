//
//  ToastModifier.swift
//  RekordboxExploreriOS
//
//  Created by Liubov Kaper  on 1/30/26.
//

import SwiftUI

/// A reusable toast notification modifier for displaying brief messages
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: TimeInterval
    
    init(message: String, isShowing: Binding<Bool>, duration: TimeInterval = 1.5) {
        self.message = message
        self._isShowing = isShowing
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowing {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(duration))
                                await MainActor.run {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
            .animation(.spring(duration: 0.3), value: isShowing)
    }
}

extension View {
    /// Shows a brief toast notification at the bottom of the view
    /// - Parameters:
    ///   - message: The text to display
    ///   - isShowing: Binding to control visibility
    ///   - duration: How long to show the toast (default: 1.5 seconds)
    func toast(_ message: String, isShowing: Binding<Bool>, duration: TimeInterval = 1.5) -> some View {
        modifier(ToastModifier(message: message, isShowing: isShowing, duration: duration))
    }
}
