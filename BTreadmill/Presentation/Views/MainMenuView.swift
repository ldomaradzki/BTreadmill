import SwiftUI
import AppKit
import Combine

struct MainMenuView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var settingsManager: SettingsManager
    
    private var treadmillService: TreadmillServiceProtocol {
        return TreadmillService.shared
    }
    
    @State private var isConnected: Bool = false
    @State private var treadmillState: TreadmillState = .unknown
    @State private var currentSpeed: Double = 1.0
    @State private var showingWorkoutHistory = false
    @State private var showingSettings = false
    
    // Computed property to determine if treadmill controls should be enabled
    private var isTreadmillReady: Bool {
        // In simulator mode, always consider ready when simulator is enabled
        if settingsManager.userProfile.simulatorMode {
            return true
        }
        // Otherwise use actual connection status and ensure not hibernated
        return isConnected && treadmillState != .hibernated
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with connection status and action buttons
                headerView
                
                Divider()
                
                // Treadmill Controls (always visible)
                treadmillControlsView
                
                Divider()
                
                // Current Workout Display
                currentWorkoutView
                
                Spacer(minLength: 8)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: 500, alignment: .top)
        .onReceive(treadmillService.isConnectedPublisher) { connected in
            isConnected = connected
        }
        .onReceive(treadmillService.statePublisher) { state in
            treadmillState = state
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            WorkoutHistoryView(
                workoutManager: workoutManager,
                settingsManager: settingsManager
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettingsSheet"))) { _ in
            showingSettings = true
        }
    }
    
    private var headerView: some View {
        HStack {
            // Connection status dot
            Circle()
                .fill(isTreadmillReady ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Image("treadmill")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            
            Text("BTreadmill")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: { showingWorkoutHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Workout History")
                
                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    
    private var treadmillControlsView: some View {
        VStack(spacing: 6) {
            Text("Treadmill Control")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Speed Control with predefined values and fine adjustment
            VStack(spacing: 6) {
                HStack {
                    Text("Speed")
                    Spacer()
                    Text("\(currentSpeed, specifier: "%.1f") km/h")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                // Predefined speed buttons
                HStack(spacing: 6) {
                    ForEach(1...6, id: \.self) { speed in
                        Button("\(speed)") {
                            currentSpeed = Double(speed)
                            if isTreadmillReady && workoutManager.isWorkoutActive {
                                workoutManager.setTreadmillSpeed(currentSpeed)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(currentSpeed == Double(speed) ? .white : .primary)
                        .background(currentSpeed == Double(speed) ? Color.blue : Color.clear)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                }
                
                // Fine adjustment buttons
                HStack(spacing: 12) {
                    Button("-0.1") {
                        let newSpeed = max(1.0, currentSpeed - 0.1)
                        currentSpeed = newSpeed
                        if isTreadmillReady && workoutManager.isWorkoutActive {
                            workoutManager.setTreadmillSpeed(newSpeed)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentSpeed <= 1.0)
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("+0.1") {
                        let newSpeed = min(6.0, currentSpeed + 0.1)
                        currentSpeed = newSpeed
                        if isTreadmillReady && workoutManager.isWorkoutActive {
                            workoutManager.setTreadmillSpeed(newSpeed)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentSpeed >= 6.0)
                    .font(.caption)
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
                        .disabled(!isTreadmillReady)
                    } else {
                        Button("Pause") {
                            workoutManager.pauseWorkout()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isTreadmillReady)
                    }
                    
                    Button("End Workout") {
                        workoutManager.endCurrentWorkout()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Start Workout") {
                        workoutManager.startWorkout()
                        currentSpeed = settingsManager.userProfile.defaultSpeed
                        workoutManager.setTreadmillSpeed(currentSpeed)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isTreadmillReady)
                }
            }
            
            if settingsManager.userProfile.simulatorMode {
                Text("Simulator mode enabled")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 2)
            } else if !isConnected {
                Text("Connect treadmill to start workout")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            } else if treadmillState == .hibernated {
                VStack(spacing: 2) {
                    Text("Treadmill is in hibernation mode")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Please restart the treadmill to use it")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onAppear {
            currentSpeed = settingsManager.userProfile.defaultSpeed
        }
    }
    
    private var currentWorkoutView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Current Workout")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let workout = workoutManager.currentWorkout, workout.isDemo {
                    Text("DEMO")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
            }
            
            if let workout = workoutManager.currentWorkout {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    workoutStatView(title: "Time", value: formatTime(workout.activeTime))
                    workoutStatView(title: "Distance", value: formatDistance(workout.totalDistance))
                    workoutStatView(title: "Avg Speed", value: formatSpeed(workout.averageSpeed))
                    workoutStatView(title: "Max Speed", value: formatSpeed(workout.maxSpeed))
                    workoutStatView(title: "Pace", value: formatPace(workout.averagePace))
                    workoutStatView(title: "Steps", value: "\(workout.totalSteps)")
                }
                
                // Speed Chart
                SpeedChartView(
                    speedData: workout.speedHistory,
                    height: 60,
                    showTitle: false
                )
                .padding(.top, 8)
                
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
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func formatDistance(_ distance: Measurement<UnitLength>) -> String {
        let converted = distance.converted(to: .kilometers)
        return String(format: "%.2f km", converted.value)
    }
    
    private func formatSpeed(_ speed: Measurement<UnitSpeed>) -> String {
        let converted = speed.converted(to: .kilometersPerHour)
        return String(format: "%.1f km/h", converted.value)
    }
    
    private func formatPace(_ pace: TimeInterval) -> String {
        if pace <= 0 { return "--:--/km" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d/km", minutes, seconds)
    }
    
    private func openSettings() {
        showingSettings = true
    }
}