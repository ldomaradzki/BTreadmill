//
//  RunListView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI

struct RunListView: View {
    let runs: [Run]
    @StateObject
    var viewModel: ContentViewModel
    
    private var groupedRuns: [GroupedRuns] {
        Dictionary(grouping: runs, by: { Calendar.current.startOfDay(for: $0.startTimestamp!) })
            .map { GroupedRuns(id: $0.key.timeIntervalSince1970, date: $0.key, runs: $0.value) }
            .sorted { run1, run2 in
                run1.date.compare(run2.date) == .orderedDescending
            }
    }
    
    var body: some View {
        List {
            ForEach(groupedRuns) { groupedRun in
                groupedSection(groupedRun)
            }
        }
    }
    
    private func groupedSection(_ groupedRun: GroupedRuns) -> some View {
        Section(groupedRun.title) {
            ForEach(groupedRun.runs) { run in
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
