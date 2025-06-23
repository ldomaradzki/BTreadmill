# BTreadmill

A macOS menu bar application for Bluetooth treadmill control and workout tracking.

## Features

### 🏃‍♂️ Treadmill Control
- **Bluetooth Connection**: Automatic discovery and connection to RZ_TreadMill devices
- **Speed Control**: Precise speed adjustment from 1.0-6.0 km/h with 0.5 increments
- **Real-time Monitoring**: Live tracking of speed, distance, and step count

### 📊 Workout Tracking
- **Comprehensive Metrics**: Track time, distance, speed, steps, calories, and cadence
- **Pause/Resume**: Full workout session control with accurate time tracking
- **Workout Plans**: Pre-defined workout routines with automatic speed transitions
- **History**: Complete workout history with detailed session analytics

### 🎯 Smart Features
- **Menu Bar Integration**: Clean, always-accessible interface from the menu bar
- **Visual Feedback**: Real-time speed charts and highlighted primary metrics
- **Auto-reconnection**: Persistent Bluetooth connection with automatic recovery
- **Data Export**: JSON export of workout sessions and history

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
1. **Connect**: BTreadmill automatically discovers and connects to your treadmill
2. **Start**: Click "Start Workout" from the menu bar popover
3. **Control**: Use the speed slider to adjust treadmill speed (1-6 km/h)
4. **Monitor**: View real-time metrics including time, distance, speed, and calories
5. **Finish**: Pause or end your workout when complete

### Workout Plans
1. Select a predefined workout plan from the dropdown
2. Click "Start Plan" to begin automated workout routine
3. The app automatically adjusts speed according to plan segments
4. Skip segments manually if needed during execution

### Settings
- Configure user profile (weight, stride length, preferred units)
- Enable/disable auto-connect functionality
- Access workout history and export data

## Architecture

BTreadmill follows a clean service-layer architecture:

- **BluetoothService**: Handles CoreBluetooth communication
- **TreadmillService**: Interprets Bluetooth data into structured state
- **WorkoutManager**: Manages workout sessions and metrics calculation
- **DataManager**: Handles data persistence and workout history
- **SettingsManager**: Manages user preferences and configuration

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

## Compatibility

### Supported Treadmills
- RZ_TreadMill devices with Bluetooth Low Energy
- Custom protocol for speed control and data reading

### Data Format
Workout sessions are stored in JSON format for easy export and analysis:

```json
{
  "id": "uuid",
  "startTime": "2023-...",
  "totalDistance": 2.5,
  "totalTime": 1800,
  "averageSpeed": 5.0,
  "totalSteps": 3200,
  "estimatedCalories": 180
}
```

## Privacy

BTreadmill stores all data locally on your device. No data is transmitted to external servers. Workout history and user preferences are saved in local JSON files.

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