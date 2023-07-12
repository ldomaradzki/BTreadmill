//
//  AppDelegate.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 12/07/2023.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
