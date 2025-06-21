import Foundation

// MARK: - Versioned App Data Model

struct AppData: Codable {
    let version: Int
    let userProfile: UserProfile
    let workoutHistory: [WorkoutSession]
    let createdAt: Date
    let lastModified: Date
    
    static let currentVersion = 1
    
    init(userProfile: UserProfile, workoutHistory: [WorkoutSession]) {
        self.version = AppData.currentVersion
        self.userProfile = userProfile
        self.workoutHistory = workoutHistory
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Version is required for future migration logic
        self.version = try container.decode(Int.self, forKey: .version)
        
        // Handle version compatibility here
        switch version {
        case 1:
            self.userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
            self.workoutHistory = try container.decode([WorkoutSession].self, forKey: .workoutHistory)
            self.createdAt = try container.decode(Date.self, forKey: .createdAt)
            self.lastModified = try container.decode(Date.self, forKey: .lastModified)
        default:
            throw AppDataError.unsupportedVersion(version)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(userProfile, forKey: .userProfile)
        try container.encode(workoutHistory, forKey: .workoutHistory)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(Date(), forKey: .lastModified) // Always update lastModified on save
    }
    
    private enum CodingKeys: String, CodingKey {
        case version
        case userProfile
        case workoutHistory
        case createdAt
        case lastModified
    }
}

enum AppDataError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case fileNotFound
    case corruptedData
    case fileAccessError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported data version: \(version). Please update the app."
        case .fileNotFound:
            return "Data file not found."
        case .corruptedData:
            return "Data file is corrupted or invalid."
        case .fileAccessError(let message):
            return "File access error: \(message)"
        }
    }
}