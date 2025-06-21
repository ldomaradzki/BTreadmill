import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    weak var statusBarController: StatusBarController?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
    }
    
    private func setupWindow() {
        window?.delegate = self
    }
    
    deinit {
        // Ensure cleanup
        window?.delegate = nil
    }
}

// MARK: - NSWindowDelegate
extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clean up
        statusBarController = nil
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}