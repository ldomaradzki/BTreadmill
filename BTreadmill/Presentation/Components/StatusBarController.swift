import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var bag = Set<AnyCancellable>()
    
    private let workoutManager: WorkoutManager
    private let settingsManager: SettingsManager
    
    private var treadmillService: TreadmillServiceProtocol {
        return TreadmillService.shared
    }
    
    init(workoutManager: WorkoutManager, settingsManager: SettingsManager) {
        self.workoutManager = workoutManager
        self.settingsManager = settingsManager
        
        super.init()
        
        setupStatusItem()
        setupPopover()
        setupSubscriptions()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        // Try multiple icon options in order of preference
        if let image = NSImage(named: "StatusBarIcon") {
            // Custom icon from assets - resize for menu bar
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.image?.isTemplate = true
        } else if let image = NSImage(named: "treadmill") {
            // Treadmill vector image fallback
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.image?.isTemplate = true
        } else if let image = NSImage(named: NSImage.userAccountsName) {
            // System icon fallback
            button.image = image
            button.image?.isTemplate = true
        } else {
            // Text fallback
            button.title = "T"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
        
        // Set up button action
        button.action = #selector(togglePopover)
        button.target = self
        
        // Add right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BTreadmill", action: #selector(quit), keyEquivalent: "q"))
        
        // Configure right-click behavior
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 200) // Initial minimal size
        popover?.behavior = .transient
        
        let hostingController = NSHostingController(
            rootView: MainMenuView(
                workoutManager: workoutManager,
                settingsManager: settingsManager
            )
        )
        
        // Allow the popover to resize based on content
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        popover?.contentViewController = hostingController
    }
    
    private func setupSubscriptions() {
        // Update status bar based on connection state
        treadmillService.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateStatusBarIcon(isConnected: isConnected)
            }
            .store(in: &bag)
        
        // Update status bar text based on workout state
        Publishers.CombineLatest(
            workoutManager.currentWorkoutPublisher,
            treadmillService.statePublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] workout, treadmillState in
            self?.updateStatusBarText(workout: workout, treadmillState: treadmillState)
        }
        .store(in: &bag)
        
        // Listen for settings window requests from main menu
        NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.openSettings()
            }
            .store(in: &bag)
    }
    
    private func updateStatusBarIcon(isConnected: Bool) {
        guard let button = statusItem?.button else { return }
        
        // Always show the walk icon
        if let image = NSImage(named: "StatusBarIcon") {
            // Custom icon - resize for menu bar
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.image?.isTemplate = true
            button.alphaValue = 1.0
        } else if let image = NSImage(named: "treadmill") {
            // Treadmill vector image fallback
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.image?.isTemplate = true
            button.alphaValue = 1.0
        } else {
            // Text fallback - show walk symbol
            button.image = nil
            button.title = "🚶"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
        
        // Update tooltip
        button.toolTip = isConnected ? "BTreadmill - Connected" : "BTreadmill - Disconnected"
    }
    
    private func updateStatusBarText(workout: WorkoutSession?, treadmillState: TreadmillState) {
        guard let button = statusItem?.button else { return }
        
        var text = ""
        
        if let workout = workout, workout.isActive && !workout.isPaused {
            // Show timer and distance in format: "1h23m•6.7km"
            let timeText = formatWorkoutTime(workout.activeTime)
            let distance = workout.totalDistance.converted(to: .kilometers)
            let distanceText = String(format: "%.1fkm", distance.value)
            text = " \(timeText)•\(distanceText)"
        }
        
        // Always show icon with optional text
        if button.image != nil {
            button.title = text
        } else {
            // Fallback if no icon available
            button.title = text.isEmpty ? "🚶" : "🚶\(text)"
        }
    }
    
    private func formatWorkoutTime(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else {
            return "\(minutes)m"
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BTreadmill", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func openSettings() {
        // Post notification to MainMenuView to show settings sheet
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsSheet"), object: nil)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func showMenu() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

