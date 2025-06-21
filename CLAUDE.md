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
- **DataManager**: Persists workout sessions using JSON storage, provides workout history queries
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
**Frameworks**: CoreBluetooth, SwiftUI
**Build System**: XcodeGen with Manual code signing (development)
**External Tools**: xcbeautify for formatted build output

The project uses no external package dependencies - all functionality is implemented with system frameworks.

## Data Models

### Core Treadmill Models
```swift
enum TreadmillState {
    case unknown
    case hibernated
    case idling
    case starting
    case running(RunningState)
    case stopping(RunningState)
}

struct RunningState {
    let timestamp: Date
    let speed: Measurement<UnitSpeed>
    let distance: Measurement<UnitLength>
    let steps: Int
}

enum TreadmillCommand {
    case start
    case speed(Double)  // 1.0-6.0 km/h
    case stop
}
```

### Workout and User Models
```swift
struct WorkoutSession {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let totalDistance: Measurement<UnitLength>
    let totalTime: TimeInterval
    let averageSpeed: Measurement<UnitSpeed>
    let maxSpeed: Measurement<UnitSpeed>
    let totalSteps: Int
    let estimatedCalories: Int
    let isPaused: Bool
    let pausedDuration: TimeInterval
}

struct UserProfile {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var preferredUnits: UnitSystem
    var autoConnectEnabled: Bool
}

enum UnitSystem {
    case metric
    case imperial
}
```

## Feature Implementation Status

### Core Features (Completed)
- ✅ Bluetooth treadmill connection and control
- ✅ Real-time workout tracking with pause/resume
- ✅ JSON-based workout history persistence
- ✅ User settings and preferences management
- ✅ Menu bar interface with popover controls
- ✅ Workout history view with session details

### Data Persistence
- **Storage Format**: JSON files for workout sessions and user settings
- **DataManager**: Handles all file I/O operations and data queries
- **Workout Recovery**: Automatic recovery of interrupted workout sessions
- **Export Capability**: JSON export of workout data

### User Interface Components
- **Status Bar**: Shows connection status and optional workout metrics
- **Main Menu Popover**: Primary control interface with treadmill controls and current workout display
- **Settings Window**: Separate window for user profile and app configuration
- **Workout History**: Chronological list of completed workouts with detailed metrics