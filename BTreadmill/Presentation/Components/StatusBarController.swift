import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var bag = Set<AnyCancellable>()
    
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
        
        // Set initial icon
        button.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "BTreadmill")
        button.image?.isTemplate = true
        
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
    }
    
    private func updateStatusBarIcon(isConnected: Bool) {
        guard let button = statusItem?.button else { return }
        
        let iconName = isConnected ? "figure.walk" : "figure.walk.slash"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "BTreadmill")
        button.image?.isTemplate = true
        
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
        
        button.title = text
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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