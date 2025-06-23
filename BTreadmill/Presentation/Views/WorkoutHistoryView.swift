import SwiftUI

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

struct WorkoutHistoryView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var workoutToDelete: WorkoutSession?
    @State private var selectedMonth: Date = Date()
    @State private var isLoading: Bool = true
    @State private var loadedWorkouts: [WorkoutSession] = []
    @State private var loadedMonths: Set<Date> = []
    @State private var groupedWorkouts: [(Date, [WorkoutSession])] = []
    @State private var monthlyHeatmapData: [Date: Double] = [:]
    
    private let dataManager = DataManager.shared
    
    // Calendar with Monday as first weekday
    private var mondayFirstCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2, Sunday = 1
        return calendar
    }
    
    // Daily statistics
    private func dayStats(for workouts: [WorkoutSession]) -> (duration: TimeInterval, distance: Double, calories: Int) {
        let totalDuration = workouts.reduce(0) { $0 + $1.activeTime }
        let totalDistance = workouts.reduce(0.0) { result, workout in
            result + workout.totalDistance
        }
        let totalCalories = workouts.reduce(0) { $0 + $1.estimatedCalories }
        return (totalDuration, totalDistance, totalCalories)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if isLoading {
                loadingView
            } else if loadedWorkouts.isEmpty {
                emptyStateView
            } else {
                historyListView
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(.windowBackgroundColor))
        .task {
            await loadInitialData()
        }
        .onChange(of: selectedMonth) { newMonth in
            Task {
                await loadDataForMonth(newMonth)
            }
        }
        .onDisappear {
            // Revert to current month when leaving the view
            selectedMonth = Date()
        }
        .alert("Delete Workout", isPresented: .constant(workoutToDelete != nil)) {
            Button("Cancel", role: .cancel) {
                workoutToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    Task {
                        await deleteWorkout(workout)
                    }
                }
                workoutToDelete = nil
            }
        } message: {
            if let workout = workoutToDelete {
                Text("Are you sure you want to delete the workout from \(workout.actualStartDate, style: .date) at \(workout.actualStartDate, style: .time)? This action cannot be undone.")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Workout History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading workout history...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Async Loading Functions
    
    @MainActor
    private func loadInitialData() async {
        await loadDataForMonth(selectedMonth, includeAdjacentMonths: true)
        isLoading = false
    }
    
    @MainActor
    private func loadDataForMonth(_ month: Date, includeAdjacentMonths: Bool = false) async {
        let calendar = Calendar.current
        let monthToLoad = calendar.startOfMonth(for: month)
        
        // Determine which months to load
        var monthsToLoad: Set<Date> = [monthToLoad]
        
        if includeAdjacentMonths {
            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthToLoad) {
                monthsToLoad.insert(previousMonth)
            }
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthToLoad) {
                monthsToLoad.insert(nextMonth)
            }
        }
        
        // Filter out already loaded months
        let monthsToActuallyLoad = monthsToLoad.subtracting(loadedMonths)
        
        if !monthsToActuallyLoad.isEmpty {
            let newWorkouts = await Task.detached {
                return await dataManager.loadWorkoutsForMonths(monthsToActuallyLoad)
            }.value
            
            // Update loaded data
            loadedWorkouts.append(contentsOf: newWorkouts)
            loadedWorkouts.sort { $0.actualStartDate > $1.actualStartDate }
            loadedMonths.formUnion(monthsToActuallyLoad)
        }
        
        // Update computed data for the selected month
        updateComputedData()
    }
    
    @MainActor
    private func updateComputedData() {
        let calendar = Calendar.current
        let selectedMonthInterval = calendar.dateInterval(of: .month, for: selectedMonth)!
        
        // Filter workouts for selected month
        let filteredWorkouts = loadedWorkouts.filter { workout in
            selectedMonthInterval.contains(workout.actualStartDate)
        }
        
        // Update grouped workouts
        let grouped = Dictionary(grouping: filteredWorkouts) { workout in
            calendar.startOfDay(for: workout.actualStartDate)
        }
        groupedWorkouts = grouped.sorted { $0.key > $1.key }
        
        // Update heatmap data
        let heatmapGrouped = Dictionary(grouping: filteredWorkouts) { workout in
            calendar.startOfDay(for: workout.actualStartDate)
        }
        
        monthlyHeatmapData = heatmapGrouped.mapValues { workouts in
            workouts.reduce(0.0) { result, workout in
                result + workout.totalDistance
            }
        }
    }
    
    @MainActor
    private func deleteWorkout(_ workout: WorkoutSession) async {
        workoutManager.deleteWorkout(id: workout.id)
        
        // Remove from local cache
        loadedWorkouts.removeAll { $0.id == workout.id }
        
        // Update computed data
        updateComputedData()
    }
    
    @MainActor
    private func uploadToStrava(_ workout: WorkoutSession) async {
        // Check if Strava is authenticated
        if !StravaService.shared.isAuthenticated {
            let success = await StravaService.shared.authenticate()
            if !success {
                // Show authentication failed alert
                return
            }
        }
        
        // Upload the workout
        if let stravaActivityId = await StravaService.shared.uploadWorkout(workout: workout) {
            // Update the workout with Strava activity ID
            var updatedWorkout = workout
            updatedWorkout.markAsUploadedToStrava(activityId: stravaActivityId)
            
            // Save the updated workout
            workoutManager.updateWorkout(updatedWorkout)
            
            // Update local cache
            if let index = loadedWorkouts.firstIndex(where: { $0.id == workout.id }) {
                loadedWorkouts[index] = updatedWorkout
            }
            
            // Update computed data
            updateComputedData()
        }
    }
    
    @ViewBuilder
    private func monthlyHeatmapView(scrollTo: @escaping (String) -> Void) -> some View {
        let calendar = mondayFirstCalendar
        let monthName = DateFormatter().monthSymbols[calendar.component(.month, from: selectedMonth) - 1]
        let year = calendar.component(.year, from: selectedMonth)
        
        VStack(alignment: .leading, spacing: 8) {
            // Month navigation header
            HStack {
                Button(action: {
                    if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                        selectedMonth = previousMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                Spacer()
                
                Text("\(monthName) \(String(year))")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                        selectedMonth = nextMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 1), count: 7), spacing: 1) {
                // Week day headers (Monday first)
                let weekdaySymbols = Array(calendar.shortWeekdaySymbols[1...] + calendar.shortWeekdaySymbols[...0])
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 20)
                }
                
                // Month days
                ForEach(daysInCurrentMonth(), id: \.self) { date in
                    heatmapDay(date: date, scrollTo: scrollTo)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func heatmapDay(date: Date, scrollTo: @escaping (String) -> Void) -> some View {
        let distance = monthlyHeatmapData[date] ?? 0.0
        let intensity = min(distance / 10.0, 1.0)
        let isSelectedMonth = Calendar.current.isDate(date, equalTo: selectedMonth, toGranularity: .month)
        let hasData = distance > 0
        let dayId = "day-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
        
        Button(action: {
            if hasData {
                scrollTo(dayId)
            }
        }) {
            RoundedRectangle(cornerRadius: 3)
                .fill(heatmapColor(for: intensity))
                .frame(width: 40, height: 28)
                .opacity(isSelectedMonth ? 1.0 : 0.3)
                .overlay(
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(intensity > 0.5 ? .white : .primary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(hasData ? Color.primary.opacity(0.3) : Color.clear, lineWidth: hasData ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasData)
        .help(heatmapTooltip(for: date, distance: distance, clickable: hasData))
    }
    
    private func daysInCurrentMonth() -> [Date] {
        let calendar = mondayFirstCalendar
        let selectedMonthInterval = calendar.dateInterval(of: .month, for: selectedMonth)!
        let startOfMonth = selectedMonthInterval.start
        
        // Get first day of week for the month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysToSubtract = (firstWeekday - calendar.firstWeekday + 7) % 7
        let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth)!
        
        var dates: [Date] = []
        var currentDate = startDate
        
        // Generate 42 days (6 weeks) to fill the grid
        for _ in 0..<42 {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    private func heatmapColor(for intensity: Double) -> Color {
        if intensity == 0 {
            return Color(.controlBackgroundColor)
        }
        
        let baseColor = Color.green
        return baseColor.opacity(0.3 + (intensity * 0.7))
    }
    
    private func heatmapTooltip(for date: Date, distance: Double, clickable: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if distance > 0 {
            let baseText = "\(formatter.string(from: date)): \(String(format: "%.1f", distance)) km"
            return clickable ? "\(baseText) - Click to view details" : baseText
        } else {
            return "\(formatter.string(from: date)): No workout"
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image("treadmill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.secondary)
            
            Text("No Workout History")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Start your first workout to see your progress here!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var historyListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Monthly Heatmap at top of scroll view
                    monthlyHeatmapView { dayId in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(dayId, anchor: .top)
                        }
                    }
                    
                    ForEach(groupedWorkouts, id: \.0) { date, workouts in
                        daySection(date: date, workouts: workouts)
                            .id("day-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)")
                    }
                }
                .padding()
            }
        }
    }
    
    private func daySection(date: Date, workouts: [WorkoutSession]) -> some View {
        let stats = dayStats(for: workouts)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Day header with summary
            VStack(alignment: .leading, spacing: 4) {
                Text(date, style: .date)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("\(workouts.count) workout\(workouts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Label(formatTimeCompact(stats.duration), systemImage: "clock")
                        HStack(spacing: 4) {
                            Image("treadmill")
                                .resizable()
                                .frame(width: 12, height: 12)
                            Text(formatDistanceCompact(stats.distance))
                        }
                        Label("\(stats.calories) cal", systemImage: "flame")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            
            // Individual workouts
            ForEach(workouts.sorted { $0.actualStartDate > $1.actualStartDate }) { workout in
                workoutHistoryRow(workout)
            }
        }
    }
    
    private func workoutHistoryRow(_ workout: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(workout.actualStartDate, style: .time)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if workout.isDemo {
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
                    
                    if let endDate = workout.actualEndDate {
                        Text("to \(endDate, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Strava upload button (only show if workout has a FIT file)
                    if workout.fitFilePath != nil {
                        if workout.isUploadedToStrava {
                            Button(action: {
                                if let url = workout.stravaActivityURL {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Image(systemName: "globe")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            .help("View on Strava")
                        } else {
                            Button(action: {
                                Task {
                                    await uploadToStrava(workout)
                                }
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            .help("Upload to Strava")
                            .disabled(StravaService.shared.isUploading)
                        }
                    }
                    
                    // Delete button
                    Button(action: {
                        workoutToDelete = workout
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Delete workout")
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                statView(title: "Time", value: formatTimeCompact(workout.activeTime))
                statView(title: "Distance", value: formatDistance(workout.totalDistance))
                statView(title: "Steps", value: "\(workout.totalSteps)")
                statView(title: "Avg Speed", value: formatSpeed(workout.averageSpeed))
                statView(title: "Max Speed", value: formatSpeed(workout.maxSpeed))
                statView(title: "Pace", value: formatPace(workout.averagePace))
            }
            
            // Speed Chart
            SpeedChartView(
                speedData: workout.speedHistory,
                height: 50,
                showTitle: false
            )
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Show session duration if different from active time (i.e., there were pauses)
            if workout.actualSessionDuration > workout.activeTime + 60 { // 1 minute threshold
                HStack {
                    Text("Session: \(formatTimeCompact(workout.actualSessionDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Paused: \(formatTimeCompact(workout.pausedDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func statView(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
    
    private func formatTimeCompact(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        return String(format: "%.2f km", distance)
    }
    
    private func formatDistanceCompact(_ distance: Double) -> String {
        return String(format: "%.1fkm", distance)
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.1f km/h", speed)
    }
    
    private func formatPace(_ pace: TimeInterval) -> String {
        if pace <= 0 { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    WorkoutHistoryView(
        workoutManager: WorkoutManager(),
        settingsManager: SettingsManager.shared
    )
}
