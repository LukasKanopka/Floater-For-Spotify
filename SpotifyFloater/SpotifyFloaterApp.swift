// FILE: SpotifyFloaterApp.swift
// DESCRIPTION: The definitive fix using a simpler style and a modern dismiss action.

import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import AppKit

@main
struct SpotifyFloaterApp: App {
    @StateObject private var authManager = SpotifyAuthManager()
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow // Get the modern dismiss action

    var body: some Scene {
        Window("SpotifyFloater", id: "player-window") {
            ContentView()
               .environmentObject(authManager)
               .onOpenURL { url in
                   authManager.handleRedirect(url: url)
               }
               .background(WindowAccessor { window in
                   if let window = window {
                       // A much simpler and more reliable setup
                       window.styleMask = .borderless
                       window.isOpaque = false
                       window.backgroundColor = .clear
                       window.isMovableByWindowBackground = true
                       window.level = .floating
                       window.hasShadow = false // Prevent rectangular window shadow/border
                       window.invalidateShadow()
                       // Ensure rounded corners at the window layer level to avoid any rectangular flashes
                       if let contentView = window.contentView {
                           contentView.wantsLayer = true
                           if let layer = contentView.layer {
                               layer.masksToBounds = true
                               layer.cornerRadius = 50.0
                           }
                       }
                   }
               })
        }
        .windowResizability(.contentSize)
        // This command modifier is the key to making Command+W work reliably
        .commands {
            CommandGroup(replacing: .windowList) { // Or any appropriate placement
                Button("Close") {
                    dismissWindow(id: "player-window")
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }

        MenuBarExtra("SpotifyFloater", systemImage: "music.note") {
            Button("Show Player") {
                openWindow(id: "player-window")
            }

            Divider()

            Button("Quit SpotifyFloater") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}


// NOTE: The rest of this file (SpotifyAuthManager, helpers, etc.) remains exactly the same.
// No changes are needed below this line.

class SpotifyAuthManager: NSObject, ObservableObject {
    private let clientID = Secrets.spotifyClientID
    private let redirectURI = Secrets.spotifyRedirectURI
    private let authStateKey = "spotify_auth_state"

    @Published var isAuthenticated = false
    @Published var accessToken: String?

    private var refreshToken: String?
    private var webAuthSession: ASWebAuthenticationSession?

    // PKCE + OAuth state
    private var codeVerifier: String?
    private var expectedState: String?

    // Token expiry tracking
    private var expiresAt: Date?

    override init() {
        super.init()
        loadAndRefreshToken()
    }
    
    // ... (The rest of the SpotifyAuthManager code is unchanged)
    
    // MARK: - Initialization and Token Loading

    private func loadAndRefreshToken() {
        var state = loadAuthState()
        if state == nil {
            state = migrateLegacyTokensIfNeeded()
        }
        self.refreshToken = state?.refreshToken
        let storedAccess = state?.accessToken
        let storedExpiry = state?.expiresAt.map(Date.init(timeIntervalSince1970:))

        // If we have a still-valid access token, use it immediately (no login prompt)
        if let token = storedAccess, let exp = storedExpiry, Date().addingTimeInterval(120) < exp {
            self.accessToken = token
            self.expiresAt = exp
            self.isAuthenticated = true
            print("Loaded valid access token from Keychain; skipping re-auth.")
            return
        }

        // Otherwise, if we have a refresh token, try to refresh silently
        if self.refreshToken != nil {
            print("Found refresh token in Keychain. Attempting silent refresh.")
            refreshAccessToken()
        } else {
            print("No refresh token found in Keychain.")
        }
    }

    private struct AuthState: Codable {
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: Double?
    }

    private func loadAuthState() -> AuthState? {
        guard let json = KeychainService.get(authStateKey) else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AuthState.self, from: data)
    }

    private func saveAuthState(accessToken: String?, refreshToken: String?, expiresAt: Date?) {
        let state = AuthState(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt.map { $0.timeIntervalSince1970 }
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        guard let json = String(data: data, encoding: .utf8) else { return }
        _ = KeychainService.set(json, for: authStateKey)
    }

    private func clearAuthState() {
        _ = KeychainService.delete(authStateKey)
        // Also clear legacy keys just in case user is upgrading/downgrading between builds.
        _ = KeychainService.delete("spotify_refresh_token")
        _ = KeychainService.delete("spotify_access_token")
        _ = KeychainService.delete("spotify_expires_at")
        UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
    }

    private func migrateLegacyTokensIfNeeded() -> AuthState? {
        // Legacy storage: 3 separate Keychain items + (very old) UserDefaults refresh token.
        let legacyAccess = KeychainService.get("spotify_access_token")
        let legacyRefreshFromKeychain = KeychainService.get("spotify_refresh_token")
        let legacyRefreshFromDefaults = UserDefaults.standard.string(forKey: "spotify_refresh_token")
        let legacyRefresh = legacyRefreshFromKeychain ?? legacyRefreshFromDefaults
        let legacyExpiry = KeychainService.get("spotify_expires_at").flatMap(Double.init)

        if legacyAccess == nil && legacyRefresh == nil && legacyExpiry == nil {
            return nil
        }

        let expiryDate = legacyExpiry.map(Date.init(timeIntervalSince1970:))
        saveAuthState(accessToken: legacyAccess, refreshToken: legacyRefresh, expiresAt: expiryDate)
        let migratedState = AuthState(accessToken: legacyAccess, refreshToken: legacyRefresh, expiresAt: legacyExpiry)

        // Remove legacy items to reduce repeated Keychain prompts.
        _ = KeychainService.delete("spotify_refresh_token")
        _ = KeychainService.delete("spotify_access_token")
        _ = KeychainService.delete("spotify_expires_at")
        if legacyRefreshFromDefaults != nil {
            UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
        }

        print("Migrated legacy Spotify tokens to a single Keychain item.")
        return migratedState
    }

    // MARK: - Authentication Flow

    func startAuthentication() {
        let scopes = "user-read-playback-state user-modify-playback-state user-library-modify user-library-read"

        // Generate PKCE and state
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = codeChallengeS256(for: verifier)
        let state = randomState()
        self.expectedState = state

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state)
        ]

        guard let authURL = components.url else {
            print("Error: Invalid authorization URL")
            return
        }

        self.webAuthSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: Secrets.spotifyCallbackURLScheme) { [weak self] callbackURL, error in
            guard let callbackURL = callbackURL, error == nil else {
                print("Authentication session failed with error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self?.handleRedirect(url: callbackURL)
        }

        webAuthSession?.presentationContextProvider = self
        webAuthSession?.start()
    }

    func handleRedirect(url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems
        if let error = items?.first(where: { $0.name == "error" })?.value {
            print("Auth error: \(error)")
            return
        }
        let returnedState = items?.first(where: { $0.name == "state" })?.value
        guard returnedState == expectedState else {
            print("State mismatch. Potential CSRF. Aborting.")
            return
        }
        guard let code = items?.first(where: { $0.name == "code" })?.value else {
            print("Invalid callback URL. Could not find authorization code.")
            return
        }
        exchangeCodeForTokens(code: code)
    }

    private func exchangeCodeForTokens(code: String) {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: self.codeVerifier ?? "")
        ]
        request.httpBody = components.query?.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Error exchanging token: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.accessToken = tokenResponse.access_token
                    self?.refreshToken = tokenResponse.refresh_token
                    let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                    self?.expiresAt = expiry
                    self?.isAuthenticated = true

                    // Persist tokens to Keychain as a single item (reduces repeated prompts).
                    self?.saveAuthState(accessToken: tokenResponse.access_token, refreshToken: tokenResponse.refresh_token, expiresAt: expiry)
                }
            } catch {
                print("Failed to decode token response: \(error)")
            }
        }.resume()
    }

    func logOut() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        isAuthenticated = false
        clearAuthState()
    }

    // Wrapper to maintain existing call sites
    func refreshAccessToken() {
        refreshAccessToken { _ in }
    }

    // Completion-based refresh to enable 401 refresh-and-retry flows
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let token = self.refreshToken else {
            print("refreshAccessToken: No refresh token available.")
            completion(false)
            return
        }
        self.refreshToken = token

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: token),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Network or transport error: do NOT delete refresh token; allow retry on next launch
            if let error = error {
                print("refreshAccessToken: Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Keep isAuthenticated as-is; caller/UI can decide what to show
                    completion(false)
                }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                print("refreshAccessToken: No HTTP response")
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Read body (may be nil on certain failures)
            let body = data ?? Data()

            // Spotify returns JSON on errors; detect invalid_grant to revoke local token
            if !(200...299).contains(http.statusCode) {
                // Try to parse error payload
                struct SpotifyErrorPayload: Decodable { let error: String?; let error_description: String? }
                let payload = (try? JSONDecoder().decode(SpotifyErrorPayload.self, from: body))
                let code = payload?.error ?? ""
                let desc = payload?.error_description ?? ""
                print("refreshAccessToken: HTTP \(http.statusCode) error=\(code) desc=\(desc)")

                // Only delete refresh token if Spotify says it's invalid (revoked/expired)
                if http.statusCode == 400 && code == "invalid_grant" {
                    self?.refreshToken = nil
                    DispatchQueue.main.async {
                        self?.isAuthenticated = false
                        self?.clearAuthState()
                        print("refreshAccessToken: Refresh token invalid; cleared from Keychain.")
                        completion(false)
                    }
                } else {
                    // Keep refresh token for future retries; transient errors should not force re-login
                    DispatchQueue.main.async {
                        print("refreshAccessToken: Transient error; keeping stored refresh token.")
                        completion(false)
                    }
                }
                return
            }

            // Success path: decode token response
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: body)
                DispatchQueue.main.async {
                    self?.accessToken = tokenResponse.access_token
                    if let newRefreshToken = tokenResponse.refresh_token {
                        self?.refreshToken = newRefreshToken
                        print("refreshAccessToken: Updated and saved new refresh token.")
                    } else {
                        print("refreshAccessToken: No new refresh token received.")
                    }
                    let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                    self?.expiresAt = expiry
                    self?.isAuthenticated = true
                    if let self = self {
                        self.saveAuthState(accessToken: self.accessToken, refreshToken: self.refreshToken, expiresAt: self.expiresAt)
                    }
                    print("refreshAccessToken: Successfully refreshed token. isAuthenticated is now true.")
                    completion(true)
                }
            } catch {
                // Decode error shouldn't wipe the refresh token; might be a transient API change/issue
                print("refreshAccessToken: Failed to decode refresh token response: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }.resume()
    }

    // MARK: - API Calls

    private func makeAPIRequest<T: Decodable>(endpoint: String, method: String, didRetry: Bool = false, completion: @escaping (Result<T, Error>) -> Void) {
        ensureValidAccessToken { [weak self] valid in
            guard let self = self, valid, let token = self.accessToken else {
                completion(.failure(APIError.notAuthenticated))
                return
            }

            guard let url = URL(string: "https://api.spotify.com\(endpoint)") else {
                completion(.failure(APIError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.badResponse(statusCode: 500)))
                    return
                }

                // Handle expired/invalid token with single refresh-and-retry
                if httpResponse.statusCode == 401 && !didRetry {
                    self.refreshAccessToken { success in
                        if success {
                            self.makeAPIRequest(endpoint: endpoint, method: method, didRetry: true, completion: completion)
                        } else {
                            completion(.failure(APIError.badResponse(statusCode: httpResponse.statusCode)))
                        }
                    }
                    return
                }

                // Handle rate limiting with a one-time retry using Retry-After header if present
                if httpResponse.statusCode == 429 && !didRetry {
                    let retryAfter = (httpResponse.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init) ?? 1.0
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryAfter) {
                        self.makeAPIRequest(endpoint: endpoint, method: method, didRetry: true, completion: completion)
                    }
                    return
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    completion(.failure(APIError.badResponse(statusCode: httpResponse.statusCode)))
                    return
                }

                guard let data = data, !data.isEmpty else {
                    completion(.failure(APIError.noData))
                    return
                }

                do {
                    let decodedObject = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedObject))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
    }

    private func makeAPICallWithoutDecoding(endpoint: String, method: String, didRetry: Bool = false, completion: @escaping (Error?) -> Void) {
        ensureValidAccessToken { [weak self] valid in
            guard let self = self, valid, let token = self.accessToken else {
                completion(APIError.notAuthenticated)
                return
            }
            guard let url = URL(string: "https://api.spotify.com\(endpoint)") else {
                completion(APIError.invalidURL)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("API Error for \(endpoint): \(error.localizedDescription)")
                    completion(error)
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 && !didRetry {
                        self.refreshAccessToken { success in
                            if success {
                                self.makeAPICallWithoutDecoding(endpoint: endpoint, method: method, didRetry: true, completion: completion)
                            } else {
                                completion(APIError.badResponse(statusCode: httpResponse.statusCode))
                            }
                        }
                        return
                    }
                    if httpResponse.statusCode == 429 && !didRetry {
                        let retryAfter = (httpResponse.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init) ?? 1.0
                        DispatchQueue.global().asyncAfter(deadline: .now() + retryAfter) {
                            self.makeAPICallWithoutDecoding(endpoint: endpoint, method: method, didRetry: true, completion: completion)
                        }
                        return
                    }
                    if !(200...299).contains(httpResponse.statusCode) {
                        let apiError = APIError.badResponse(statusCode: httpResponse.statusCode)
                        print("API Error for \(endpoint): Status Code \(httpResponse.statusCode)")
                        completion(apiError)
                        return
                    }
                }
                print("Successfully performed action: \(endpoint)")
                completion(nil)
            }.resume()
        }
    }

    enum PlayerEndpoint: String {
        case play = "/v1/me/player/play"
        case pause = "/v1/me/player/pause"
        case next = "/v1/me/player/next"
        case previous = "/v1/me/player/previous"
    }

    // UPDATED: Now includes a completion handler to report success or failure.
    func performPlayerAction(endpoint: PlayerEndpoint, completion: @escaping (Error?) -> Void) {
        let method = (endpoint == .next || endpoint == .previous) ? "POST" : "PUT"
        makeAPICallWithoutDecoding(endpoint: endpoint.rawValue, method: method, completion: completion)
    }

    // Specialized handler to gracefully manage 204 (no content) and 401 refresh-and-retry
    func getCurrentTrack(completion: @escaping (Result<SpotifyTrackResponse, Error>) -> Void) {
        requestCurrentTrack(didRetry: false, completion: completion)
    }

    private func requestCurrentTrack(didRetry: Bool, completion: @escaping (Result<SpotifyTrackResponse, Error>) -> Void) {
        ensureValidAccessToken { [weak self] valid in
            guard let self = self, valid, let token = self.accessToken else {
                completion(.failure(APIError.notAuthenticated))
                return
            }
            guard let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
                completion(.failure(APIError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.badResponse(statusCode: 500)))
                    return
                }

                switch httpResponse.statusCode {
                case 200...299:
                    if let data = data, !data.isEmpty {
                        do {
                            let decoded = try JSONDecoder().decode(SpotifyTrackResponse.self, from: data)
                            completion(.success(decoded))
                        } catch {
                            completion(.failure(error))
                        }
                    } else {
                        // Treat empty 2xx body as idle/no song
                        completion(.success(SpotifyTrackResponse(item: nil, is_playing: false)))
                    }
                case 204:
                    // No content when nothing is playing
                    completion(.success(SpotifyTrackResponse(item: nil, is_playing: false)))
                case 401:
                    if didRetry {
                        completion(.failure(APIError.badResponse(statusCode: 401)))
                    } else {
                        self.refreshAccessToken { success in
                            if success {
                                self.requestCurrentTrack(didRetry: true, completion: completion)
                            } else {
                                completion(.failure(APIError.badResponse(statusCode: 401)))
                            }
                        }
                    }
                case 429:
                    if !didRetry {
                        let retryAfter = (httpResponse.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init) ?? 1.0
                        DispatchQueue.global().asyncAfter(deadline: .now() + retryAfter) {
                            self.requestCurrentTrack(didRetry: true, completion: completion)
                        }
                    } else {
                        completion(.failure(APIError.badResponse(statusCode: 429)))
                    }
                default:
                    completion(.failure(APIError.badResponse(statusCode: httpResponse.statusCode)))
                }
            }.resume()
        }
    }

    func addToFavorites(trackId: String, completion: @escaping (Error?) -> Void) {
        makeAPICallWithoutDecoding(endpoint: "/v1/me/tracks?ids=\(trackId)", method: "PUT", completion: completion)
    }

    func removeFromFavorites(trackId: String, completion: @escaping (Error?) -> Void) {
        makeAPICallWithoutDecoding(endpoint: "/v1/me/tracks?ids=\(trackId)", method: "DELETE", completion: completion)
    }

    func checkIfTrackIsSaved(trackId: String, completion: @escaping (Result<[Bool], Error>) -> Void) {
        makeAPIRequest(endpoint: "/v1/me/tracks/contains?ids=\(trackId)", method: "GET", completion: completion)
    }
    // MARK: - PKCE and Token Helpers

    private func ensureValidAccessToken(completion: @escaping (Bool) -> Void) {
        if let expiresAt = self.expiresAt {
            // Refresh if expiring within 120 seconds
            if Date().addingTimeInterval(120) >= expiresAt {
                self.refreshAccessToken(completion: completion)
                return
            }
            completion(self.accessToken != nil)
        } else {
            // If no known expiry, try to refresh if we have a refresh token
            if self.accessToken != nil {
                completion(true)
            } else if self.refreshToken != nil {
                self.refreshAccessToken(completion: completion)
            } else {
                completion(false)
            }
        }
    }

    private func generateCodeVerifier() -> String {
        return randomString(length: 64) // within 43...128
    }

    private func randomState() -> String {
        return randomString(length: 32)
    }

    private func randomString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                result.append(charset[Int(random) % charset.count])
            } else {
                result.append(charset.randomElement()!)
            }
        }
        return result
    }

    private func codeChallengeS256(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Helper Models
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
}

enum APIError: Error {
    case notAuthenticated
    case invalidURL
    case badResponse(statusCode: Int)
    case noData
}

// Helper to access the NSWindow
final class WindowHolder: ObservableObject {
    static let shared = WindowHolder()
    weak var window: NSWindow?
    private init() {}
}

struct WindowAccessor: NSViewRepresentable {
   var callback: (NSWindow?) -> Void

   func makeNSView(context: Context) -> NSView {
       let view = NSView()
       DispatchQueue.main.async { [weak view] in
           let win = view?.window
           WindowHolder.shared.window = win
           self.callback(win)
       }
       return view
   }

   func updateNSView(_ nsView: NSView, context: Context) {}
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
   func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
       return NSApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
   }
}
