import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var bag = Set<AnyCancellable>()
    var settingsWindow: NSWindow?
    
    private let treadmillService: TreadmillServiceProtocol
    private let workoutManager: WorkoutManager
    private let settingsManager: SettingsManager
    
    init(treadmillService: TreadmillServiceProtocol, workoutManager: WorkoutManager, settingsManager: SettingsManager) {
        self.treadmillService = treadmillService
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
            // Custom icon from assets
            button.image = image
            button.image?.isTemplate = true
        } else if let image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "BTreadmill") {
            // SF Symbol
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
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MainMenuView(
                treadmillService: treadmillService,
                workoutManager: workoutManager,
                settingsManager: settingsManager
            )
        )
    }
    
    private func setupSubscriptions() {
        // Update status bar based on connection state
        treadmillService.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateStatusBarIcon(isConnected: isConnected)
            }
            .store(in: &bag)
        
        // Update status bar text based on workout state and settings
        Publishers.CombineLatest3(
            workoutManager.currentWorkoutPublisher,
            treadmillService.statePublisher,
            settingsManager.$showSpeedInMenuBar
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] workout, treadmillState, showSpeed in
            self?.updateStatusBarText(workout: workout, treadmillState: treadmillState, showSpeed: showSpeed)
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
        
        // Try multiple icon options in order of preference
        let iconName = isConnected ? "figure.walk" : "figure.walk.slash"
        if let image = NSImage(named: "StatusBarIcon") {
            // Custom icon - change opacity to indicate connection
            button.image = image
            button.image?.isTemplate = true
            button.alphaValue = isConnected ? 1.0 : 0.5
            button.title = "" // Clear title when using image
        } else if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BTreadmill") {
            // SF Symbol
            button.image = image
            button.image?.isTemplate = true
            button.alphaValue = 1.0
            button.title = "" // Clear title when using image
        } else {
            // Text fallback with connection indicator
            button.image = nil
            button.alphaValue = 1.0
            button.title = isConnected ? "T●" : "T○"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        }
        
        // Update tooltip
        button.toolTip = isConnected ? "BTreadmill - Connected" : "BTreadmill - Disconnected"
    }
    
    private func updateStatusBarText(workout: WorkoutSession?, treadmillState: TreadmillState, showSpeed: Bool) {
        guard let button = statusItem?.button else { return }
        
        var text = ""
        
        if let workout = workout, workout.isActive {
            if showSpeed {
                if case .running(let runningState) = treadmillState {
                    let speed = runningState.speed.converted(to: settingsManager.userProfile.preferredUnits.speedUnit)
                    text = String(format: "%.1f", speed.value)
                } else {
                    text = "0.0"
                }
            } else if settingsManager.showDistanceInMenuBar {
                let distance = workout.totalDistance.converted(to: settingsManager.userProfile.preferredUnits.distanceUnit)
                text = String(format: "%.2f", distance.value)
            }
        }
        
        // Only update title if we have text to show AND we're not using an icon
        if !text.isEmpty && button.image == nil {
            button.title = text
        } else if text.isEmpty {
            // Clear title when no data to show (preserves icon if present)
            if button.image != nil {
                button.title = ""
            }
        } else if !text.isEmpty && button.image != nil {
            // Show both icon and text when we have data
            button.title = " " + text // Space before text for better visual separation
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
        // If settings window already exists, just bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new settings window using a different approach
        DispatchQueue.main.async { [weak self] in
            self?.createSettingsWindow()
        }
    }
    
    private func createSettingsWindow() {
        // Create the settings view with explicit dependencies
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "BTreadmill Settings"
        window.center()
        
        // Use a custom window controller to manage lifecycle
        let windowController = SettingsWindowController(window: window)
        windowController.statusBarController = self
        
        // Retain the window
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func showMenu() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

