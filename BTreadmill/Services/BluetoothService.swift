//
//  BluetoothService.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 01/07/2023.
//

import Foundation
import CoreBluetooth
import Combine
import OSLog

class BluetoothService: NSObject {
    static let treadmillName = "RZ_TreadMill"
    private var peripheral: CBPeripheral? = nil
    private var writeCharacteristic: CBCharacteristic? = nil
    private var manager: CBCentralManager? = nil
    private let logger = Logger(subsystem: "Bluetooth", category: "connection")
    
    private let dataSubject = CurrentValueSubject<[Int], Never>([])
    private let isConnectedSubject = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Public
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> { isConnectedSubject.eraseToAnyPublisher() }
    var dataPublisher: AnyPublisher<[Int], Never> { dataSubject.eraseToAnyPublisher() }
    
    override init() {
        super.init()
        
        manager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func sendCommand(data: Data) {
        guard isConnectedSubject.value, let writeCharacteristic, let peripheral else { return }
        
        peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
    }
}

extension BluetoothService: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        connect(central)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnectedSubject.send(false)
        self.peripheral = nil
        connect(central)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnectedSubject.send(false)
        logger.error("\(error?.localizedDescription ?? "\(#function)")")
    }
    
    func connect(_ central: CBCentralManager) {
        guard central.state == CBManagerState.poweredOn else { return }
        let found = central.retrieveConnectedPeripherals(withServices: [])
            .first { $0.name == BluetoothService.treadmillName }
        
        if let found = found {
            self.peripheral = found
            central.connect(found, options: nil)
        } else {
            // TODO: Maybe it's better to provide `service` instead of scanning everything around
            central.scanForPeripherals(withServices: nil, options: nil)
            logger.warning("Did not find peripheral: \(BluetoothService.treadmillName)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == BluetoothService.treadmillName {
            self.peripheral = peripheral
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        isConnectedSubject.send(true)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties != .write {
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                writeCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            return
        }
        
        let points: [Int] = data.map { Int($0) }

        dataSubject.send(points)
        
        if isConnectedSubject.value == false {
            isConnectedSubject.send(true)
        }
    }
}
