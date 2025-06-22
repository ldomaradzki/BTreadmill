import SwiftUI
import AppKit
import Combine

struct MainMenuView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var planManager = WorkoutPlanManager()
    
    private var treadmillService: TreadmillServiceProtocol {
        return TreadmillService.shared
    }
    
    @State private var isConnected: Bool = false
    @State private var treadmillState: TreadmillState = .unknown
    @State private var currentSpeed: Double = 1.0
    @State private var showingWorkoutHistory = false
    @State private var showingSettings = false
    @State private var selectedPlan: WorkoutPlan? = nil
    
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
        VStack(spacing: 0) {
            // Header with connection status and action buttons
            headerView
            
            Divider()
            
            // Treadmill Controls (always visible)
            treadmillControlsView
            
            // Current Workout Display (only show when workout is active)
            if workoutManager.currentWorkout != nil {
                Divider()
                currentWorkoutView
            }
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
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
            
            // Workout Plan Selection (only show when not active)
            if !workoutManager.isWorkoutActive {
                VStack(spacing: 6) {
                    HStack {
                        Text("Workout Plan")
                        Spacer()
                        if planManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .font(.caption)
                    
                    Picker("Workout Plan", selection: $selectedPlan) {
                        Text("---").tag(nil as WorkoutPlan?)
                        ForEach(planManager.availablePlans) { plan in
                            Text(plan.name).tag(plan as WorkoutPlan?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let plan = selectedPlan {
                        HStack {
                            if let duration = plan.estimatedDuration {
                                Text("Duration: \(formatTime(duration))")
                            }
                            Spacer()
                            Text("Segments: \(plan.segments.count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                    Button(selectedPlan != nil ? "Start Plan" : "Start Workout") {
                        if let plan = selectedPlan {
                            startWorkoutWithPlan(plan)
                        } else {
                            workoutManager.startWorkout()
                            currentSpeed = settingsManager.userProfile.defaultSpeed
                            workoutManager.setTreadmillSpeed(currentSpeed)
                        }
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
                
                if workoutManager.currentExecutingPlan != nil {
                    Text("PLAN")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }
            
            // Plan execution info
            if let planExecutor = workoutManager.planExecutor,
               let plan = workoutManager.currentExecutingPlan,
               planExecutor.isExecuting {
                VStack(spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        if planExecutor.isPaused {
                            Text("PAUSED")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !planExecutor.currentSegmentDisplayText.isEmpty {
                        HStack {
                            Text(planExecutor.currentSegmentDisplayText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(planExecutor.progressDisplayText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !planExecutor.remainingTimeDisplayText.isEmpty {
                        HStack {
                            Spacer()
                            Text(planExecutor.remainingTimeDisplayText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Skip segment button for plan workouts
                    if !planExecutor.isPaused {
                        HStack {
                            Spacer()
                            Button("Skip Segment") {
                                workoutManager.skipCurrentSegment()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .font(.caption2)
                        }
                    }
                }
                .padding(.top, 4)
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
    
    private func formatDistance(_ distance: Double) -> String {
        return String(format: "%.2f km", distance)
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.1f km/h", speed)
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
    
    private func startWorkoutWithPlan(_ plan: WorkoutPlan) {
        workoutManager.startWorkoutWithPlan(plan)
        print("🎯 Starting workout with plan: \(plan.name)")
        print("📋 Plan has \(plan.segments.count) segments")
        if let duration = plan.estimatedDuration {
            print("⏱️ Estimated duration: \(formatTime(duration))")
        }
    }
}