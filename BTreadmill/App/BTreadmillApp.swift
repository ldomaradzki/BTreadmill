import SwiftUI

@main
struct BTreadmillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    var body: some Scene {
        // Use Settings to create an empty scene that doesn't show by default
        Settings {
            EmptyView()
        }
        .windowResizability(.contentSize)
    }
}