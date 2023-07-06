//
//  BTreadmillApp.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 29/06/2023.
//

import SwiftUI

@main
struct BTreadmillApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .init())
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
