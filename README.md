# BTreadmill

A macOS menu bar application for Bluetooth treadmill control and workout tracking.

## Features

### 🏃‍♂️ Treadmill Control
- **Bluetooth Connection**: Automatic discovery and connection to RZ_TreadMill devices
- **Speed Control**: Precise speed adjustment from 1.0-6.0 km/h with 0.5 increments
- **Real-time Monitoring**: Live tracking of speed, distance, and step count

### 📊 Workout Tracking
- **Comprehensive Metrics**: Track time, distance, speed, steps, calories, pace, and cadence
- **Pause/Resume**: Full workout session control with accurate time tracking
- **Workout Plans**: Pre-defined workout routines with automatic speed transitions and progress tracking
- **History**: Complete workout history with lazy loading, monthly heatmap, and detailed session analytics
- **Real-time Charts**: Live speed visualization during workouts
- **Grace Period**: Smart metric calculation prevents incorrect values during workout startup

### 🎯 Smart Features
- **Menu Bar Integration**: Clean, always-accessible interface with live workout metrics display
- **Visual Feedback**: Real-time speed charts and highlighted primary metrics
- **Auto-reconnection**: Persistent Bluetooth connection with automatic recovery
- **Demo Mode**: Full functionality simulator for testing without physical hardware
- **Data Export**: JSON export, FIT file generation, and direct Strava upload

### 🏃‍♂️ Strava Integration
- **OAuth Authentication**: Secure connection to your Strava account
- **Automatic Upload**: Direct FIT file upload after workout completion
- **Activity Linking**: Seamless integration with your Strava activity feed
- **Standards Compliance**: Garmin FIT SDK ensures compatibility across platforms

## Screenshots

*Menu bar interface showing current workout metrics and controls*

## Requirements

- **macOS**: 13.0 or later
- **Bluetooth**: Compatible RZ_TreadMill device
- **Swift**: 5.9+ (for development)

## Installation

### From Releases
1. Download the latest `.dmg` file from [Releases](https://github.com/ldomaradzki/BTreadmill/releases)
2. Mount the disk image and drag BTreadmill to Applications
3. Launch BTreadmill from Applications or Spotlight

### Building from Source
```bash
# Clone the repository
git clone https://github.com/ldomaradzki/BTreadmill.git
cd BTreadmill

# Generate Xcode project
make generate

# Build the application
make build

# Run the application
make run
```

## Usage

### Basic Workout
1. **Connect**: BTreadmill automatically discovers and connects to your treadmill (or enable Demo Mode)
2. **Start**: Click "Start Workout" from the menu bar popover
3. **Control**: Use the speed slider to adjust treadmill speed (1-6 km/h)
4. **Monitor**: View real-time metrics with live speed charts and highlighted primary metrics
5. **Menu Bar**: See live workout time and distance in the menu bar during active sessions
6. **Finish**: Pause or end your workout when complete

### Workout Plans
1. Select a predefined workout plan from the dropdown
2. Click "Start Plan" to begin automated workout routine
3. The app automatically adjusts speed according to plan segments with progress tracking
4. Skip segments manually if needed during execution
5. View remaining time and current segment information

### Workout History
- Browse chronological workout history with lazy loading
- View monthly workout heatmap for activity patterns
- Export individual workouts or complete history
- Upload workouts directly to Strava

### Settings & Integrations
- Configure user profile (weight, stride length, preferred units)
- Enable/disable auto-connect and demo mode functionality
- Connect to Strava for automatic workout uploads
- Set default workout speed and preferences
- Access comprehensive workout history and export options

## Architecture

BTreadmill follows a clean service-layer architecture:

- **BluetoothService**: Handles CoreBluetooth communication with RZ_TreadMill devices
- **TreadmillService**: Interprets Bluetooth data into structured state
- **TreadmillSimulatorService**: Demo mode service for testing without physical hardware
- **WorkoutManager**: Manages workout sessions, metrics calculation, and plan execution
- **WorkoutPlanExecutor**: Handles automated workout plan execution with speed transitions
- **DataManager**: Handles data persistence, workout history, and export functionality
- **SettingsManager**: Manages user preferences and configuration
- **StravaService**: Handles OAuth authentication and workout upload integration
- **FITWorkoutEncoder**: Generates standards-compliant FIT files for data export

## Development

### Build System
The project uses XcodeGen for project file management:

```bash
# Available commands
make generate    # Generate Xcode project from project.yml
make build      # Build with formatted output
make clean      # Clean build artifacts
make run        # Build and launch
make stop       # Terminate running processes
make archive    # Create distribution archive
```

### Project Structure
```
BTreadmill/
├── App/                    # Application entry point
├── Core/
│   ├── Services/          # Business logic services
│   ├── Models/           # Data models
│   ├── Extensions/       # Swift extensions
│   └── Utilities/        # Helper utilities
├── Presentation/
│   ├── Views/           # SwiftUI views
│   └── Components/      # Reusable UI components
├── Resources/           # Assets and resources
├── project.yml         # XcodeGen configuration
└── Makefile           # Build automation
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **CoreBluetooth**: Bluetooth Low Energy communication
- **Combine**: Reactive programming for data flow
- **JSON**: Data persistence and export format
- **FIT SDK**: Garmin FIT file generation for cross-platform compatibility
- **OAuth2**: Secure Strava authentication and token management

## Compatibility

### Supported Treadmills
- RZ_TreadMill devices with Bluetooth Low Energy
- Custom protocol for speed control and data reading

### Data Formats
Workout sessions support multiple export formats:

**JSON Format** (for analysis and backup):
```json
{
  "id": "uuid",
  "startTime": "2023-...",
  "totalDistance": 2.5,
  "totalTime": 1800,
  "averageSpeed": 5.0,
  "averagePace": 720,
  "totalSteps": 3200,
  "estimatedCalories": 180,
  "speedHistory": [1.0, 2.5, 3.0, ...],
  "stravaActivityId": "12345678",
  "fitFilePath": "/path/to/workout.fit"
}
```

**FIT Format** (for Strava and fitness platforms):
- Standards-compliant Garmin FIT files
- Real-time generation during workouts
- Automatic upload to Strava
- Compatible with all major fitness platforms

## Privacy

BTreadmill stores all data locally on your device. Workout history and user preferences are saved in local JSON files. 

**Strava Integration**: When you choose to connect to Strava, workout data (FIT files) is transmitted directly to Strava's servers using their official API. This is entirely optional and controlled by you. Authentication tokens are stored securely in your system keychain.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have feature requests:
1. Check the [Issues](https://github.com/ldomaradzki/BTreadmill/issues) page
2. Create a new issue with detailed description
3. Include system information and steps to reproduce

---

**BTreadmill** - Making treadmill workouts smarter, one step at a time. 🏃‍♂️💨