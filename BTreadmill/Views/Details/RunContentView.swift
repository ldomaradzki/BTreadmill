//
//  RunContentView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI
import Charts
import GRDBQuery

struct RunContentView: View {
    @Environment(\.appDatabase) private var appDatabase
    
    @Query<SingleRunDataRequest>
    var runData: RunData
    
    private var speedsArray: [(Int, Double)] { runData.speedsArray.enumerated().map { ($0.offset, $0.element) } }

    init(id: Int64) {
        _runData = Query(SingleRunDataRequest(id: id), in: \.appDatabase)
    }
    
    var body: some View {
        VStack {
            Text("Speed").padding(.top, 10)
            Chart {
                AreaMark(x: .value("", 0), y: .value("", 0))
                ForEach(speedsArray, id: \.0) { speed in
                    AreaMark(x: .value("", speed.0 + 1),
                             y: .value("", speed.1))
                }
            }
            .chartXAxis(.hidden)
            .padding(.horizontal, 20).frame(height: 100)
            
            
            List {
                HStack {
                    Text("Avg Speed").bold()
                    Spacer()
                    Text("\(runData.speedsArray.reduce(0.0, +)/Double(runData.speedsArray.count), specifier: "%.1f") km/h")
                }.padding(.horizontal, 10)
                Divider()
                HStack {
                    Text("Max Speed").bold()
                    Spacer()
                    Text("\(runData.speedsArray.max() ?? 0.0, specifier: "%.1f") km/h")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Distance").bold()
                    Spacer()
                    Text("\(runData.distanceMeters / 1000, specifier: "%.2f") km")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Elapsed Time").bold()
                    Spacer()
                    Text("\(runData.durationString)")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Pace").bold()
                    Spacer()
                    Text(runData.paceString)
                }.padding(.horizontal,10)
            }
            
        }
    }
}
