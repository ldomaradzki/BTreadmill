import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportFileDialog = false
    @State private var showingImportFileDialog = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                // Application Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Application")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Simulator mode", isOn: $settingsManager.userProfile.simulatorMode)
                                .toggleStyle(.switch)
                        }
                        
                        Text("Enable demo mode to simulate treadmill data without physical hardware.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider()
                
                // Treadmill Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Treadmill")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
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
                    }
                }
                
                Divider()
                
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
                        Picker("", selection: $settingsManager.userProfile.preferredUnits) {
                            ForEach(UnitSystem.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 150, maxWidth: 200)
                    }
                }
                
                Divider()
                
                // Data Management Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Management")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        let dataInfo = settingsManager.getDataFileInfo()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data file: \(dataInfo.exists ? "Found" : "Not found")")
                                    .font(.caption)
                                    .foregroundColor(dataInfo.exists ? .primary : .secondary)
                                
                                if let size = dataInfo.size {
                                    Text("Size: \(size)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Button("Export") {
                                        showingExportFileDialog = true
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!dataInfo.exists)
                                    
                                    Button("Import") {
                                        showingImportFileDialog = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        
                        Text("Export saves all your settings and workout history to a JSON file. Import replaces current data with imported file.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                
                Divider()
                
                // Stride Length Calculation Guide
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Calculate Your Stride Length")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Start a 1-minute workout at 4.0 km/h (comfortable walking pace)")
                            .font(.caption)
                        Text("2. Note the number of steps shown after 1 minute")
                            .font(.caption)
                        Text("3. Calculate: Distance = 4.0 km/h ÷ 60 min = 66.7 meters per minute")
                            .font(.caption)
                        Text("4. Stride length = 66.7 meters ÷ number of steps")
                            .font(.caption)
                        Text("5. Example: 66.7m ÷ 80 steps = 0.83m stride length")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(.windowBackgroundColor))
        .fileExporter(
            isPresented: $showingExportFileDialog,
            document: BTreadmillDataDocument(),
            contentType: .json,
            defaultFilename: "btreadmill_data.json"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportFileDialog,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Data Management", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Settings")
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
    
    // MARK: - Import/Export Handlers
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try settingsManager.exportData(to: url)
                alertMessage = "Data successfully exported to: \(url.lastPathComponent)"
                showingAlert = true
            } catch {
                alertMessage = "Export failed: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Export cancelled: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                alertMessage = "No file selected for import."
                showingAlert = true
                return
            }
            
            do {
                try settingsManager.importData(from: url)
                alertMessage = "Data successfully imported from: \(url.lastPathComponent)\n\nLoaded \(settingsManager.workoutHistory.count) workouts."
                showingAlert = true
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Import cancelled: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Document Wrapper for Export

import UniformTypeIdentifiers

struct BTreadmillDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: Data
    
    init() {
        // Get current app data for export
        let appData = AppData(
            userProfile: SettingsManager.shared.userProfile,
            workoutHistory: SettingsManager.shared.workoutHistory
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            self.data = try encoder.encode(appData)
        } catch {
            // Fallback to empty JSON if encoding fails
            self.data = "{}".data(using: .utf8) ?? Data()
        }
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
}