//
//  ATBLEDeviceManager.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol ATBLEConnection {
    func bleConnectionDidConnect()
    func bleConnectionDidDisconnect()
    func bleConnectionDidFailToConnect()
}

public class ATBLEDeviceManager : ATDeviceManager, CBCentralManagerDelegate {
    
    private let serviceUUID = CBUUID(string: "4154") // "AT"
    private let dispatchQueue: DispatchQueue
    private var centralManager: CBCentralManager
    private var foundDevices: [ATBLEDevice]?
    
    public override var state: ATDeviceManagerState { get { return (centralManager.state == .poweredOn) ? .btOn : .btOff } }
    public static var shared: ATBLEDeviceManager {
        get { return self.instance }
    }
    
    private static let instance: ATBLEDeviceManager = ATBLEDeviceManager()
    
    private override init() {
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.ATBLEDeviceManager")
        self.centralManager = CBCentralManager(delegate: nil, queue: dispatchQueue)
        super.init()
        self.centralManager.delegate = self
    }
    
    deinit {
        // TODO
    }
    
#if os(OSX)
    public override func scan() {
        var isScanning = false
        if #available(OSX 10.13, *) {
            isScanning = self.centralManager.isScanning
        }
        if !isScanning {
            ATLog.debug("scan()")
            self.foundDevices = nil
            self.centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    public override func stopScan() {
        var isScanning = true
        if #available(OSX 10.13, *) {
            isScanning = self.centralManager.isScanning
        }
        if isScanning {
            self.centralManager.stopScan()
        }
    }
#else
    public override func scan() {
        if !self.centralManager.isScanning {
            self.foundDevices = nil
            self.centralManager.scanForPeripherals(withServices: [self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    public override func stopScan() {
        if self.centralManager.isScanning {
            self.centralManager.stopScan()
        }
    }
#endif
    
    public override func connect(_ device: ATDevice) {
        let bleDevice = device as! ATBLEDevice
        self.centralManager.connect(bleDevice.peripheral, options: nil)
        DispatchQueue.main.async {
            // Timeout after 5 seconds
            Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (timer) in
                if !bleDevice.connected {
                    self.centralManager.cancelPeripheralConnection(bleDevice.peripheral)
                }
            }
        }
    }
    
    public override func disconnect(_ device: ATDevice) {
        let bleDevice = device as! ATBLEDevice
        self.centralManager.cancelPeripheralConnection(bleDevice.peripheral)
    }
    
    private func findDeviceByPeripheral(_ peripheral: CBPeripheral) -> ATBLEDevice? {
        var bleDevice: ATBLEDevice?
        for device in (self.foundDevices ?? []) {
            if device.peripheral.isEqual(peripheral) { // TODO: need to compare CBUUID?
                bleDevice = device
                break
            }
        }
        return bleDevice
    }
    
    // MARK: - CBCentralManagerDelegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            DispatchQueue.main.async {
                self.delegate?.deviceManager(self, didUpdateState: .btOn)
            }
        }
        else if central.state == .poweredOff {
            DispatchQueue.main.async {
                self.delegate?.deviceManager(self, didUpdateState: .btOff)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        ATLog.debug("Found BLE device: \(peripheral.name ?? "unknown"), \(RSSI)")
        var isATWallet = false
        var pairingMode = false
        for uuid in advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [] {
            if uuid.uuidString.starts(with: "41545741") { // "ATWA"
                isATWallet = true
            }
        }
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? NSDictionary, let data = serviceData[self.serviceUUID] as? NSData {
            let productId: UInt8 = 0x05 // AT.Wallet
            if let byte = data.first, (byte & UInt8(0x80)) > 0 {
                pairingMode = true
            }
            if data.count >= 2, [UInt8](data as Data)[1] == productId {
                isATWallet = true
            }
        }
        if isATWallet && peripheral.name != nil {
            var bleDevice = findDeviceByPeripheral(peripheral)
            if bleDevice == nil {
                bleDevice = ATBLEDevice(Peripheral: peripheral, RSSI: RSSI.intValue, DeviceManager: self)
                foundDevices?.append(bleDevice!) ?? (foundDevices = [bleDevice!])
            }
            DispatchQueue.main.async {
                bleDevice?.attributes[ATDevice.ATTR_RSSI] = RSSI.intValue
                bleDevice?.attributes[ATDevice.ATTR_PAIRING_MODE] = pairingMode
                self.delegate?.deviceManager(self, didDiscover: bleDevice!)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let bleDevice = findDeviceByPeripheral(peripheral) {
            bleDevice.bleConnectionDidConnect()
        }
        else {
            ATLog.debug("Peripheral not found, name: \(peripheral.name ?? "unknown")")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let bleDevice = findDeviceByPeripheral(peripheral) {
            bleDevice.bleConnectionDidDisconnect()
        }
        else {
            ATLog.debug("Peripheral not found, name: \(peripheral.name ?? "unknown")")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let bleDevice = findDeviceByPeripheral(peripheral) {
            ATLog.error(error.debugDescription)
            bleDevice.bleConnectionDidFailToConnect()
        }
        else {
            ATLog.debug("Peripheral not found, name: \(peripheral.name ?? "unknown")")
        }
    }
    
}
