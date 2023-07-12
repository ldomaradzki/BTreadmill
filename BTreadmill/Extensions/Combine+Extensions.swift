//
//  Combine+Extensions.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 12/07/2023.
//

import Foundation
import Combine

extension Publisher where Self.Failure == Never {
  func sink(receiveValue: @escaping ((Self.Output) async -> Void)) -> AnyCancellable {
    sink { value in
      Task { @MainActor in
        await receiveValue(value)
      }
    }
  }
}
