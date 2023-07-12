//
//  AppDatabase.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 09/07/2023.
//

import Foundation
import GRDB
import OSLog

class AppDatabase {
    static let shared: AppDatabase = .init()
    
    let dbWriter: any DatabaseWriter
    private let logger = Logger(subsystem: "SQLite", category: "database")
    
    private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
            logger.info("Database stored at \(databaseURL.path)")

            dbWriter = try DatabasePool(path: databaseURL.path, configuration: Configuration())
            
            try migrator.migrate(dbWriter)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func updateRunData(_ runData: RunData) async {
        logger.info("Updating run data to database")
        do {
            try await dbWriter.write { [runData] db in
                try runData.save(db)
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    
    func removeRunData(_ runData: RunData) async {
        guard let id = runData.id else { return }
        logger.info("Removing new run data to database")
        do {
            _ = try await dbWriter.write { db in
                try RunData.deleteAll(db, ids: [id])
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
            
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        RunData.prepareSchema(&migrator)
        
        return migrator
    }
}
