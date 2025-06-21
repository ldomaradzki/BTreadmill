import Foundation
import CoreBluetooth
import Combine
import OSLog

class BluetoothService: NSObject {
    static let treadmillName = "RZ_TreadMill"
    private let bluetoothQueue = DispatchQueue(label: "com.btreadmill.bluetooth", qos: .userInitiated)
    private let accessQueue = DispatchQueue(label: "com.btreadmill.bluetooth.access", attributes: .concurrent)
    
    // Thread-safe properties
    private var _peripheral: CBPeripheral? = nil
    private var peripheral: CBPeripheral? {
        get {
            accessQueue.sync { _peripheral }
        }
        set {
            accessQueue.async(flags: .barrier) { self._peripheral = newValue }
        }
    }
    
    private var _writeCharacteristic: CBCharacteristic? = nil
    private var writeCharacteristic: CBCharacteristic? {
        get {
            accessQueue.sync { _writeCharacteristic }
        }
        set {
            accessQueue.async(flags: .barrier) { self._writeCharacteristic = newValue }
        }
    }
    
    private var manager: CBCentralManager? = nil
    private let logger = Logger(subsystem: "BTreadmill", category: "bluetooth")
    
    private let dataSubject = CurrentValueSubject<[Int], Never>([])
    private let isConnectedSubject = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Public
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> { isConnectedSubject.eraseToAnyPublisher() }
    var dataPublisher: AnyPublisher<[Int], Never> { dataSubject.eraseToAnyPublisher() }
    
    override init() {
        super.init()
        
        manager = CBCentralManager(delegate: self, queue: bluetoothQueue)
    }
    
    func sendCommand(data: Data, completion: ((Result<Void, Error>) -> Void)? = nil) {
        accessQueue.sync {
            guard isConnectedSubject.value, let writeCharacteristic = self.writeCharacteristic, let peripheral = self.peripheral else {
                completion?(.failure(NSError(domain: "com.btreadmill.bluetooth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not connected or missing characteristic"])))
                return
            }
            
            bluetoothQueue.async {
                peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
                completion?(.success(()))
            }
        }
    }
    
    deinit {
        // Clean up any ongoing Bluetooth operations
        if let peripheral = peripheral {
            if let characteristics = peripheral.services?.flatMap({ $0.characteristics ?? [] }) {
                for characteristic in characteristics {
                    if characteristic.isNotifying {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                }
            }
        }
        
        // Stop scanning
        manager?.stopScan()
    }
}

extension BluetoothService: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        connect(central)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnectedSubject.send(false)
        }
        self.peripheral = nil
        connect(central)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnectedSubject.send(false)
        }
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
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == BluetoothService.treadmillName {
            self.peripheral = peripheral
            central.stopScan() // Stop scanning once we find our device
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        DispatchQueue.main.async {
            self.isConnectedSubject.send(true)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties != .write {
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                writeCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error updating value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
        
        let points: [Int] = data.map { Int($0) }

        DispatchQueue.main.async {
            self.dataSubject.send(points)
            
            if self.isConnectedSubject.value == false {
                self.isConnectedSubject.send(true)
            }
        }
    }
}