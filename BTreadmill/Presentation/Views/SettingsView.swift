import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        TabView {
            // General Settings
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // User Profile
            UserProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
            
            // Display Settings
            DisplaySettingsView()
                .tabItem {
                    Label("Display", systemImage: "display")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Application Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Application")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Launch at login", isOn: $settingsManager.launchAtLogin)
                        Toggle("Enable notifications", isOn: $settingsManager.enableNotifications)
                    }
                }
                
                Divider()
                
                // Treadmill Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Treadmill")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Auto-connect to known devices", isOn: $settingsManager.userProfile.autoConnectEnabled)
                        
                        HStack {
                            Text("Default speed:")
                                .frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            TextField("Speed", value: $settingsManager.userProfile.defaultSpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("km/h")
                                .frame(width: 40, alignment: .leading)
                        }
                        
                        HStack {
                            Text("Maximum speed:")
                                .frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            TextField("Max Speed", value: $settingsManager.userProfile.maxSpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("km/h")
                                .frame(width: 40, alignment: .leading)
                        }
                    }
                }
                
                Divider()
                
                // Actions Section
                HStack(spacing: 12) {
                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Export Settings") {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "BTreadmill Settings.json"
        panel.allowedContentTypes = [.json]
        
        panel.begin { result in
            if result == .OK, let url = panel.url,
               let data = settingsManager.exportSettings() {
                try? data.write(to: url)
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        panel.begin { result in
            if result == .OK, let url = panel.url,
               let data = try? Data(contentsOf: url) {
                _ = settingsManager.importSettings(from: data)
            }
        }
    }
}

struct UserProfileView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Personal Information Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Information")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Weight:")
                                .frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            TextField("Weight", value: $settingsManager.userProfile.weight.value, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text(settingsManager.userProfile.weight.unit.symbol)
                                .frame(width: 40, alignment: .leading)
                        }
                        
                        HStack {
                            Text("Stride length:")
                                .frame(minWidth: 120, alignment: .leading)
                            Spacer()
                            TextField("Stride", value: $settingsManager.userProfile.strideLength.value, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text(settingsManager.userProfile.strideLength.unit.symbol)
                                .frame(width: 40, alignment: .leading)
                        }
                    }
                }
                
                Divider()
                
                // Units Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Units")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    HStack {
                        Text("Unit system:")
                            .frame(minWidth: 120, alignment: .leading)
                        Spacer()
                        Picker("Unit system", selection: $settingsManager.userProfile.preferredUnits) {
                            ForEach(UnitSystem.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 150, maxWidth: 200)
                    }
                }
                
                Divider()
                
                // Help Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("Weight is used for calorie estimation. Stride length is used for step counting when not provided by the treadmill.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DisplaySettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Menu Bar Display Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Menu Bar Display")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show current speed", isOn: $settingsManager.showSpeedInMenuBar)
                        Toggle("Show distance", isOn: $settingsManager.showDistanceInMenuBar)
                    }
                }
                
                Divider()
                
                // Help Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("Choose what information to display in the menu bar during workouts. Only one option can be active at a time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: settingsManager.showSpeedInMenuBar) { newValue in
            if newValue {
                settingsManager.showDistanceInMenuBar = false
            }
        }
        .onChange(of: settingsManager.showDistanceInMenuBar) { newValue in
            if newValue {
                settingsManager.showSpeedInMenuBar = false
            }
        }
    }
}

#Preview {
    SettingsView()
}