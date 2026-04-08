struct Secrets {
    // Public identifier for your Spotify developer app (NOT a secret).
    // Keep this file local and uncommitted by copying it to `Secrets.swift`.
    static let spotifyClientID = "YOUR_SPOTIFY_CLIENT_ID_HERE"

    // Must match your Spotify Dashboard redirect URI and Info.plist URL scheme.
    static let spotifyRedirectURI = "spotifycontroller://callback"
    static let spotifyCallbackURLScheme = "spotifycontroller"
}
