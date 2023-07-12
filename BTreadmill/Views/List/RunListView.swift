//
//  RunListView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI
import GRDBQuery

struct RunListView: View {
    @Environment(\.appDatabase) private var appDatabase
    
    @StateObject
    var viewModel: ContentViewModel
    
    @Query(GroupedRunDataRequest())
    private var groupedRunData: [(String, [RunData])]

    var body: some View {
        List {
            ForEach(groupedRunData, id: \.0) { groupedRun in
                groupedSection(groupedRun)
            }
        }
    }
    
    private func groupedSection(_ groupedRun: (String, [RunData])) -> some View {
        Section(groupedRun.1.headerTitle) {
            ForEach(groupedRun.1, id: \.startTimestamp) { runData in
                NavigationLink {
                    RunContentView(id: runData.id!, viewModel: viewModel)
                        .toolbar {
                            Button(action: {
                                viewModel.showAlert.toggle()
                            }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                            .alert(isPresented: $viewModel.showAlert) {
                                Alert(title: Text("Remove this run?"),
                                      primaryButton: .destructive(Text("Yes"),
                                      action: {
                                        Task {
                                            await deleteRun(runData: runData)
                                        }
                                      }),
                                      secondaryButton: .cancel())
                            }
                            
                            Button(action: {
                                openWebActivity(runData: runData)
                            }) { Image(systemName: "globe") }
                            .disabled(runData.uploadedId == nil)
                            
                            Button(action: {
                                Task {
                                    await shareButton(runData: runData)
                                }
                            }) { Image(systemName: "square.and.arrow.up") }
                        }
                } label: {
                    RunCellView(runData: runData).frame(height: 44, alignment: .leading)
                }
            }
        }
    }
    
    @MainActor
    func shareButton(runData: RunData) async {
        if let id = await viewModel.shareOnStrava(runData: runData) {
            await viewModel.updateUploadedId(runData: runData, id: id)
        }
    }
    
    func openWebActivity(runData: RunData) {
        guard let uploadedId = runData.uploadedId else { return }
        let url = URL(string: "https://www.strava.com/activities/\(uploadedId)")!
        NSWorkspace.shared.open(url)
    }
    
    @MainActor
    func deleteRun(runData: RunData) async {
        await viewModel.remove(runData: runData)
    }
    
}

extension [RunData] {
    var headerTitle: String {
        "\(DateFormatter.mediumDateFormatter.string(from: first!.startTimestamp)) (total \(totalDistance()) km)"
    }

    private func totalDistance() -> String {
        let distance = map { $0.distance.converted(to: .meters).value }.reduce(0, +)
        let kmDistance = Measurement<UnitLength>(value: distance, unit: .meters).converted(to: .kilometers).value
        return String(format: "%.2f", kmDistance)
    }
}
