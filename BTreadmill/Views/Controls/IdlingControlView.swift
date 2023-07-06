//
//  IdlingControlView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation
import SwiftUI

struct IdlingControlView: View {
    let viewModel: ContentViewModel
    
    var body: some View {
        HStack(alignment: .center) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 50, height: 50, alignment: .center)
                Text("Start")
                    .foregroundColor(.black)
                    .fontWeight(.heavy)
            }
            .onTapGesture {
                viewModel.sendCommand(.start)
            }
        }.padding(.horizontal, 20)
        
    }
}
