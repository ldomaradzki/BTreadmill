//
//  RunListView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI

struct RunListView: View {
    @StateObject
    var viewModel: ContentViewModel
    
    @SectionedFetchRequest(sectionIdentifier: \.day, sortDescriptors: [NSSortDescriptor(keyPath: \Run.startTimestamp, ascending: false)], animation: .default)
    var groupedRuns: SectionedFetchResults<String, Run>

    var body: some View {
        List {
            ForEach(groupedRuns) { groupedRun in
                groupedSection(groupedRun)
            }
        }
    }
    
    private func groupedSection(_ groupedRun: SectionedFetchResults<String, Run>.Element) -> some View {
        Section(groupedRun.headerTitle) {
            ForEach(groupedRun) { run in
                NavigationLink {
                    RunContentView(run: run)
                        .toolbar {
                            Button(action: { viewModel.showAlert.toggle() }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .alert(isPresented: $viewModel.showAlert) {
                                Alert(title: Text("Remove this run?"), primaryButton: .destructive(Text("Yes"), action: { deleteRun(run: run) }), secondaryButton: .cancel())
                            }
                            
                            Button(action: { openWebActivity(run: run) }) {
                                Image(systemName: "globe")
                            }
                            .disabled(run.uploadedId == 0)
                            
                            Button(action: { Task { await shareButton(run: run) } }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                } label: {
                    RunCellView(run: run).frame(height: 44, alignment: .leading)
                }
            }
        }
    }
    
    @MainActor
    func shareButton(run: Run) async {
        if let id = await viewModel.shareOnStrava(run: run) {
            viewModel.updateUploadedId(run: run, id: id)
        }
    }
    
    func openWebActivity(run: Run) {
        let url = URL(string: "https://www.strava.com/activities/\(run.uploadedId)")!
        NSWorkspace.shared.open(url)
    }
    
    func deleteRun(run: Run) {
        viewModel.remove(run: run)
    }
    
}

extension SectionedFetchResults<String, Run>.Element {
    var headerTitle: String {
        "\(DateFormatter.mediumDateFormatter.string(from: first!.startTimestamp!)) (total \(totalDistance()) km)"
    }
    
    private func totalDistance() -> String {
        let distance = map { $0.distanceMeters }.reduce(0, +)
        let kmDistance = Measurement<UnitLength>(value: distance, unit: .meters).converted(to: .kilometers).value
        return String(format: "%.2f", kmDistance)
    }
}
