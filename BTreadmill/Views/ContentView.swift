//
//  ContentView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 29/06/2023.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject
    var viewModel: ContentViewModel
    
    @State private var date = Date()

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Run.startTimestamp, ascending: false)], animation: .default)
    private var runs: FetchedResults<Run>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                if viewModel.bluetoothState && viewModel.treadmillState != .unknown {
                    HStack {
                        if viewModel.treadmillState == .hibernated {
                            Text("Hibernated treadmill, wake it up!")
                                .fontWeight(.heavy)
                        } else {
                            if viewModel.treadmillState == .idling {
                                IdlingControlView(viewModel: viewModel)
                            } else {
                                RunningControlView(viewModel: viewModel)
                            }
                        }
                    }
                } else {
                    Text("Connecting...")
                }
                RunListView(runs: runs.map { $0 }, viewModel: viewModel)
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
            }
            .toolbar {
                ToolbarItemGroup {
                    Spacer()
                    if viewModel.bluetoothState {
                        Text("🟢")
                    } else {
                        Text("🔴")
                    }

                }
            }
        }
    }
    
}


//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//    }
//}
