import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var userProfile: UserProfile {
        didSet {
            saveUserProfile()
        }
    }
    
    @Published var showSpeedInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showSpeedInMenuBar, forKey: "showSpeedInMenuBar")
        }
    }
    
    @Published var showDistanceInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showDistanceInMenuBar, forKey: "showDistanceInMenuBar")
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            // TODO: Implement launch at login functionality
        }
    }
    
    @Published var enableNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        }
    }
    
    private init() {
        // Load user profile
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile()
        }
        
        // Load other settings
        self.showSpeedInMenuBar = UserDefaults.standard.bool(forKey: "showSpeedInMenuBar")
        self.showDistanceInMenuBar = UserDefaults.standard.bool(forKey: "showDistanceInMenuBar")
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
    }
    
    private func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
    
    // MARK: - Convenience Methods
    
    func resetToDefaults() {
        userProfile = UserProfile()
        showSpeedInMenuBar = false
        showDistanceInMenuBar = false
        launchAtLogin = false
        enableNotifications = true
    }
    
    func exportSettings() -> Data? {
        let settings = [
            "userProfile": userProfile,
            "showSpeedInMenuBar": showSpeedInMenuBar,
            "showDistanceInMenuBar": showDistanceInMenuBar,
            "launchAtLogin": launchAtLogin,
            "enableNotifications": enableNotifications
        ] as [String : Any]
        
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    func importSettings(from data: Data) -> Bool {
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        // Import user profile if available
        if let profileData = settings["userProfile"] as? Data,
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            userProfile = profile
        }
        
        // Import other settings
        if let value = settings["showSpeedInMenuBar"] as? Bool {
            showSpeedInMenuBar = value
        }
        
        if let value = settings["showDistanceInMenuBar"] as? Bool {
            showDistanceInMenuBar = value
        }
        
        if let value = settings["launchAtLogin"] as? Bool {
            launchAtLogin = value
        }
        
        if let value = settings["enableNotifications"] as? Bool {
            enableNotifications = value
        }
        
        return true
    }
}