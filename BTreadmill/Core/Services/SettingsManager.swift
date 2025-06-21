import Foundation
import Combine
import OSLog

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let logger = Logger(subsystem: "BTreadmill", category: "settings")
    private let dataManager = DataManager.shared
    
    @Published var userProfile: UserProfile {
        didSet {
            // Check if simulator mode changed
            if oldValue.simulatorMode != userProfile.simulatorMode {
                // Reset the shared treadmill service to use the new mode
                TreadmillService.resetShared()
                logger.info("Simulator mode changed to \(self.userProfile.simulatorMode), reset treadmill service")
            }
            saveData()
        }
    }
    
    @Published var workoutHistory: [WorkoutSession] = [] {
        didSet {
            saveData()
        }
    }
    
    private init() {
        // Load data from JSON file
        if let appData = dataManager.loadData() {
            self.userProfile = appData.userProfile
            self.workoutHistory = appData.workoutHistory
            logger.info("Loaded \(self.workoutHistory.count) workouts from data file")
        } else {
            // No existing data, start with defaults
            self.userProfile = UserProfile()
            self.workoutHistory = []
            logger.info("Starting with default user profile and empty workout history")
        }
    }
    
    private func saveData() {
        let appData = AppData(userProfile: userProfile, workoutHistory: workoutHistory)
        do {
            try dataManager.saveData(appData)
        } catch {
            logger.error("Failed to save data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Workout Management
    
    func addWorkout(_ workout: WorkoutSession) {
        workoutHistory.insert(workout, at: 0) // Insert at beginning for newest-first order
        logger.info("Added workout: \(workout.id) - Demo: \(workout.isDemo)")
    }
    
    func deleteWorkout(id: UUID) {
        workoutHistory.removeAll { $0.id == id }
        logger.info("Deleted workout: \(id)")
    }
    
    // MARK: - Import/Export
    
    func exportData(to url: URL) throws {
        let appData = AppData(userProfile: userProfile, workoutHistory: workoutHistory)
        try dataManager.exportData(to: url, appData: appData)
    }
    
    func importData(from url: URL) throws {
        let appData = try dataManager.importData(from: url)
        
        // Update the published properties (this will trigger UI updates and auto-save)
        self.userProfile = appData.userProfile
        self.workoutHistory = appData.workoutHistory
        
        logger.info("Successfully imported data with \(self.workoutHistory.count) workouts")
    }
    
    // MARK: - Data Info
    
    func getDataFileInfo() -> (exists: Bool, size: String?, path: String) {
        let exists = dataManager.dataFileExists()
        let sizeString: String?
        
        if let size = dataManager.getDataFileSize() {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            sizeString = formatter.string(fromByteCount: size)
        } else {
            sizeString = nil
        }
        
        return (exists: exists, size: sizeString, path: dataManager.getDataFileURL().path)
    }
}