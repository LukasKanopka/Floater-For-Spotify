// FILE: SpotifyModels.swift
// DESCRIPTION: Create a new Swift file named "SpotifyModels.swift" and add this code.
//
import Foundation

// The main response object from the /currently-playing endpoint
struct SpotifyTrackResponse: Codable {
    let item: Track?
    let is_playing: Bool
}

// Represents a single track
struct Track: Codable, Identifiable {
    let id: String
    let name: String
    let album: Album
    let artists: [Artist]
    
    // Computed property to easily get a string of artist names
    var artistNames: String {
        return artists.map { $0.name }.joined(separator: ", ")
    }
}

// Represents an album, which contains the artwork
struct Album: Codable {
    let images: [ImageObject]
}

// Represents a single artist
struct Artist: Codable {
    let name: String
}

// Represents an image, with its URL
struct ImageObject: Codable {
    let url: String
}