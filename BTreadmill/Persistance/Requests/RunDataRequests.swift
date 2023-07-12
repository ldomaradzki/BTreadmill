//
//  RunDataRequests.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 10/07/2023.
//

import Foundation
import GRDB
import GRDBQuery
import Combine

/// Request for list screen to receive all RunData objects grouped by day
struct GroupedRunDataRequest: Queryable {
    typealias GroupedRunData = [(String, [RunData])]
    
    static var defaultValue: GroupedRunData { [] }
    
    func publisher(in appDatabase: AppDatabase) -> AnyPublisher<GroupedRunData, Error> {
        ValueObservation
            .tracking(fetchValue(_:))
            .publisher(
                in: appDatabase.dbWriter,
                scheduling: .immediate)
            .map {
                Dictionary(grouping: $0,
                           by: { Calendar.current.startOfDay(for: $0.startTimestamp).description })
                .map { ($0.key, $0.value.sorted(by: { $0.startTimestamp > $1.startTimestamp })) }
                    .sorted { $0.0 > $1.0}
            }
            .eraseToAnyPublisher()
    }

    func fetchValue(_ db: Database) throws -> [RunData] {
        try RunData.all().fetchAll(db)
    }
}

/// Request for detailed screen to receive changes on single RunData object
struct SingleRunDataRequest: Queryable {
    let id: Int64
    
    static var defaultValue: RunData { .init(startTimestamp: .now) }
    
    func publisher(in appDatabase: AppDatabase) -> AnyPublisher<RunData, Error> {
        ValueObservation
            .tracking(fetchValue(_:))
            .publisher(
                in: appDatabase.dbWriter,
                scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func fetchValue(_ db: Database) throws -> RunData {
        try RunData.find(db, id: id)
    }
}
