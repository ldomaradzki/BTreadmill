//
//  RunCellView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation
import SwiftUI

struct RunCellView: View {
    var runData: RunData
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(runData.startTimestamp, formatter: DateFormatter.shortFormatter).bold()
                Text(runData.endTimestamp ?? .now, formatter: DateFormatter.shortFormatter).fontWeight(.thin).font(.callout)
            }
            Spacer()
            Text("\(runData.distance.converted(to: .kilometers).value, specifier: "%.2f")").bold()
            Text("km").fontWeight(.thin)
            Spacer()
            Text("\(runData.hours)").bold()
            Text("h").fontWeight(.thin)
            Text("\(runData.minutesReminder)").bold()
            Text("min").fontWeight(.thin)
            if !runData.completed {
                Spacer()
                Text("🟢")
            }
        }.padding(10)
    }
}
