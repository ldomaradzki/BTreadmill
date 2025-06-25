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
        workoutManager = WorkoutManager()
        treadmillService = TreadmillService.shared
    }
    
    private func setupStatusBar() {
        statusBarController = StatusBarController(
            workoutManager: workoutManager!,
            settingsManager: settingsManager!
        )
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Only show menu if there are no visible windows and user explicitly reopened
        if !flag {
            statusBarController?.showMenu()
        }
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Allow graceful shutdown - end any active workout
        workoutManager?.endCurrentWorkout()
        return .terminateNow
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure menu bar functionality remains intact
        // This can be called after OAuth authentication to restore menu bar
        if statusBarController == nil {
            setupStatusBar()
        }
    }
}