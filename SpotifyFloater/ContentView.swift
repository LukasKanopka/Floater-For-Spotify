// FILE: ContentView.swift
// DESCRIPTION: Replace the contents of ContentView.swift with this code.

import Foundation
import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                PlayerView()
            } else {
                // Login View
                VStack(spacing: 20) {
                    Text("Spotify Floater")
                        .font(.largeTitle)
                        .fontWeight(.bold) // Added for emphasis

                    Text("Welcome to Spotify Floater! Please log in to continue.")
                        .font(.body)
                        .foregroundColor(.primary)

                    Button("Login with Spotify") {
                        authManager.startAuthentication()
                    }
                    .buttonStyle(.borderedProminent) // Modern button style
                    .tint(Color(red: 0.11, green: 0.82, blue: 0.33)) // Spotify Green
                    .controlSize(.large) // Make the button larger
                }
                .frame(width: 360, height: 240)
                // --- UI REVAMP: FROSTED GLASS EFFECT ---
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25.0))
                // --- END OF UI REVAMP ---
                .shadow(color: .black.opacity(0.2), radius: 10)
            }
        }
        .onAppear {
            // Attempt to refresh token on app launch (uses Keychain if available)
            authManager.refreshAccessToken()
        }
    }
}