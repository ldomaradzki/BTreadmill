import Foundation
import OAuth2
import OSLog
import AuthenticationServices

@MainActor
class StravaService: ObservableObject {
    static let shared = StravaService()
    
    private let logger = Logger(subsystem: "BTreadmill", category: "strava")
    
    // Strava API Configuration
    private let clientId = "109886"
    private let host = "https://www.strava.com"
    private let anchor = ASPresentationAnchor()
    
    @Published var isAuthenticated = false
    @Published var isUploading = false
    @Published var isAuthenticating = false
    @Published var authenticationDetails: String = ""
    @Published var hasValidClientSecret = false
    
    private var oauth2: OAuth2CodeGrant?
    
    private init() {
        // Check if we have a valid client secret and initialize OAuth2
        updateOAuth2Configuration()
        // Check if we already have a valid access token
        updateAuthenticationStatus()
    }
    
    // MARK: - Configuration
    
    private func updateOAuth2Configuration() {
        guard let clientSecret = SettingsManager.shared.userProfile.stravaClientSecret,
              !clientSecret.isEmpty else {
            hasValidClientSecret = false
            oauth2 = nil
            isAuthenticated = false
            authenticationDetails = "Client secret not configured"
            return
        }
        
        hasValidClientSecret = true
        
        oauth2 = OAuth2CodeGrant(settings: [
            "client_id": clientId,
            "client_secret": clientSecret,
            "authorize_uri": "\(host)/oauth/authorize",
            "token_uri": "\(host)/oauth/token?client_id=\(clientId)&client_secret=\(clientSecret)",
            "redirect_uris": ["http://localhost"],
            "scope": "read,activity:write",
            "secret_in_body": false,
            "keychain": true,
            "keychain_access_group": "com.lukasz.btreadmill.strava",
        ] as OAuth2JSON)
        
        oauth2?.authConfig.ui.useAuthenticationSession = true
        oauth2?.authConfig.authorizeEmbedded = true
        oauth2?.authConfig.ui.useSafariView = false
        oauth2?.authConfig.authorizeContext = anchor
    }
    
    func updateClientSecret(_ secret: String?) {
        // Update the settings
        SettingsManager.shared.userProfile.stravaClientSecret = secret
        
        // Reconfigure OAuth2
        updateOAuth2Configuration()
        
        // Update authentication status
        updateAuthenticationStatus()
    }
    
    // MARK: - Authentication
    
    func authenticate() async -> Bool {
        guard let oauth2 = oauth2 else {
            logger.error("Cannot authenticate: OAuth2 not configured (missing client secret)")
            return false
        }
        
        isAuthenticating = true
        
        let result = await withCheckedContinuation { continuation in
            oauth2.authorize { authParameters, error in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    
                    if let error = error {
                        self.logger.error("Strava authentication failed: \(error.localizedDescription)")
                        self.isAuthenticated = false
                        continuation.resume(returning: false)
                    } else {
                        self.logger.info("Strava authentication successful")
                        self.updateAuthenticationStatus()
                        
                        // Small delay to ensure authentication completes before any cleanup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // The ASWebAuthenticationSession should close automatically
                            // Ensure our app remains as menu bar app
                            NSApp.setActivationPolicy(.accessory)
                            
                            // Post notification that app became active to trigger any necessary UI restoration
                            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)
                        }
                        
                        continuation.resume(returning: true)
                    }
                }
            }
        }
        
        return result
    }
    
    func logout() {
        oauth2?.forgetTokens()
        isAuthenticated = false
        authenticationDetails = ""
        logger.info("Logged out from Strava")
    }
    
    private func updateAuthenticationStatus() {
        guard let oauth2 = oauth2 else {
            isAuthenticated = false
            authenticationDetails = hasValidClientSecret ? "" : "Client secret not configured"
            return
        }
        
        // Check for valid access token, refresh if needed
        if oauth2.hasUnexpiredAccessToken() {
            isAuthenticated = true
            authenticationDetails = "OAuth token active"
        } else if oauth2.refreshToken != nil {
            // Try to refresh the token
            Task {
                await refreshTokenIfNeeded()
            }
        } else {
            isAuthenticated = false
            authenticationDetails = ""
        }
    }
    
    private func refreshTokenIfNeeded() async {
        guard let oauth2 = oauth2,
              oauth2.refreshToken != nil else {
            isAuthenticated = false
            authenticationDetails = ""
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            oauth2.doRefreshToken { params, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.isAuthenticated = false
                        self.authenticationDetails = ""
                        self.logger.error("Failed to refresh Strava token: \(error.localizedDescription)")
                    } else {
                        self.isAuthenticated = true
                        self.authenticationDetails = "OAuth token active"
                        self.logger.info("Successfully refreshed Strava token")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Workout Upload
    
    func uploadWorkout(workout: WorkoutSession) async -> String? {
        guard let oauth2 = oauth2 else {
            logger.warning("Cannot upload workout: OAuth2 not configured (missing client secret)")
            return nil
        }
        
        guard isAuthenticated else {
            logger.warning("Attempted to upload workout without authentication")
            return nil
        }
        
        guard let fitFilePath = workout.fitFilePath,
              FileManager.default.fileExists(atPath: fitFilePath) else {
            logger.error("FIT file not found for workout: \(workout.id)")
            return nil
        }
        
        isUploading = true
        
        defer {
            isUploading = false
        }
        
        // Upload FIT file
        guard let uploadId = await uploadFITFile(fitFilePath: fitFilePath, workout: workout) else {
            logger.error("Failed to upload FIT file to Strava")
            return nil
        }
        
        // Poll for upload completion
        guard let activityId = await pollUploadStatus(uploadId: uploadId) else {
            logger.error("Failed to get activity ID from Strava upload")
            return nil
        }
        
        logger.info("Successfully uploaded workout to Strava with ID: \(activityId)")
        return String(activityId)
    }
    
    private func uploadFITFile(fitFilePath: String, workout: WorkoutSession) async -> Int? {
        guard let oauth2 = oauth2 else { return nil }
        
        return await withCheckedContinuation { continuation in
            let url = URL(string: "\(host)/api/v3/uploads")!
            let originalRequest = oauth2.request(forURL: url)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            // Copy authorization headers from OAuth2 request
            if let authHeader = originalRequest.allHTTPHeaderFields?["Authorization"] {
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            }
            
            // Create multipart form data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            guard let fitData = FileManager.default.contents(atPath: fitFilePath) else {
                self.logger.error("Failed to read FIT file at path: \(fitFilePath)")
                continuation.resume(returning: nil)
                return
            }
            
            var body = Data()
            
            // Add data_type parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"data_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("fit\r\n".data(using: .utf8)!)
            
            // Add trainer parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"trainer\"\r\n\r\n".data(using: .utf8)!)
            body.append("1\r\n".data(using: .utf8)!)
            
            // Add name parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
            body.append("Treadmill Walk\r\n".data(using: .utf8)!)
            
            // Add description parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
            body.append("Uploaded from BTreadmill app. Setup: treadmill and standing desk.\r\n".data(using: .utf8)!)
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"workout.fit\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fitData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    self.logger.error("Network error uploading FIT file to Strava: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Invalid response from Strava upload API")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let data = data else {
                    self.logger.error("No data received from Strava upload API")
                    continuation.resume(returning: nil)
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    // Success - parse the response to get the upload ID
                    do {
                        let response = try JSONDecoder().decode(StravaUploadResponse.self, from: data)
                        continuation.resume(returning: response.id)
                    } catch {
                        self.logger.error("Failed to decode Strava upload response: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                } else {
                    // Error - log the response
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    self.logger.error("Strava upload API error (\(httpResponse.statusCode)): \(responseString)")
                    continuation.resume(returning: nil)
                }
            }
            
            task.resume()
        }
    }
    
    private func pollUploadStatus(uploadId: Int) async -> Int? {
        let maxAttempts = 30 // Maximum 30 seconds of polling
        
        for attempt in 1...maxAttempts {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            
            let result = await getUploadStatus(uploadId: uploadId)
            
            switch result {
            case .completed(let activityId):
                return activityId
            case .processing:
                logger.info("Upload \(uploadId) still processing... (attempt \(attempt)/\(maxAttempts))")
                continue
            case .error(let message):
                logger.error("Upload \(uploadId) failed: \(message)")
                return nil
            }
        }
        
        logger.error("Upload \(uploadId) timed out after \(maxAttempts) attempts")
        return nil
    }
    
    private func getUploadStatus(uploadId: Int) async -> UploadStatus {
        guard let oauth2 = oauth2 else { return .error("OAuth2 not configured") }
        
        return await withCheckedContinuation { continuation in
            let url = URL(string: "\(host)/api/v3/uploads/\(uploadId)")!
            let originalRequest = oauth2.request(forURL: url)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Copy authorization headers from OAuth2 request
            if let authHeader = originalRequest.allHTTPHeaderFields?["Authorization"] {
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    self.logger.error("Network error checking upload status: \(error.localizedDescription)")
                    continuation.resume(returning: .error("Network error"))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Invalid response from Strava upload status API")
                    continuation.resume(returning: .error("Invalid response"))
                    return
                }
                
                guard let data = data else {
                    self.logger.error("No data received from Strava upload status API")
                    continuation.resume(returning: .error("No data"))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        let response = try JSONDecoder().decode(StravaUploadStatusResponse.self, from: data)
                        
                        if let activityId = response.activity_id {
                            continuation.resume(returning: .completed(activityId))
                        } else if let error = response.error {
                            continuation.resume(returning: .error(error))
                        } else {
                            continuation.resume(returning: .processing)
                        }
                    } catch {
                        self.logger.error("Failed to decode upload status response: \(error.localizedDescription)")
                        continuation.resume(returning: .error("Decode error"))
                    }
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    self.logger.error("Upload status API error (\(httpResponse.statusCode)): \(responseString)")
                    continuation.resume(returning: .error("API error"))
                }
            }
            
            task.resume()
        }
    }
    
    // MARK: - Utility
    
    func getStravaActivityURL(activityId: String) -> URL? {
        return URL(string: "\(host)/activities/\(activityId)")
    }
}

// MARK: - Response Models

struct StravaResponse: Codable {
    let id: Int
}

struct StravaUploadResponse: Codable {
    let id: Int
    let external_id: String?
    let error: String?
    let status: String?
}

struct StravaUploadStatusResponse: Codable {
    let id: Int
    let external_id: String?
    let error: String?
    let status: String?
    let activity_id: Int?
}

enum UploadStatus {
    case processing
    case completed(Int)
    case error(String)
}