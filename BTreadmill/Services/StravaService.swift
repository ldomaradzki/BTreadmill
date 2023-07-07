//
//  StravaService.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 01/07/2023.
//

import Foundation
import OAuth2
import OSLog

class StravaService {
    private let clientId = "109886"
    private let clientSecret = "3f5ad80cbf782e55f2fc684b8a263c386de3a3c5"
    private let host = "https://www.strava.com"
    private let logger = Logger(subsystem: "Strava", category: "connection")
    
    private lazy var oauth2: OAuth2CodeGrant = {
        let oauth2 = OAuth2CodeGrant(settings: [
            "client_id": clientId,
            "client_secret": clientSecret,
            "authorize_uri": "\(host)/oauth/authorize",
            "token_uri": "\(host)/oauth/token?client_id=\(clientId)&client_secret=\(clientSecret)",
            "redirect_uris": ["http://localhost"],
            "scope": "read,activity:write",
            "secret_in_body": false,
            "keychain": false,
        ] as OAuth2JSON)
        oauth2.authConfig.ui.useAuthenticationSession = true
        oauth2.authConfig.authorizeEmbedded = true
        oauth2.logger = OAuth2DebugLogger(.trace)
        return oauth2
    }()
    
    private var activitiesComponents: URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.strava.com"
        components.path = "/api/v3/activities"
        return components
    }
    
    private lazy var dateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = .current
        return dateFormatter
    }()
    
    // MARK: - Public
    
    struct StravaResponse: Codable {
        let id: Int
    }
    
    func sendPost(startDate: Date, elapsedTimeSeconds: Int, distanceMeters: Double) async -> Int? {
        await withCheckedContinuation { continuation in
            var components = activitiesComponents
            components.queryItems = [
                URLQueryItem(name: "name", value: "Treadmill Walk"),
                URLQueryItem(name: "sport_type", value: "VirtualRun"),
                URLQueryItem(name: "start_date_local", value: dateFormatter.string(from: startDate)),
                URLQueryItem(name: "elapsed_time", value: "\(elapsedTimeSeconds)"),
                URLQueryItem(name: "trainer", value: "1"),
                URLQueryItem(name: "distance", value: "\(distanceMeters)"),
                URLQueryItem(name: "description", value: "Uploaded from BTreadmill app. Setup: treadmill and standing desk.")
            ]

            var req = oauth2.request(forURL: components.url!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let loader = OAuth2DataLoader(oauth2: oauth2)
            loader.perform(request: req) { [weak self] response in
                if let error = response.error {
                    continuation.resume(returning: nil)
                    self?.logger.error("\(error.localizedDescription)")
                } else if let data = response.data, let body = String(data: data, encoding: .utf8) {
                    if let id = (try? JSONDecoder().decode(StravaResponse.self, from: data))?.id {
                        continuation.resume(returning: id)
                    } else {
                        continuation.resume(returning: nil)
                    }
                    
                    self?.logger.info("\(body)")
                }
            }
        }
    }
}
