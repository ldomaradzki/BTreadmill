//
//  RunCellView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI

struct RunCellView: View {
    @ObservedObject
    var run: Run
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(run.startTimestamp ?? .now, formatter: DateFormatter.shortFormatter).bold()
                Text(run.endTimestamp ?? .now, formatter: DateFormatter.shortFormatter).fontWeight(.thin).font(.callout)
            }
            Spacer()
            Text("\(run.distanceMeters / 1000, specifier: "%.2f")").bold()
            Text("km").fontWeight(.thin)
            Spacer()
            Text("\(run.hours)").bold()
            Text("h").fontWeight(.thin)
            Text("\(run.minutesReminder)").bold()
            Text("min").fontWeight(.thin)
            if !run.completed {
                Spacer()
                Text("🟢")
            }
        }.padding(10)
    }
}

struct RunCellView_Previews: PreviewProvider {
    static var previews: some View {
        let testRun = Run(context: PersistenceController.preview.container.viewContext)
        testRun.startTimestamp = Date()
        testRun.endTimestamp = Date().addingTimeInterval(95*60)
        testRun.distanceMeters = 4500
        
        return RunCellView(run: testRun).frame(width: 200, height: 44, alignment: .leading)
    }
}
