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
        
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
        
        // Migrate from legacy format if needed
        migrateLegacyDataIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: dataFolderURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: workoutsFolderURL, withIntermediateDirectories: true)
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
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let configFile = try decoder.decode(ConfigFile.self, from: data)
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
            
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription)")
            throw ConfigDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    func loadWorkout(id: UUID) -> WorkoutSession? {
        // First try to find the file by searching through all workout files
        guard let fileName = findWorkoutFileName(for: id) else {
            return nil
        }
        
        let workoutFileURL = workoutsFolderURL.appendingPathComponent(fileName)
        
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
        let fileName = generateWorkoutFileName(for: workout)
        let workoutFileURL = workoutsFolderURL.appendingPathComponent(fileName)
        
        do {
            let workoutFile = WorkoutDataFile(workout: workout)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(workoutFile)
            try data.write(to: workoutFileURL)
            
        } catch {
            logger.error("Failed to save workout \(workout.id): \(error.localizedDescription)")
            throw WorkoutDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    func deleteWorkout(id: UUID) throws {
        // Find the actual filename for this workout
        guard let fileName = findWorkoutFileName(for: id) else {
            return // File doesn't exist, nothing to delete
        }
        
        let workoutFileURL = workoutsFolderURL.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: workoutFileURL)
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
            
        } catch {
            logger.error("Failed to load workouts: \(error.localizedDescription)")
        }
        
        return workouts.sorted { $0.actualStartDate > $1.actualStartDate }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateWorkoutFileName(for workout: WorkoutSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.timeZone = TimeZone.current
        
        let baseName = formatter.string(from: workout.actualStartDate)
        let suffix = workout.isDemo ? "-demo.json" : ".json"
        let fileName = "\(baseName)\(suffix)"
        
        // Check if file already exists and append counter if needed
        let baseURL = workoutsFolderURL.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            return fileName
        }
        
        // File exists, append counter
        var counter = 1
        while true {
            let numberedFileName = workout.isDemo ? "\(baseName)_\(counter)-demo.json" : "\(baseName)_\(counter).json"
            let numberedURL = workoutsFolderURL.appendingPathComponent(numberedFileName)
            if !FileManager.default.fileExists(atPath: numberedURL.path) {
                return numberedFileName
            }
            counter += 1
        }
    }
    
    private func findWorkoutFileName(for workoutId: UUID) -> String? {
        do {
            let workoutFiles = try FileManager.default.contentsOfDirectory(at: workoutsFolderURL, includingPropertiesForKeys: nil)
            
            for fileURL in workoutFiles where fileURL.pathExtension == "json" {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let workoutFile = try decoder.decode(WorkoutDataFile.self, from: data)
                
                if workoutFile.workout.id == workoutId {
                    return fileURL.lastPathComponent
                }
            }
        } catch {
            logger.error("Failed to search for workout file: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Import/Export Operations (Legacy single-file support)
    
    func exportDataLegacy(to url: URL, userProfile: UserProfile, workouts: [WorkoutSession]) throws {
        let appData = AppData(userProfile: userProfile, workoutHistory: workouts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(appData)
        try data.write(to: url)
        
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