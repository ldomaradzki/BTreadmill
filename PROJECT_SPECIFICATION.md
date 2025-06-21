# BTreadmill - macOS Menu Bar Treadmill Control Application

## Project Overview

BTreadmill is a macOS menu bar application designed to provide seamless Bluetooth control of an RZ_TreadMill, real-time workout tracking, and comprehensive workout history management. The application leverages proven architectures from existing projects while delivering a focused, menu bar-optimized user experience.

## Technical Foundation

### Reference Architectures
- **WBTreadmill**: Provides the core Bluetooth treadmill communication protocols, state management, and command structures
- **VibeMeter**: Provides the menu bar application architecture, service patterns, and UI component organization

### Core Technologies
- **Swift/SwiftUI**: Primary development language and UI framework
- **Core Bluetooth**: Bluetooth Low Energy communication with treadmill
- **JSON Storage**: Local workout data persistence with DataManager
- **XcodeGen**: Project generation and configuration management

## Architecture Overview

### Service Layer
```
BluetoothService
├── Handles RZ_TreadMill connection/disconnection
├── Manages BLE characteristic discovery and communication
└── Publishes connection state and data streams

TreadmillService
├── Interprets raw Bluetooth data into TreadmillState
├── Executes TreadmillCommand operations
└── Manages treadmill state transitions

WorkoutManager
├── Tracks workout sessions and metrics
├── Calculates derived data (steps, calories, pace)
└── Manages workout pause/resume functionality

DataManager
├── Persists workout sessions using JSON storage
├── Provides workout history queries
└── Handles data import/export functionality

SettingsManager
├── Manages user preferences and configuration
├── Handles user profile data (weight, stride length)
└── Controls app behavior settings
```

### Data Models

#### Core Models
```swift
// Treadmill State Management
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

#### Workout Tracking Models
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

### UI Architecture

#### Menu Bar Integration
- **Status Bar Icon**: Shows connection status and current workout state
- **Status Bar Text**: Optional display of current speed or distance (configurable)
- **Menu Popover**: Primary interaction interface with full controls

#### Menu Popover Components
```
Popover Layout
├── Connection Status Header
├── Treadmill Control Panel
│   ├── Start/Stop Button
│   ├── Speed Control Slider (1.0-6.0 km/h)
│   └── Emergency Stop
├── Current Workout Display
│   ├── Elapsed Time
│   ├── Current Speed
│   ├── Distance Traveled
│   ├── Step Count
│   └── Estimated Calories
├── Workout Controls
│   ├── Pause/Resume Button
│   └── End Workout Button
└── Navigation
    ├── Workout History
    ├── Settings
    └── About
```

## Feature Specifications

### Bluetooth Treadmill Control
- **Auto Connect**: Automatically connects to known RZ_TreadMill devices
- **Connection Management**: Handles disconnections and reconnection attempts
- **Command Execution**: Start, stop, and speed control (1.0-6.0 km/h range)
- **State Monitoring**: Real-time treadmill state and data parsing
- **Error Handling**: Bluetooth failures, command errors, disconnection recovery

### Workout Tracking
- **Real-time Metrics**: Speed, distance, time, estimated steps
- **Pause/Resume**: Maintains workout continuity across pause periods
- **Calculated Metrics**: Steps (based on user stride length), calories (based on user weight)
- **Session Management**: Start/stop workout sessions independent of treadmill state

### Data Persistence
- **Local Storage**: JSON-based workout history with DataManager service
- **Session Recovery**: Restore interrupted workouts on app restart
- **Data Export**: Export workout data to JSON formats
- **Data Integrity**: Versioned data format with migration support

### User Settings
- **User Profile**: Weight, stride length, preferred units
- **App Behavior**: Auto-connect, startup behavior, notification preferences
- **Display Options**: Menu bar text, metric units, decimal precision
- **Treadmill Settings**: Speed increments, safety limits, default speeds

### Historical Data & Statistics
- **Workout History**: Chronological list of completed workouts
- **Statistics View**: Weekly/monthly summaries and trends
- **Progress Tracking**: Distance goals, workout frequency, speed improvements
- **Data Visualization**: Simple charts showing progress over time

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [x] Project setup with XcodeGen
- [x] Basic app structure and menu bar integration
- [x] Core service architecture implementation
- [x] Bluetooth service porting from WBTreadmill

### Phase 2: Treadmill Integration (Week 1-2)
- [x] TreadmillService implementation
- [x] Command system and state management
- [x] Real-time data parsing and display
- [x] Connection management and error handling
- [x] TreadmillSimulatorService for testing

### Phase 3: Workout Tracking (Week 2)
- [x] WorkoutManager implementation
- [x] Basic workout session tracking
- [x] Pause/resume functionality
- [x] Metric calculations (steps, calories)

### Phase 4: UI Development (Week 2-3)
- [x] Menu bar popover interface
- [x] Treadmill control components
- [x] Workout display components
- [x] Settings interface
- [x] Workout history interface

### Phase 5: Data Persistence (Week 3)
- [x] JSON-based data model setup
- [x] Workout history storage
- [x] Data export functionality
- [x] Settings persistence
- [x] Data persistence bug fixes

### Phase 6: Polish & Testing (Week 3-4)
- [ ] Error handling and edge cases
- [ ] UI polish and animations
- [ ] Comprehensive testing
- [ ] Documentation and user guides

## Technical Considerations

### macOS-Specific Adaptations
- **No HealthKit**: Custom workout tracking without system health integration
- **Menu Bar Constraints**: Compact UI design optimized for menu bar interaction
- **Local Storage**: All data stored locally without cloud synchronization
- **Bluetooth Permissions**: Proper entitlements and user permission handling

### Performance Considerations
- **Background Processing**: Minimal CPU usage when running in background
- **Memory Management**: Efficient data structures for large workout histories
- **Battery Impact**: Optimized Bluetooth communication patterns
- **Responsiveness**: Smooth UI updates during active workouts

### Security & Privacy
- **Local Data Only**: No external data transmission or cloud storage
- **User Consent**: Clear communication about Bluetooth usage
- **Data Encryption**: Secure local storage of workout data
- **Minimal Permissions**: Only required system permissions requested

## Success Criteria

### Core Functionality
- [x] Reliable Bluetooth connection to RZ_TreadMill
- [x] Accurate real-time workout tracking
- [x] Persistent workout history storage
- [x] Intuitive menu bar interface

### User Experience
- [ ] Sub-second connection time to known devices
- [ ] Responsive UI during active workouts
- [ ] Clear visual feedback for all operations
- [ ] Helpful error messages and recovery guidance

### Reliability
- [ ] Handles Bluetooth disconnections gracefully
- [ ] Recovers from app crashes during workouts
- [ ] Maintains data integrity across sessions
- [ ] Performs well over extended usage periods

## Development Notes

### Commit Strategy
Each major feature implementation will be committed separately with descriptive commit messages following the pattern:
- `feat: implement [feature description]`
- `fix: resolve [issue description]`
- `refactor: improve [component description]`
- `docs: update [documentation description]`

### Testing Approach
- Unit tests for core business logic (WorkoutManager, TreadmillService)
- Integration tests for Bluetooth communication
- UI tests for critical user workflows
- Manual testing on actual hardware

### Future Enhancements
- Multiple treadmill brand support
- Workout programs and intervals
- Social features and workout sharing
- Integration with fitness tracking services
- Advanced analytics and goal setting

---

This specification serves as the definitive reference for the BTreadmill project, ensuring consistent implementation and clear communication of requirements throughout development.