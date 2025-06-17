import SwiftUI

@main
struct BTreadmillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 600, height: 400)
        }
    }
}