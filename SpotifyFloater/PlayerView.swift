// FILE: PlayerView.swift
// DESCRIPTION: Replace the contents of PlayerView.swift with this code.

import SwiftUI
import AppKit
import QuartzCore

struct PlayerView: View {
    @EnvironmentObject var authManager: SpotifyAuthManager
    
    // State for the currently playing track and its artwork
    @State private var currentTrack: Track?
    @State private var albumArt: NSImage?
    @State private var isPlaying: Bool = false
    @State private var isFavorite: Bool = false
    @State private var isExpanded: Bool = false
    
    // A timer to periodically fetch the latest track info
    // Slow down the timer to reduce unnecessary background polling.
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // Control button layout parameters
    private let controlHitSize: CGFloat = 36
    private let controlIconSize: CGFloat = 24
    private var controlAdjustedSpacing: CGFloat { max(0, 15 - (controlHitSize - controlIconSize)) }
    private let containerCornerRadius: CGFloat = 50.0
    @Namespace private var cardNS
    private var cardAnimation: Animation { .interpolatingSpring(stiffness: 180, damping: 20) }
    private let collapsedSize = CGSize(width: 300, height: 100)
    private let expandedSize = CGSize(width: 300, height: 400)

    var body: some View {
       CardContainer(cornerRadius: containerCornerRadius) {
           Group {
               if let track = currentTrack {
                   if isExpanded {
                      // Expanded portrait card layout (4:3 portrait)
                       VStack(spacing: 12) {
                          // Album art large and centered
                          Image(nsImage: albumArt ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!)
                              .resizable()
                              .aspectRatio(1, contentMode: .fit)
                              .frame(width: 220, height: 220)
                              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                              .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                              .hoverOutline(cornerRadius: 12)
                              .contentShape(RoundedRectangle(cornerRadius: 12))
                              .matchedGeometryEffect(id: "art", in: cardNS)
                              .onTapGesture { toggleExpanded() }

                          // Title and artists, center aligned
                          VStack(spacing: 6) {
                              Text(track.name)
                                  .font(.title3)
                                  .fontWeight(.semibold)
                                  .multilineTextAlignment(.center)
                                  .foregroundColor(.primary)
                                  .lineLimit(3)
                                  .fixedSize(horizontal: false, vertical: true)
                                  .matchedGeometryEffect(id: "title", in: cardNS)

                              Text(track.artistNames)
                                  .font(.callout)
                                  .multilineTextAlignment(.center)
                                  .foregroundColor(.secondary)
                                  .lineLimit(3)
                                  .fixedSize(horizontal: false, vertical: true)
                                  .matchedGeometryEffect(id: "artists", in: cardNS)
                          }
                          .padding(.horizontal, 12)
                          .hoverOutline(cornerRadius: 8)
                          .onTapGesture { toggleExpanded() }

                          Spacer(minLength: 0)

                          // Controls row: previous, play/pause, next, heart
                          HStack(spacing: controlAdjustedSpacing) {
                              PlayerButton(systemName: "backward.fill", hitSize: controlHitSize) {
                                  authManager.performPlayerAction(endpoint: .previous) { error in
                                      if error == nil { self.fetchAfterAction() }
                                  }
                              }
                              PlayerButton(systemName: isPlaying ? "pause.fill" : "play.fill", fontSize: .title2, hitSize: controlHitSize) {
                                  let endpoint: SpotifyAuthManager.PlayerEndpoint = isPlaying ? .pause : .play
                                  authManager.performPlayerAction(endpoint: endpoint) { error in
                                      if error == nil { self.fetchAfterAction() }
                                  }
                              }
                              PlayerButton(systemName: "forward.fill", hitSize: controlHitSize) {
                                  authManager.performPlayerAction(endpoint: .next) { error in
                                      if error == nil { self.fetchAfterAction() }
                                  }
                              }
                              PlayerButton(systemName: isFavorite ? "heart.fill" : "heart", fontSize: .title2, hitSize: controlHitSize) {
                                  toggleFavoriteStatus()
                              }
                              .tint(isFavorite ? .pink : .secondary)
                              .animation(.spring(), value: isFavorite)
                          }
                          .matchedGeometryEffect(id: "controls", in: cardNS)
                      }
                      .padding(16)
                   } else {
                      // Collapsed pill layout (original horizontal)
                       HStack(spacing: 12) {
                          // Album art
                          Image(nsImage: albumArt ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!)
                              .resizable()
                              .aspectRatio(contentMode: .fit)
                              .frame(width: 72, height: 72)
                              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                              .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                              .hoverOutline(cornerRadius: 8)
                              .contentShape(RoundedRectangle(cornerRadius: 8))
                              .matchedGeometryEffect(id: "art", in: cardNS)
                              .onTapGesture { toggleExpanded() }

                          // Track info and controls
                          VStack(alignment: .leading, spacing: 5) {
                              // Hoverable, clickable metadata area
                              VStack(alignment: .leading, spacing: 3) {
                                  Text(track.name)
                                      .font(.headline)
                                      .fontWeight(.bold)
                                      .foregroundColor(.primary)
                                      .lineLimit(1)
                                      .fixedSize(horizontal: false, vertical: true)
                                      .matchedGeometryEffect(id: "title", in: cardNS)

                                  Text(track.artistNames)
                                      .font(.caption)
                                      .foregroundColor(.secondary)
                                      .lineLimit(1)
                                      .fixedSize(horizontal: false, vertical: true)
                                      .matchedGeometryEffect(id: "artists", in: cardNS)
                              }
                              .hoverOutline(cornerRadius: 6)
                              .onTapGesture { toggleExpanded() }

                              // Target hit area for controls without changing visible spacing between icons
                              HStack(spacing: controlAdjustedSpacing) {
                                  // Backward Button
                                  PlayerButton(systemName: "backward.fill", hitSize: controlHitSize) {
                                      authManager.performPlayerAction(endpoint: .previous) { error in
                                          if error == nil { self.fetchAfterAction() }
                                      }
                                  }

                                  // Play/Pause Button
                                  PlayerButton(systemName: isPlaying ? "pause.fill" : "play.fill", fontSize: .title2, hitSize: controlHitSize) {
                                      let endpoint: SpotifyAuthManager.PlayerEndpoint = isPlaying ? .pause : .play
                                      authManager.performPlayerAction(endpoint: endpoint) { error in
                                          if error == nil { self.fetchAfterAction() }
                                      }
                                  }

                                  // Forward Button
                                  PlayerButton(systemName: "forward.fill", hitSize: controlHitSize) {
                                      authManager.performPlayerAction(endpoint: .next) { error in
                                          if error == nil { self.fetchAfterAction() }
                                      }
                                  }
                              }
                              .matchedGeometryEffect(id: "controls", in: cardNS)
                          }

                          // Heart on the right in collapsed mode
                          PlayerButton(systemName: isFavorite ? "heart.fill" : "heart", fontSize: .title2, hitSize: controlHitSize) {
                              toggleFavoriteStatus()
                          }
                          .tint(isFavorite ? .pink : .secondary)
                          .animation(.spring(), value: isFavorite)
                      }
                   }
           } else {
               Text("Nothing Playing")
                   .font(.title)
                   .foregroundColor(.secondary)
           }
       }
       .padding(.horizontal, 20)
       .padding(.vertical, 12)
       }
       .frame(width: collapsedSize.width, height: isExpanded ? expandedSize.height : collapsedSize.height) // Portrait 3:4 when expanded
       .onAppear(perform: fetchCurrentTrack)
       .onReceive(timer) { _ in
           fetchCurrentTrack()
       }
   }
    
    // Fetches the track and then its artwork
    private func fetchCurrentTrack() {
        authManager.getCurrentTrack { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if self.currentTrack?.id != response.item?.id {
                        self.currentTrack = response.item
                        if let imageURLString = response.item?.album.images.first?.url,
                           let imageURL = URL(string: imageURLString) {
                            self.fetchAlbumArt(from: imageURL)
                        } else {
                            self.albumArt = nil
                        }
                    }
                    self.isPlaying = response.is_playing
                    
                    if let trackId = response.item?.id {
                        self.checkFavoriteStatus(for: trackId)
                    }
                    
                case .failure(let error):
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .badResponse(let statusCode) where statusCode == 403:
                            print("Playback not active on any device (403).")
                            self.isPlaying = false
                            self.currentTrack = nil
                            self.albumArt = nil
                        case .badResponse(let statusCode) where statusCode == 401:
                            // 401 should have been handled by refresh-and-retry. Keep last known state.
                            print("Unauthorized (401) after retry. Keeping last known track.")
                        default:
                            print("API error fetching track: \(apiError)")
                            // Keep last known track/artwork on transient errors
                        }
                    } else {
                        print("Error fetching track: \(error.localizedDescription)")
                        // Keep last known track/artwork on transient errors
                    }
                    // no view transitions here; keep logic-only path
                }
            }
        }
    }
    
    private func checkFavoriteStatus(for trackId: String) {
        authManager.checkIfTrackIsSaved(trackId: trackId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let isSavedArray):
                    self.isFavorite = isSavedArray.first ?? false
                case .failure(let error):
                    print("Could not check favorite status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func toggleFavoriteStatus() {
        guard let trackId = currentTrack?.id else { return }
        
        if isFavorite {
            authManager.removeFromFavorites(trackId: trackId) { error in
                if error == nil {
                    DispatchQueue.main.async { self.isFavorite = false }
                }
            }
        } else {
            authManager.addToFavorites(trackId: trackId) { error in
                if error == nil {
                    DispatchQueue.main.async { self.isFavorite = true }
                }
            }
        }
    }
    
    // Fetches image data from a URL
    private func fetchAlbumArt(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.albumArt = image
                }
            } else {
                print("Error fetching album art: \(error?.localizedDescription ?? "Unknown error")")
            }
        }.resume()
    }
    // Instantly fetches track info after a short delay to ensure
    // Spotify's backend has processed the change.
    private func fetchAfterAction() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.fetchCurrentTrack()
        }
    }

    // Centralized toggle with high-quality spring for perfect symmetry
    private func toggleExpanded() {
        let target = isExpanded ? collapsedSize : expandedSize
        withAnimation(cardAnimation) {
            isExpanded.toggle()
        }
        animateWindowResize(to: target)
    }

    private func animateWindowResize(to targetSize: CGSize) {
        guard let window = WindowHolder.shared.window else { return }
        let current = window.frame
        let newWidth = targetSize.width
        let newHeight = targetSize.height
        // Anchor to the top-left: keep X origin fixed, maintain constant maxY (top edge)
        let topY = current.maxY
        let newOrigin = NSPoint(x: current.origin.x, y: topY - newHeight)
        let newFrame = NSRect(origin: newOrigin, size: NSSize(width: newWidth, height: newHeight))

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
}

// --- NEW HELPER VIEW FOR PRETTIER BUTTONS ---
struct PlayerButton: View {
    let systemName: String
    var fontSize: Font = .body
    var hitSize: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(fontSize)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(HoverHitButtonStyle(hitSize: hitSize))
    }
}

// A button style that increases the hit target without altering visible layout
// and shows a subtle outline on hover to communicate the clickable area.
struct HoverHitButtonStyle: ButtonStyle {
    var hitSize: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        HoverHitContainer(hitSize: hitSize,
                          isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct HoverHitContainer<Label: View>: View {
    let hitSize: CGFloat
    let isPressed: Bool
    @ViewBuilder let label: () -> Label

    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var outlineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.40) : Color.gray.opacity(0.50)
    }

    private var pressedFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.gray.opacity(0.15)
    }

    var body: some View {
        ZStack {
            // Label stays at intrinsic (e.g., 24x24) size; container provides larger hit area
            label()
        }
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .overlay(
            Circle()
                .stroke(hovering ? outlineColor : .clear,
                        lineWidth: isPressed ? 2 : 1)
        )
        .background(
            Circle()
                .fill(isPressed ? pressedFill : .clear)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

// Generic hover outline modifier for rectangular/capsule areas
private struct HoverOutline: ViewModifier {
    let cornerRadius: CGFloat
    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var outlineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.40) : Color.gray.opacity(0.50)
    }

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(hovering ? outlineColor : .clear, lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

private extension View {
    func hoverOutline(cornerRadius: CGFloat = 6) -> some View {
        self.modifier(HoverOutline(cornerRadius: cornerRadius))
    }
}

// Background container that draws a rounded material card with a shape-following shadow
// and masks only the content, keeping the shadow consistent during animations/resizes.
private struct CardContainer<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    var body: some View {
        ZStack {
            // Shape-following material background with subtle border; no outer shadow to avoid artifacts
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )

            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    PlayerView()
        .environmentObject(SpotifyAuthManager())
}
