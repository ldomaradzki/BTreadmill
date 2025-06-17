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
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section("Application") {
                Toggle("Launch at login", isOn: $settingsManager.launchAtLogin)
                Toggle("Enable notifications", isOn: $settingsManager.enableNotifications)
            }
            
            Section("Treadmill") {
                Toggle("Auto-connect to known devices", isOn: $settingsManager.userProfile.autoConnectEnabled)
                
                HStack {
                    Text("Default speed:")
                    Spacer()
                    TextField("Speed", value: $settingsManager.userProfile.defaultSpeed, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("km/h")
                }
                
                HStack {
                    Text("Maximum speed:")
                    Spacer()
                    TextField("Max Speed", value: $settingsManager.userProfile.maxSpeed, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("km/h")
                }
            }
            
            Section {
                HStack {
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
            }
        }
        .padding()
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
        Form {
            Section("Personal Information") {
                HStack {
                    Text("Weight:")
                    Spacer()
                    TextField("Weight", value: $settingsManager.userProfile.weight.value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(settingsManager.userProfile.weight.unit.symbol)
                }
                
                HStack {
                    Text("Stride length:")
                    Spacer()
                    TextField("Stride", value: $settingsManager.userProfile.strideLength.value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(settingsManager.userProfile.strideLength.unit.symbol)
                }
            }
            
            Section("Units") {
                Picker("Unit system:", selection: $settingsManager.userProfile.preferredUnits) {
                    ForEach(UnitSystem.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section {
                Text("Weight is used for calorie estimation. Stride length is used for step counting when not provided by the treadmill.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct DisplaySettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section("Menu Bar Display") {
                Toggle("Show current speed", isOn: $settingsManager.showSpeedInMenuBar)
                Toggle("Show distance", isOn: $settingsManager.showDistanceInMenuBar)
            }
            
            Section {
                Text("Choose what information to display in the menu bar during workouts. Only one option can be active at a time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
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