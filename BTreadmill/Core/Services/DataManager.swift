import Foundation
import OSLog

class DataManager {
    static let shared = DataManager()
    private let logger = Logger(subsystem: "BTreadmill", category: "data")
    
    // New multi-file structure
    private let dataFolderName = "BTreadmillData"
    private let configFileName = "config.json"
    private let workoutsFolderName = "workouts"
    
    private let documentsDirectory: URL
    private let dataFolderURL: URL
    private let configFileURL: URL
    private let workoutsFolderURL: URL
    
    // Legacy single file (for migration)
    private let legacyDataFileName = "btreadmill_data.json"
    private let legacyDataFileURL: URL
    
    private init() {
        // Get the user's Documents directory for easy access and export
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dataFolderURL = documentsDirectory.appendingPathComponent(dataFolderName)
        configFileURL = dataFolderURL.appendingPathComponent(configFileName)
        workoutsFolderURL = dataFolderURL.appendingPathComponent(workoutsFolderName)
        legacyDataFileURL = documentsDirectory.appendingPathComponent(legacyDataFileName)
        
        logger.info("Data folder location: \(self.dataFolderURL.path)")
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
        
        // Migrate from legacy format if needed
        migrateLegacyDataIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: dataFolderURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: workoutsFolderURL, withIntermediateDirectories: true)
            logger.info("Created data directories")
        } catch {
            logger.error("Failed to create data directories: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Legacy Migration
    
    private func migrateLegacyDataIfNeeded() {
        guard FileManager.default.fileExists(atPath: legacyDataFileURL.path),
              !FileManager.default.fileExists(atPath: configFileURL.path) else {
            return // No legacy file or already migrated
        }
        
        logger.info("Migrating legacy data format...")
        
        do {
            let data = try Data(contentsOf: legacyDataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyAppData = try decoder.decode(AppData.self, from: data)
            
            // Save config
            try saveConfig(legacyAppData.userProfile)
            
            // Save individual workouts
            for workout in legacyAppData.workoutHistory {
                try saveWorkout(workout)
            }
            
            logger.info("Successfully migrated \(legacyAppData.workoutHistory.count) workouts from legacy format")
            
            // Archive the old file
            let archivedURL = legacyDataFileURL.appendingPathExtension("archived")
            try FileManager.default.moveItem(at: legacyDataFileURL, to: archivedURL)
            
        } catch {
            logger.error("Failed to migrate legacy data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Core Data Operations
    
    func loadConfig() -> UserProfile? {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            logger.info("No existing config file found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let configFile = try decoder.decode(ConfigFile.self, from: data)
            logger.info("Successfully loaded config (version \(configFile.version))")
            return configFile.userProfile
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveConfig(_ userProfile: UserProfile) throws {
        do {
            let configFile = ConfigFile(userProfile: userProfile)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(configFile)
            try data.write(to: configFileURL)
            
            logger.info("Successfully saved config")
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription)")
            throw ConfigDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    func loadWorkout(id: UUID) -> WorkoutSession? {
        let workoutFileURL = workoutsFolderURL.appendingPathComponent("\(id.uuidString).json")
        
        guard FileManager.default.fileExists(atPath: workoutFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: workoutFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let workoutFile = try decoder.decode(WorkoutDataFile.self, from: data)
            return workoutFile.workout
        } catch {
            logger.error("Failed to load workout \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveWorkout(_ workout: WorkoutSession) throws {
        let workoutFileURL = workoutsFolderURL.appendingPathComponent("\(workout.id.uuidString).json")
        
        do {
            let workoutFile = WorkoutDataFile(workout: workout)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(workoutFile)
            try data.write(to: workoutFileURL)
            
            logger.info("Successfully saved workout: \(workout.id)")
        } catch {
            logger.error("Failed to save workout \(workout.id): \(error.localizedDescription)")
            throw WorkoutDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    func deleteWorkout(id: UUID) throws {
        let workoutFileURL = workoutsFolderURL.appendingPathComponent("\(id.uuidString).json")
        
        guard FileManager.default.fileExists(atPath: workoutFileURL.path) else {
            return // File doesn't exist, nothing to delete
        }
        
        do {
            try FileManager.default.removeItem(at: workoutFileURL)
            logger.info("Successfully deleted workout: \(id)")
        } catch {
            logger.error("Failed to delete workout \(id): \(error.localizedDescription)")
            throw WorkoutDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    func loadAllWorkouts() -> [WorkoutSession] {
        var workouts: [WorkoutSession] = []
        
        do {
            let workoutFiles = try FileManager.default.contentsOfDirectory(at: workoutsFolderURL, includingPropertiesForKeys: nil)
            
            for fileURL in workoutFiles where fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let workoutFile = try decoder.decode(WorkoutDataFile.self, from: data)
                workouts.append(workoutFile.workout)
            }
            
            logger.info("Successfully loaded \(workouts.count) workouts")
        } catch {
            logger.error("Failed to load workouts: \(error.localizedDescription)")
        }
        
        return workouts.sorted { $0.actualStartDate > $1.actualStartDate }
    }
    
    // MARK: - Import/Export Operations (Legacy single-file support)
    
    func exportDataLegacy(to url: URL, userProfile: UserProfile, workouts: [WorkoutSession]) throws {
        let appData = AppData(userProfile: userProfile, workoutHistory: workouts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(appData)
        try data.write(to: url)
        
        logger.info("Successfully exported legacy data to: \(url.path)")
    }
    
    func importDataLegacy(from url: URL) throws -> (UserProfile, [WorkoutSession]) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppDataError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let appData = try decoder.decode(AppData.self, from: data)
            logger.info("Successfully imported legacy data (version \(appData.version)) with \(appData.workoutHistory.count) workouts from: \(url.path)")
            
            return (appData.userProfile, appData.workoutHistory)
        } catch DecodingError.dataCorrupted(_) {
            throw AppDataError.corruptedData
        } catch {
            throw AppDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    func getDataFolderURL() -> URL {
        return dataFolderURL
    }
    
    func getConfigFileURL() -> URL {
        return configFileURL
    }
    
    func getWorkoutsFolderURL() -> URL {
        return workoutsFolderURL
    }
    
    func dataFolderExists() -> Bool {
        return FileManager.default.fileExists(atPath: dataFolderURL.path)
    }
    
    func getDataFolderSize() -> Int64? {
        guard let enumerator = FileManager.default.enumerator(at: dataFolderURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    func getWorkoutCount() -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: workoutsFolderURL, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }.count
        } catch {
            return 0
        }
    }
}