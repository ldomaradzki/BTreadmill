//
//  BTreadmillApp.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 29/06/2023.
//

import SwiftUI
import GRDB
import GRDBQuery

@main
struct BTreadmillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .init(appDatabase: .shared))
                .environment(\.appDatabase, .shared)
        }
    }
}

private struct AppDatabaseKey: EnvironmentKey {
    static var defaultValue: AppDatabase { .shared }
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}

extension Query where Request.DatabaseContext == AppDatabase {
    init(_ request: Request) {
        self.init(request, in: \.appDatabase)
    }
}
