import Foundation

// MARK: - Configuration Data File Model

struct ConfigFile: Codable {
    let version: Int
    let userProfile: UserProfile
    let createdAt: Date
    let lastModified: Date
    
    static let currentVersion = 1
    
    init(userProfile: UserProfile) {
        self.version = ConfigFile.currentVersion
        self.userProfile = userProfile
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.version = try container.decode(Int.self, forKey: .version)
        
        switch version {
        case 1:
            self.userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
            self.createdAt = try container.decode(Date.self, forKey: .createdAt)
            self.lastModified = try container.decode(Date.self, forKey: .lastModified)
        default:
            throw ConfigDataError.unsupportedVersion(version)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(userProfile, forKey: .userProfile)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(Date(), forKey: .lastModified) // Always update on save
    }
    
    private enum CodingKeys: String, CodingKey {
        case version
        case userProfile
        case createdAt
        case lastModified
    }
}

enum ConfigDataError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case fileNotFound
    case corruptedData
    case fileAccessError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported config version: \(version). Please update the app."
        case .fileNotFound:
            return "Configuration file not found."
        case .corruptedData:
            return "Configuration file is corrupted or invalid."
        case .fileAccessError(let message):
            return "Configuration file access error: \(message)"
        }
    }
}