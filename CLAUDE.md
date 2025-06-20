# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Project Generation**: `make generate` or `xcodegen generate` - Generate Xcode project from project.yml
**Build**: `make build` - Build the application using xcodebuild with xcbeautify formatting
**Clean**: `make clean` - Clean build artifacts
**Run**: `make run` - Build and launch the application
**Stop**: `make stop` - Terminate running BTreadmill processes
**Archive**: `make archive` - Create distribution archive

All commands use xcbeautify for formatted output. The project uses XcodeGen for project file management - always run `make generate` after modifying project.yml.

## Architecture Overview

BTreadmill is a macOS menu bar application for Bluetooth treadmill control with the following key components:

### Service Layer Architecture
- **BluetoothService**: Handles CoreBluetooth communication with RZ_TreadMill devices, provides connection state and data publishers
- **TreadmillService**: Interprets Bluetooth data into TreadmillState, executes TreadmillCommand operations
- **WorkoutManager**: Tracks workout sessions, calculates metrics (steps, calories), manages pause/resume
- **SettingsManager**: Manages user preferences and configuration persistence

### Menu Bar Integration Pattern
The app follows a menu bar-first design:
- **StatusBarController**: Manages NSStatusItem, popover presentation, and context menus
- **MainMenuView**: Primary SwiftUI interface displayed in popover
- **SettingsView**: Separate window for configuration managed by SettingsWindowController

### Data Flow
1. BluetoothService publishes raw treadmill data via Combine publishers
2. TreadmillService transforms data into structured TreadmillState
3. WorkoutManager consumes state changes to track workout metrics
4. StatusBarController subscribes to all services to update menu bar appearance

## Key Implementation Details

**Threading**: BluetoothService uses dedicated queues with thread-safe property access patterns
**State Management**: Uses CurrentValueSubject publishers for reactive state updates
**Menu Bar Behavior**: LSUIElement=YES prevents dock icon, supports both left/right click interactions
**Connection Strategy**: Auto-discovers RZ_TreadMill devices, maintains persistent connection with reconnection logic

## Project Structure

- `BTreadmill/App/`: Application entry point and AppDelegate
- `BTreadmill/Core/`: Business logic (Services, Models, Extensions, Utilities)
- `BTreadmill/Presentation/`: UI components (Views, Components)
- `BTreadmill/Resources/`: Assets and resources
- `project.yml`: XcodeGen configuration for project generation
- `Makefile`: Build automation with xcodebuild integration

## Dependencies and Requirements

**Platform**: macOS 13.0+, Swift 5.9
**Frameworks**: CoreBluetooth, CoreData, SwiftUI
**Build System**: XcodeGen with Manual code signing (development)
**External Tools**: xcbeautify for formatted build output

The project uses no external package dependencies - all functionality is implemented with system frameworks.