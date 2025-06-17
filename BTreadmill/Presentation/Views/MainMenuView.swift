import SwiftUI
import Combine

struct MainMenuView: View {
    let treadmillService: TreadmillServiceProtocol
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var settingsManager: SettingsManager
    
    @State private var isConnected: Bool = false
    @State private var treadmillState: TreadmillState = .unknown
    @State private var currentSpeed: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Connection Status
            connectionStatusView
            
            Divider()
            
            // Treadmill Controls
            if isConnected {
                treadmillControlsView
                
                Divider()
                
                // Current Workout Display
                currentWorkoutView
                
                Divider()
            }
            
            // Navigation
            navigationView
        }
        .frame(width: 300, height: isConnected ? 450 : 200)
        .onReceive(treadmillService.isConnectedPublisher) { connected in
            isConnected = connected
        }
        .onReceive(treadmillService.statePublisher) { state in
            treadmillState = state
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("BTreadmill")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(isConnected ? "Connected to RZ_TreadMill" : "Searching for treadmill...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var treadmillControlsView: some View {
        VStack(spacing: 12) {
            Text("Treadmill Control")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Speed Control
            VStack(spacing: 8) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text("\(currentSpeed, specifier: "%.1f") km/h")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                Slider(value: $currentSpeed, in: 1.0...6.0, step: 0.1) { editing in
                    if !editing {
                        workoutManager.setTreadmillSpeed(currentSpeed)
                    }
                }
            }
            
            // Start/Stop Buttons
            HStack(spacing: 12) {
                if workoutManager.isWorkoutActive {
                    if workoutManager.currentWorkout?.isPaused == true {
                        Button("Resume") {
                            workoutManager.resumeWorkout()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Pause") {
                            workoutManager.pauseWorkout()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("End Workout") {
                        workoutManager.endCurrentWorkout()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Start Workout") {
                        workoutManager.startWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    private var currentWorkoutView: some View {
        VStack(spacing: 8) {
            Text("Current Workout")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let workout = workoutManager.currentWorkout {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    workoutStatView(title: "Time", value: formatTime(workout.activeTime))
                    workoutStatView(title: "Distance", value: formatDistance(workout.totalDistance))
                    workoutStatView(title: "Steps", value: "\(workout.totalSteps)")
                    workoutStatView(title: "Calories", value: "\(workout.estimatedCalories)")
                }
                
                if workout.isPaused {
                    Text("Workout Paused")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            } else {
                Text("No active workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var navigationView: some View {
        VStack(spacing: 8) {
            Button("Workout History") {
                // TODO: Show workout history
            }
            .buttonStyle(.bordered)
            
            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func workoutStatView(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ distance: Measurement<UnitLength>) -> String {
        let converted = distance.converted(to: settingsManager.userProfile.preferredUnits.distanceUnit)
        return String(format: "%.2f %@", converted.value, converted.unit.symbol)
    }
}