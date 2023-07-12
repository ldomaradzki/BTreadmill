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
                RunListView(viewModel: viewModel)
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
