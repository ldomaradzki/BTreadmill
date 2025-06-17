import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var treadmillService: TreadmillServiceProtocol?
    private var workoutManager: WorkoutManager?
    private var settingsManager: SettingsManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupServices()
        setupStatusBar()
        
        // Hide dock icon since we're a menu bar app
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupServices() {
        settingsManager = SettingsManager.shared
        treadmillService = TreadmillService.shared
        workoutManager = WorkoutManager(treadmillService: treadmillService!)
    }
    
    private func setupStatusBar() {
        statusBarController = StatusBarController(
            treadmillService: treadmillService!,
            workoutManager: workoutManager!,
            settingsManager: settingsManager!
        )
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showMenu()
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Allow graceful shutdown - end any active workout
        workoutManager?.endCurrentWorkout()
        return .terminateNow
    }
}