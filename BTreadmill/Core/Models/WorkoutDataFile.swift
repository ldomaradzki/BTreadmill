import Foundation

// MARK: - Individual Workout Data File Model

struct WorkoutDataFile: Codable {
    let version: Int
    let workout: WorkoutSession
    let createdAt: Date
    let lastModified: Date
    
    static let currentVersion = 1
    
    init(workout: WorkoutSession) {
        self.version = WorkoutDataFile.currentVersion
        self.workout = workout
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.version = try container.decode(Int.self, forKey: .version)
        
        switch version {
        case 1:
            self.workout = try container.decode(WorkoutSession.self, forKey: .workout)
            self.createdAt = try container.decode(Date.self, forKey: .createdAt)
            self.lastModified = try container.decode(Date.self, forKey: .lastModified)
        default:
            throw WorkoutDataError.unsupportedVersion(version)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(workout, forKey: .workout)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(Date(), forKey: .lastModified) // Always update on save
    }
    
    private enum CodingKeys: String, CodingKey {
        case version
        case workout
        case createdAt
        case lastModified
    }
}

enum WorkoutDataError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case fileNotFound
    case corruptedData
    case fileAccessError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported workout data version: \(version). Please update the app."
        case .fileNotFound:
            return "Workout data file not found."
        case .corruptedData:
            return "Workout data file is corrupted or invalid."
        case .fileAccessError(let message):
            return "Workout file access error: \(message)"
        }
    }
}