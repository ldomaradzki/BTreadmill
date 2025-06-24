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
        .frame(width: 350)
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
            // Connection status with icon
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 10, height: 10)
                
                Image("treadmill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.primary)
                
                Text("BTreadmill")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let statusText = connectionStatusText {
                    Text("• \(statusText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons - match header size
            HStack(spacing: 8) {
                Button(action: { showingWorkoutHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Workout History")
                
                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Quit BTreadmill")
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var connectionStatusColor: Color {
        if settingsManager.userProfile.simulatorMode { return .blue }
        if !isConnected { return .red }
        return treadmillState == .hibernated ? .orange : .green
    }
    
    private var connectionStatusText: String? {
        if settingsManager.userProfile.simulatorMode { return nil }
        
        switch (isConnected, treadmillState) {
        case (false, _): return "Connecting..."
        case (true, .hibernated): return "Hibernated"
        case (true, .running(_)): return "Running"
        default: return nil
        }
    }
    
    
    private var treadmillControlsView: some View {
        // Grouped controls with visual container
        VStack(spacing: 12) {
            // Speed Control - Only show during workout
            if workoutManager.isWorkoutActive {
                VStack(spacing: 8) {
                    // Speed slider with 0.5 increments
                    Slider(value: $currentSpeed, in: 1.0...6.0, step: 0.5) { changed in
                        if !changed && isTreadmillReady && workoutManager.isWorkoutActive {
                            workoutManager.setTreadmillSpeed(currentSpeed)
                        }
                    }
                    .disabled(!workoutManager.isWorkoutActive)
                    
                    // Speed labels
                    HStack(spacing: 0) {
                        Text("1 km/h")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        HStack(spacing: 36) {
                            Text("2")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .center)
                            
                            Text("3")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .center)
                            
                            Text("4")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .center)
                            
                            Text("5")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Text("6 km/h")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .offset(y: -6)
                }
            }
            
            // Workout Plan Selection (only show when not active)
            if !workoutManager.isWorkoutActive {
                VStack(spacing: 6) {
                    HStack {
                        if planManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Picker("Workout Plan", selection: $selectedPlan) {
                        Text("---").tag(nil as WorkoutPlan?)
                        ForEach(planManager.availablePlans) { plan in
                            if let duration = plan.estimatedDuration {
                                Text("\(plan.name) (\(formatTime(duration)))").tag(plan as WorkoutPlan?)
                            } else {
                                Text(plan.name).tag(plan as WorkoutPlan?)
                            }
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
            
            // Workout Control Buttons
            if workoutManager.isWorkoutActive {
                // Pause/Resume and End buttons - full width
                HStack(spacing: 8) {
                    Button {
                        if workoutManager.currentWorkout?.isPaused == true {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: workoutManager.currentWorkout?.isPaused == true ? "play.fill" : "pause.fill")
                            Text(workoutManager.currentWorkout?.isPaused == true ? "Resume" : "Pause")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isTreadmillReady)
                    
                    Button {
                        workoutManager.endCurrentWorkout()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("End")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                // Start workout button
                Button {
                    if let plan = selectedPlan {
                        startWorkoutWithPlan(plan)
                    } else {
                        workoutManager.startWorkout()
                        currentSpeed = settingsManager.userProfile.defaultSpeed
                        workoutManager.setTreadmillSpeed(currentSpeed)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedPlan != nil ? "list.bullet" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(selectedPlan != nil ? "Start Plan" : "Start Workout")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        selectedPlan != nil ? Color.blue : Color.green
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!isTreadmillReady)
                .opacity(isTreadmillReady ? 1.0 : 0.6)
            }
            
            // Status message (only show important ones)
            if !isConnected && !settingsManager.userProfile.simulatorMode {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("Connect treadmill to start workout")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            } else if treadmillState == .hibernated {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                        .font(.caption2)
                    Text("Treadmill hibernated - restart to use")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
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
                VStack(spacing: 8) {
                    // First row - highlighted primary metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        workoutStatView(title: "Speed", value: formatSpeed(workout.currentSpeed), isHighlighted: true)
                        workoutStatView(title: "Time", value: formatTime(workout.activeTime), isHighlighted: true)
                        workoutStatView(title: "Distance", value: formatDistance(workout.totalDistance), isHighlighted: true)
                    }
                    
                    // Second row - performance metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        workoutStatView(title: "Avg Speed", value: workout.isInGracePeriod ? "--.- km/h" : formatSpeed(workout.averageSpeed))
                        workoutStatView(title: "Max Speed", value: formatSpeed(workout.maxSpeed))
                        workoutStatView(title: "Calories", value: workout.isInGracePeriod ? "--" : "\(workout.estimatedCalories)")
                    }
                    
                    // Third row - additional metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        workoutStatView(title: "Pace", value: workout.isInGracePeriod ? "--:--/km" : formatPace(workout.averagePace))
                        workoutStatView(title: "Steps", value: "\(workout.totalSteps)")
                        workoutStatView(title: "Cadence", value: formatCadence(workout.cadence))
                    }
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
    
    
    private func workoutStatView(title: String, value: String, isHighlighted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(isHighlighted ? .title2 : .title3)
                .fontWeight(isHighlighted ? .bold : .semibold)
                .foregroundColor(isHighlighted ? .primary : .primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHighlighted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(title.isEmpty ? 0 : 1) // Hide empty cells
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
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
    
    private func formatCadence(_ cadence: Double) -> String {
        if cadence <= 0 { return "-- spm" }
        return String(format: "%.0f spm", cadence)
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
