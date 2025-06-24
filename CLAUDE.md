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
- **TreadmillSimulatorService**: Demo mode service for testing without physical treadmill
- **WorkoutManager**: Tracks workout sessions, calculates metrics (steps, calories), manages pause/resume, handles workout plan execution
- **WorkoutPlanExecutor**: Executes predefined workout plans with automatic speed transitions
- **WorkoutPlanManager**: Manages available workout plans and plan loading
- **DataManager**: Persists workout sessions using JSON storage, provides workout history queries
- **SettingsManager**: Manages user preferences and configuration persistence
- **StravaService**: Handles Strava OAuth authentication and workout upload integration
- **FITWorkoutEncoder**: Generates FIT files for workout data export and Strava uploads

### Menu Bar Integration Pattern
The app follows a menu bar-first design:
- **StatusBarController**: Manages NSStatusItem, popover presentation, and context menus with real-time workout metrics display
- **MainMenuView**: Primary SwiftUI interface displayed in popover with comprehensive workout controls
- **SettingsView**: Separate window for configuration managed by SettingsWindowController
- **WorkoutHistoryView**: Dedicated view for browsing workout history with lazy loading and monthly heatmap

### Data Flow
1. BluetoothService (or TreadmillSimulatorService in demo mode) publishes raw treadmill data via Combine publishers
2. TreadmillService transforms data into structured TreadmillState
3. WorkoutManager consumes state changes to track workout metrics and manages plan execution
4. FITWorkoutEncoder generates real-time FIT file data during workouts
5. StatusBarController subscribes to all services to update menu bar appearance with live metrics
6. StravaService handles post-workout upload of FIT files to Strava platform

## Key Implementation Details

**Threading**: BluetoothService uses dedicated queues with thread-safe property access patterns
**State Management**: Uses CurrentValueSubject publishers for reactive state updates
**Menu Bar Behavior**: LSUIElement=YES prevents dock icon, supports both left/right click interactions with live workout metrics
**Connection Strategy**: Auto-discovers RZ_TreadMill devices, maintains persistent connection with reconnection logic
**Demo Mode**: TreadmillSimulatorService provides full functionality without physical hardware for testing
**Grace Period**: Calculated metrics (averages, pace, calories) wait for 5 data points to prevent startup anomalies
**Real-time FIT Generation**: FIT files are generated during workout execution, not post-processing
**OAuth Integration**: Secure Strava authentication with automatic token refresh handling

## Project Structure

- `BTreadmill/App/`: Application entry point and AppDelegate
- `BTreadmill/Core/`: Business logic (Services, Models, Extensions, Utilities)
- `BTreadmill/Presentation/`: UI components (Views, Components)
- `BTreadmill/Resources/`: Assets and resources
- `project.yml`: XcodeGen configuration for project generation
- `Makefile`: Build automation with xcodebuild integration

## Dependencies and Requirements

**Platform**: macOS 13.0+, Swift 5.9
**Frameworks**: CoreBluetooth, SwiftUI, Combine
**Build System**: XcodeGen with Manual code signing (development)
**External Tools**: xcbeautify for formatted build output
**Package Dependencies**: 
- FITSwiftSDK (Garmin FIT file generation)
- OAuth2 (Strava integration authentication)

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
    var endTime: Date?
    var totalDistance: Double // kilometers
    var totalTime: TimeInterval
    var averageSpeed: Double // km/h
    var maxSpeed: Double // km/h
    var averagePace: TimeInterval // minutes per kilometer
    var totalSteps: Int
    var estimatedCalories: Int
    var isPaused: Bool
    var pausedDuration: TimeInterval
    var isDemo: Bool
    var speedHistory: [Double] // for chart visualization
    var stravaActivityId: String?
    var fitFilePath: String?
    var isInGracePeriod: Bool // calculated metrics grace period
    var cadence: Double // steps per minute
}

struct UserProfile {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var preferredUnits: UnitSystem
    var autoConnectEnabled: Bool
    var simulatorMode: Bool
    var defaultSpeed: Double
    var stravaConnected: Bool
}

struct WorkoutPlan {
    let id: UUID
    let name: String
    let segments: [WorkoutSegment]
    var estimatedDuration: TimeInterval?
}

struct WorkoutSegment {
    let duration: TimeInterval
    let speed: Double
    let type: SegmentType
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
- ✅ Menu bar interface with popover controls and live metrics
- ✅ Workout history view with lazy loading and monthly heatmap
- ✅ Workout plan system with automatic speed transitions
- ✅ Demo/simulator mode for testing without hardware
- ✅ FIT file generation and export
- ✅ Strava integration with OAuth authentication
- ✅ Real-time speed charts and visual feedback
- ✅ Grace period for calculated metrics to prevent startup anomalies

### Data Persistence & Export
- **Storage Format**: JSON files for workout sessions and user settings
- **DataManager**: Handles all file I/O operations and data queries with thread safety
- **Workout Recovery**: Automatic recovery of interrupted workout sessions
- **Export Capabilities**: JSON export of workout data, FIT file generation, direct Strava upload
- **FIT File Support**: Real-time generation during workouts with proper activity tracking

### Third-Party Integrations
- **Strava OAuth**: Secure authentication with automatic token refresh
- **FIT File Upload**: Direct upload to Strava with activity linking
- **Garmin FIT SDK**: Standards-compliant FIT file generation for cross-platform compatibility

### User Interface Components
- **Status Bar**: Shows connection status and live workout metrics (time, distance) when active
- **Main Menu Popover**: Comprehensive workout interface with controls, metrics, and plan selection
- **Settings Window**: User profile, Strava connection, simulator mode, and preferences
- **Workout History**: Lazy-loaded chronological list with monthly heatmap and detailed session analytics
- **Speed Charts**: Real-time visualization of workout speed patterns
- **Plan Execution UI**: Progress tracking, segment display, and manual skip controls