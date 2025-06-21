import Foundation
import OSLog

class DataManager {
    static let shared = DataManager()
    private let logger = Logger(subsystem: "BTreadmill", category: "data")
    
    private let dataFileName = "btreadmill_data.json"
    private let documentsDirectory: URL
    private let dataFileURL: URL
    
    private init() {
        // Get the user's Documents directory for easy access and export
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dataFileURL = documentsDirectory.appendingPathComponent(dataFileName)
        logger.info("Data file location: \(self.dataFileURL.path)")
    }
    
    // MARK: - Core Data Operations
    
    func loadData() -> AppData? {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            logger.info("No existing data file found, starting fresh")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let appData = try decoder.decode(AppData.self, from: data)
            logger.info("Successfully loaded data (version \(appData.version)) with \(appData.workoutHistory.count) workouts")
            return appData
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.error("Decoding error details: \(decodingError)")
            }
            // Don't crash the app if data is corrupted - start fresh instead
            return nil
        }
    }
    
    func saveData(_ appData: AppData) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(appData)
            try data.write(to: dataFileURL)
            
            logger.info("Successfully saved data with \(appData.workoutHistory.count) workouts")
        } catch {
            logger.error("Failed to save data: \(error.localizedDescription)")
            throw AppDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    // MARK: - Import/Export Operations
    
    func exportData(to url: URL, appData: AppData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(appData)
        try data.write(to: url)
        
        logger.info("Successfully exported data to: \(url.path)")
    }
    
    func importData(from url: URL) throws -> AppData {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppDataError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let appData = try decoder.decode(AppData.self, from: data)
            logger.info("Successfully imported data (version \(appData.version)) with \(appData.workoutHistory.count) workouts from: \(url.path)")
            
            return appData
        } catch DecodingError.dataCorrupted(_) {
            throw AppDataError.corruptedData
        } catch {
            throw AppDataError.fileAccessError(error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    func getDataFileURL() -> URL {
        return dataFileURL
    }
    
    func dataFileExists() -> Bool {
        return FileManager.default.fileExists(atPath: dataFileURL.path)
    }
    
    func getDataFileSize() -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: dataFileURL.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }
    
    // MARK: - Migration Support (for future versions)
    
    private func migrateData(from oldVersion: Int, to newVersion: Int, data: Data) throws -> AppData {
        // Future migration logic will go here
        // For now, we only support version 1
        throw AppDataError.unsupportedVersion(oldVersion)
    }
}