//
//  RunningControlView.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation
import SwiftUI

enum PreselectedSpeeds: Int, CaseIterable, Identifiable {
    var id: Self { self }
    
    case selectMe = 0
    case oneZero = 10
    case twoZero = 20
    case twoFive = 25
    case threeZero = 30
    case threeFive = 35
    case fourZero = 40
    case fiveZero = 50
    case sixZero = 60
}

struct RunningControlView: View {
    @StateObject
    var viewModel: ContentViewModel
    
    @State private var pickerSelection: PreselectedSpeeds = .selectMe
    
    var body: some View {
        HStack {
            VStack {
                Button("STOP") {
                    viewModel.sendCommand(.stop)
                }.niceButton(foregroundColor: .white, backgroundColor: .red, pressedColor: .accentColor)
                Button("PAUSE") {
                    Task {
                        await viewModel.pauseRun()
                        viewModel.sendCommand(.stop)
                    }
                }.niceButton(foregroundColor: .white, backgroundColor: .blue, pressedColor: .accentColor)
            }
            
            VStack(spacing: 5) {
                Button(action: {
                    guard let currentSpeed = viewModel.runningSpeed?.value else { return }
                    viewModel.sendCommand(.speed(currentSpeed + 0.1))
                }) {
                    Text("+0.1 km/h")
                }
                Picker("", selection: $pickerSelection) {
                    Text("- select speed -").tag(PreselectedSpeeds.selectMe)
                    Text("1.0 km/h").tag(PreselectedSpeeds.oneZero)
                    Text("2.0 km/h").tag(PreselectedSpeeds.twoZero)
                    Text("2.5 km/h").tag(PreselectedSpeeds.twoFive)
                    Text("3.0 km/h").tag(PreselectedSpeeds.threeZero)
                    Text("3.5 km/h").tag(PreselectedSpeeds.threeFive)
                    Text("4.0 km/h").tag(PreselectedSpeeds.fourZero)
                    Text("5.0 km/h").tag(PreselectedSpeeds.fiveZero)
                    Text("6.0 km/h").tag(PreselectedSpeeds.sixZero)
                }.onChange(of: pickerSelection) { newValue in
                    if pickerSelection == .selectMe { return }
                    let speed = Double(pickerSelection.rawValue) / 10
                    viewModel.sendCommand(.speed(speed))
                    pickerSelection = .selectMe
                }
                Button(action: {
                    guard let currentSpeed = viewModel.runningSpeed?.value else { return }
                    viewModel.sendCommand(.speed(currentSpeed - 0.1))
                }) {
                    Text("-0.1 km/h")
                }
            }.padding(.horizontal, 10)
            Spacer()
            VStack {
                Text(viewModel.runningSpeed?.debugDescription ?? "- km/h")
                Text(viewModel.distance?.debugDescription ?? "- km")
            }
        }.padding(.horizontal, 20)
    }
}

struct RunningControlView_Previews: PreviewProvider {
    static var previews: some View {
        let contentViewModel = ContentViewModel(appDatabase: .shared)
        return RunningControlView(viewModel: contentViewModel).frame(width: 300, height: 80)
    }
}


struct NiceButtonStyle: ButtonStyle {
  var foregroundColor: Color
  var backgroundColor: Color
  var pressedColor: Color

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .foregroundColor(foregroundColor)
      .background(configuration.isPressed ? pressedColor : backgroundColor)
      .cornerRadius(5)
  }
}


extension View {
  func niceButton(foregroundColor: Color = .white, backgroundColor: Color = .gray, pressedColor: Color = .accentColor) -> some View {
    self.buttonStyle(NiceButtonStyle(foregroundColor: foregroundColor, backgroundColor: backgroundColor, pressedColor: pressedColor))
  }
}
