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
            }
            saveConfig()
        }
    }
    
    @Published var workoutHistory: [WorkoutSession] = []
    
    private init() {
        // Load config from new multi-file structure
        if let loadedProfile = dataManager.loadConfig() {
            self.userProfile = loadedProfile
        } else {
            // No existing config, start with defaults
            self.userProfile = UserProfile()
        }
        
        // Load workout history from individual files
        self.workoutHistory = dataManager.loadAllWorkouts()
    }
    
    private func saveConfig() {
        do {
            try dataManager.saveConfig(userProfile)
        } catch {
            logger.error("Failed to save config: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Workout Management
    
    func addWorkout(_ workout: WorkoutSession) {
        do {
            try dataManager.saveWorkout(workout)
            workoutHistory.insert(workout, at: 0) // Insert at beginning for newest-first order
        } catch {
            logger.error("Failed to save workout \(workout.id): \(error.localizedDescription)")
        }
    }
    
    func deleteWorkout(id: UUID) {
        do {
            try dataManager.deleteWorkout(id: id)
            workoutHistory.removeAll { $0.id == id }
        } catch {
            logger.error("Failed to delete workout \(id): \(error.localizedDescription)")
        }
    }
    
    func updateWorkout(_ workout: WorkoutSession) {
        do {
            try dataManager.saveWorkout(workout)
            
            // Update local history
            if let index = workoutHistory.firstIndex(where: { $0.id == workout.id }) {
                workoutHistory[index] = workout
            }
        } catch {
            logger.error("Failed to update workout \(workout.id): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import/Export (Legacy format support)
    
    func exportData(to url: URL) throws {
        try dataManager.exportDataLegacy(to: url, userProfile: userProfile, workouts: workoutHistory)
    }
    
    func importData(from url: URL) throws {
        let (importedProfile, importedWorkouts, importedPlans) = try dataManager.importDataLegacy(from: url)
        
        // Save imported config
        self.userProfile = importedProfile
        
        // Save imported workouts individually and update local history
        for workout in importedWorkouts {
            try dataManager.saveWorkout(workout)
        }
        
        // Save imported workout plans
        for plan in importedPlans {
            try dataManager.saveUserWorkoutPlan(plan)
        }
        
        // Reload workout history from files to ensure consistency
        self.workoutHistory = dataManager.loadAllWorkouts()
        
    }
    
    // MARK: - Data Info
    
    func getDataFileInfo() -> (exists: Bool, size: String?, path: String, workoutCount: Int) {
        let exists = dataManager.dataFolderExists()
        let sizeString: String?
        
        if let size = dataManager.getDataFolderSize() {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            sizeString = formatter.string(fromByteCount: size)
        } else {
            sizeString = nil
        }
        
        let workoutCount = dataManager.getWorkoutCount()
        
        return (exists: exists, size: sizeString, path: dataManager.getDataFolderURL().path, workoutCount: workoutCount)
    }
}