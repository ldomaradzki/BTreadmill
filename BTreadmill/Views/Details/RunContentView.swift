//
//  RunContentView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI
import Charts

struct RunContentView: View {
    @ObservedObject
    var run: Run
    var speedsArray: [(Int, Double)] { run.speedsArray.enumerated().map { ($0.offset, $0.element) } }

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
                    Text("\(run.speedsArray.reduce(0.0, +)/Double(run.speedsArray.count), specifier: "%.1f") km/h")
                }.padding(.horizontal, 10)
                Divider()
                HStack {
                    Text("Max Speed").bold()
                    Spacer()
                    Text("\(run.speedsArray.max() ?? 0.0, specifier: "%.1f") km/h")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Distance").bold()
                    Spacer()
                    Text("\(run.distanceMeters / 1000, specifier: "%.2f") km")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Elapsed Time").bold()
                    Spacer()
                    Text("\(run.durationString)")
                }.padding(.horizontal,10)
                Divider()
                HStack {
                    Text("Pace").bold()
                    Spacer()
                    Text(run.paceString)
                }.padding(.horizontal,10)
            }
            
        }
    }
}

struct RunContentView_Previews: PreviewProvider {
    static var previews: some View {
        let testRun = Run(context: PersistenceController.preview.container.viewContext)
        testRun.startTimestamp = Date()
        testRun.endTimestamp = Date().addingTimeInterval(95*60)
        testRun.distanceMeters = 4500
        testRun.speeds = [1.0, 1.1, 1.3, 1.5, 2.0, 2.0, 2.0, 2.0, 2.3, 2.4, 2.5, 2.5, 2.5, 2.5, 2.0, 1.5, 1.0, 0.5, 0.0] as NSObject

        return RunContentView(run: testRun).frame(width: 400, height: 500, alignment: .leading)
    }
}
