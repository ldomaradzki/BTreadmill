import Foundation
import Combine

class WorkoutPlanManager: ObservableObject {
    @Published var availablePlans: [WorkoutPlan] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    
    private let fileManager = FileManager.default
    
    init() {
        loadPlans()
    }
    
    // MARK: - Plan Loading
    
    func loadPlans() {
        isLoading = true
        loadError = nil
        
        Task {
            do {
                let plans = try await loadPlansFromDirectory()
                await MainActor.run {
                    self.availablePlans = plans.sorted { $0.name < $1.name }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = "Failed to load plans: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadPlansFromDirectory() async throws -> [WorkoutPlan] {
        var allPlans: [WorkoutPlan] = []
        
        // 1. Load bundled default plans from app bundle
        if let bundledPlans = try? loadBundledPlans() {
            allPlans.append(contentsOf: bundledPlans)
            print("✅ Loaded \(bundledPlans.count) bundled workout plans")
        }
        
        // 2. Load user plans from Documents/BTreadmillData/plans/
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let userPlansPath = documentsPath.appendingPathComponent("BTreadmillData/plans")
        
        // Create user plans directory if it doesn't exist
        if !fileManager.fileExists(atPath: userPlansPath.path) {
            try fileManager.createDirectory(at: userPlansPath, withIntermediateDirectories: true)
            print("📁 Created user plans directory: \(userPlansPath.path)")
        }
        
        if let userPlans = try? loadPlansFromPath(userPlansPath) {
            allPlans.append(contentsOf: userPlans)
            print("✅ Loaded \(userPlans.count) user workout plans")
        }
        
        return allPlans
    }
    
    private func loadBundledPlans() throws -> [WorkoutPlan] {
        // Try multiple approaches to find bundled workout plans
        
        // Method 1: Look for WorkoutPlans directory
        if let bundlePath = Bundle.main.path(forResource: "WorkoutPlans", ofType: nil) {
            print("📁 Found WorkoutPlans directory at: \(bundlePath)")
            let bundleURL = URL(fileURLWithPath: bundlePath)
            return try loadPlansFromPath(bundleURL)
        }
        
        // Method 2: Look for individual JSON files in bundle
        let bundleURL = Bundle.main.bundleURL
        print("📦 Bundle URL: \(bundleURL)")
        
        // List all resources in bundle for debugging
        if let resourcePath = Bundle.main.resourcePath {
            print("📂 Resource path: \(resourcePath)")
            let resourceURL = URL(fileURLWithPath: resourcePath)
            if let contents = try? fileManager.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                print("📋 Bundle contents: \(contents.map { $0.lastPathComponent })")
            }
        }
        
        // Try to find JSON files directly in Resources
        if let allJsonFiles = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            let jsonFiles = allJsonFiles.filter { !$0.lastPathComponent.contains(".sample.") }
            print("📄 Found \(jsonFiles.count) active JSON files in bundle (filtered out sample files)")
            var plans: [WorkoutPlan] = []
            
            for file in jsonFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)
                    
                    let validationErrors = validatePlan(plan)
                    if validationErrors.isEmpty {
                        plans.append(plan)
                        print("✅ Loaded plan: \(plan.name)")
                    } else {
                        print("⚠️ Invalid plan '\(plan.name)': \(validationErrors.joined(separator: ", "))")
                    }
                } catch {
                    print("❌ Failed to load plan from \(file.lastPathComponent): \(error)")
                }
            }
            
            return plans
        }
        
        print("ℹ️ No bundled workout plans found")
        return []
    }
    
    private func loadPlansFromPath(_ path: URL) throws -> [WorkoutPlan] {
        let jsonFiles = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.contains(".sample.") }
        
        var plans: [WorkoutPlan] = []
        
        for file in jsonFiles {
            do {
                let data = try Data(contentsOf: file)
                let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)
                
                // Validate plan
                let validationErrors = validatePlan(plan)
                if validationErrors.isEmpty {
                    plans.append(plan)
                } else {
                    print("⚠️ Invalid plan '\(plan.name)' from \(file.lastPathComponent): \(validationErrors.joined(separator: ", "))")
                }
            } catch {
                print("❌ Failed to load plan from \(file.lastPathComponent): \(error)")
            }
        }
        
        return plans
    }
    
    // MARK: - Plan Validation
    
    private func validatePlan(_ plan: WorkoutPlan) -> [String] {
        var errors: [String] = []
        
        // Validate basic requirements
        if plan.segments.isEmpty {
            errors.append("Plan has no segments")
        }
        
        // Validate each segment
        for segment in plan.segments {
            errors.append(contentsOf: segment.segment.validate())
        }
        
        return errors
    }
    
    // MARK: - Plan Access
    
    func getPlan(by id: String) -> WorkoutPlan? {
        return availablePlans.first { $0.id == id }
    }
    
    func getPlanNames() -> [String] {
        return availablePlans.map { $0.name }
    }
}

