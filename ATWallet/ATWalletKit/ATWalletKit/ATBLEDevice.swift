//
//  ATBLEDevice.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation
import CoreBluetooth

class ATBLEDevice : ATDevice, CBPeripheralDelegate, ATBLEConnection {

    enum CommandType : UInt8 {
        case blePing = 0x81
        case bleKeepalive = 0x82
        case bleMsg = 0x83
        case bleContinuationFirst = 0x00
        case bleContinuationLast = 0x7F
        case bleError = 0xBF
    }

    class DataPackage {
        var nextOutputPacketIndex = 0
        var outputPackets: [Data] = []
        var nextInputPacketIndex = 0
        var inputData: Data
        var inputDataLength = 0
        let callback: ResponseCallback

        var hasPendingOutputData: Bool {
            get {
                return self.nextOutputPacketIndex < self.outputPackets.count
            }
        }

        var isInputDataAvailable: Bool {
            get {
                guard !self.inputData.isEmpty else { return false }
                return self.inputDataLength == self.inputData.count
            }
        }

        init(_ cmd: UInt8, _ data: Data, _ packetSize: Int, _ callback: @escaping ResponseCallback) {
            self.inputData = Data()
            self.callback = callback
            self.outputPackets = packetize(cmd, data, packetSize)
        }

        func packetize(_ cmd: UInt8, _ data: Data, _ packetSize: Int) -> [Data] {
            var packets: [Data] = []
            var packet = Data()
            packet.append(cmd)
            packet.append(UInt8((data.count >> 8) & 0xFF))
            packet.append(UInt8(data.count & 0xFF))
            if data.count <= (packetSize - 3) {
                packet.append(data)
                packets.append(packet)
                return packets
            }
            
            let subData = data.subdata(in: 0..<(packetSize - 3))
            packet.append(subData)
            packets.append(packet)
            
            let leftDataLength = data.count - (packetSize - 3)
            let numberOfLeftPackets = (leftDataLength + (packetSize - 1 - 1)) / (packetSize - 1)
            for index in 0..<numberOfLeftPackets {
                var packet = Data()
                packet.append(UInt8(index))
                let start = (packetSize - 3) + index * (packetSize - 1)
                var end = start + (packetSize - 1)
                if end > data.count {
                    end = data.count
                }
                let subData = data.subdata(in: start..<end)
                packet.append(subData)
                packets.append(packet)
            }
            
            return packets
        }

        func getNextOutputPacket() -> Data? {
            guard self.nextOutputPacketIndex < self.outputPackets.count else { return nil }
            self.nextOutputPacketIndex += 1
            return self.outputPackets[self.nextOutputPacketIndex - 1]
        }

        func enqueueInputPacket(_ packet: Data) -> Bool {
            let data = packet.bytes
            if self.inputData.isEmpty {
                guard self.outputPackets[0].bytes[0] == data[0] else { return false }
                self.inputDataLength = ((Int(data[1]) << 8 ) & 0xFF00) | (Int(data[2]) & 0x00FF)
                self.inputData.append(contentsOf: data[3..<packet.count])
                return true
            }
            
            guard data[0] == self.nextInputPacketIndex else { return false }
            self.nextInputPacketIndex += 1
            let leftDataLength = self.inputDataLength - self.inputData.count
            self.inputData.append(contentsOf: data[1..<((leftDataLength >= (data.count - 1)) ? data.count : 1 + leftDataLength)])
            return true
        }
    }

    // MARK: -

    public override var name: String { get { return self.peripheral.name ?? super.name } }

    var peripheral: CBPeripheral

    private let serviceUUIDs: [String: CBUUID] = ["fido": CBUUID(string: "FFFD"), "devInfo": CBUUID(string: "180A"), "battery": CBUUID(string: "180F"), "at": CBUUID(string: "4154")]
    private var services: [CBUUID: CBService?] = [CBUUID(string: "FFFD"): nil, CBUUID(string: "180A"): nil, CBUUID(string: "180F"): nil, CBUUID(string: "4154"): nil]
    private let fidoCharacUUIDs: [String: CBUUID] = ["controlPoint": CBUUID(string: "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"),
                                                    "status": CBUUID(string: "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"),
                                                    "controlPointLength": CBUUID(string: "F1D0FFF3-DEAA-ECEE-B42F-C9BA7ED623BB"),
                                                    "revision": CBUUID(string: "2A28"),
                                                    "revisionBitfield": CBUUID(string: "F1D0FFF4-DEAA-ECEE-B42F-C9BA7ED623BB")]
    private let devInfoCharacUUIDs: [String: CBUUID] = ["fwVersion": CBUUID(string: "2A26")]
    private let batteryCharacUUIDs: [String: CBUUID] = ["batteryLevel": CBUUID(string: "2A19")]
    private var fidoCharacteristics: [CBUUID: CBCharacteristic?] = [CBUUID(string: "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"): nil,
                                                                    CBUUID(string: "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"): nil,
                                                                    CBUUID(string: "F1D0FFF3-DEAA-ECEE-B42F-C9BA7ED623BB"): nil,
                                                                    CBUUID(string: "2A28"): nil,
                                                                    CBUUID(string: "F1D0FFF4-DEAA-ECEE-B42F-C9BA7ED623BB"): nil]
    private var devInfoCharacteristics: [CBUUID: CBCharacteristic?] = [CBUUID(string: "2A26"): nil]
    private var batteryCharacteristics: [CBUUID: CBCharacteristic?] = [CBUUID(string: "2A19"): nil]

    private var maxPacketSize: Int?
    private var dataQueue: [DataPackage] = []

    init(Peripheral peripheral: CBPeripheral, RSSI rssi: Int, DeviceManager deviceManager: ATBLEDeviceManager) {
        self.peripheral = peripheral
        super.init(Type: ATDeviceType.ble, Manager: deviceManager)
        self.peripheral.delegate = self;
        self.attributes[ATDevice.ATTR_RSSI] = rssi
    }

    private func reset() {
        self.connected = false
        self.maxPacketSize = nil
        self.services = [CBUUID(string: "FFFD"): nil, CBUUID(string: "180A"): nil, CBUUID(string: "180F"): nil, CBUUID(string: "4154"): nil]
        self.fidoCharacteristics = [CBUUID(string: "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"): nil, CBUUID(string: "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"): nil, CBUUID(string: "F1D0FFF3-DEAA-ECEE-B42F-C9BA7ED623BB"): nil, CBUUID(string: "2A28"): nil, CBUUID(string: "F1D0FFF4-DEAA-ECEE-B42F-C9BA7ED623BB"): nil]
        self.devInfoCharacteristics = [CBUUID(string: "2A26"): nil]
        self.batteryCharacteristics = [CBUUID(string: "2A19"): nil]
    }

    private func sendDataPacket() {
        if self.dataQueue.isEmpty { return }
        if let packet = self.dataQueue.first!.getNextOutputPacket() {
            let charac = self.fidoCharacteristics[self.fidoCharacUUIDs["controlPoint"]!]!!
            self.peripheral.writeValue(packet, for: charac, type: .withResponse)
        }
    }

    private func handleResponse() {
        if self.dataQueue.isEmpty { return }
        if let package = self.dataQueue.first, package.isInputDataAvailable {
            self.dataQueue.remove(at: 0)
            DispatchQueue.main.async {
                self.sendDataPacket()
                package.callback(package.inputData, nil)
            }
        }
    }

    // MARK: -

    public override func isEqual(_ object: Any?) -> Bool {
        guard let device = object as? ATBLEDevice else { return false }
        return device.peripheral == self.peripheral
    }

    override func send(_ data: Data, Callback callback: @escaping ResponseCallback) {
        guard self.connected else {
            DispatchQueue.main.async {
                callback(nil, .failToSend)
            }
            return
        }
        
        let maxDataLength = (self.maxPacketSize! - 3) + (0x80 * self.maxPacketSize! - 0x80)
        if data.count > maxDataLength {
            callback(nil, .overlength)
            return
        }
        
        ATLog.debug("Send BLE Data:\n\(data as NSData)")
        
        self.dataQueue.append(DataPackage(CommandType.bleMsg.rawValue, data, self.maxPacketSize!, callback))
        if self.dataQueue.count == 1 {
            DispatchQueue.main.async {
                self.sendDataPacket()
            }
        }
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            ATLog.error(error.debugDescription)
            self.deviceManager.disconnect(self)
            return
        }
        
        for service in (peripheral.services ?? []) {
            ATLog.debug("Found Service: \(service.uuid.uuidString)")
            if self.services.keys.contains(service.uuid) {
                ATLog.debug("Add Service: \(service.uuid.uuidString)")
                self.services[service.uuid] = service
            }
        }
        guard let atService = self.services[serviceUUIDs["at"]!]!, let devInfoService = self.services[serviceUUIDs["devInfo"]!]!, let batteryService = self.services[serviceUUIDs["battery"]!]! else {
            ATLog.error("Cannot find all needed services")
            self.deviceManager.disconnect(self)
            return
        }
        
        peripheral.discoverCharacteristics(Array(self.fidoCharacUUIDs.values), for: atService)
        peripheral.discoverCharacteristics(Array(self.devInfoCharacUUIDs.values), for: devInfoService)
        peripheral.discoverCharacteristics(Array(self.batteryCharacUUIDs.values), for: batteryService)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            ATLog.error(error.debugDescription)
            self.deviceManager.disconnect(self)
            return
        }
        
        var characteristics: [CBUUID: CBCharacteristic?]?
        if service.uuid.isEqual(self.serviceUUIDs["at"]) {
            characteristics = self.fidoCharacteristics
        }
        else if service.uuid.isEqual(self.serviceUUIDs["devInfo"]) {
            characteristics = self.devInfoCharacteristics
        }
        else if service.uuid.isEqual(self.serviceUUIDs["battery"]) {
            characteristics = self.batteryCharacteristics
        }
        else {
            ATLog.debug("Unknown service")
            return
        }
        
        for charac in (service.characteristics ?? []) {
            ATLog.debug("Found characteristic: UUID: \(charac.uuid.uuidString)")
            if characteristics!.keys.contains(charac.uuid) {
                ATLog.debug("add characteristic")
                characteristics![charac.uuid] = charac
                if charac.uuid.isEqual(self.fidoCharacUUIDs["status"]) {
                    peripheral.setNotifyValue(true, for: charac)
                }
            }
        }
        if characteristics!.values.contains(nil) {
            ATLog.debug("Cannot find all needed characteristics")
            self.deviceManager.disconnect(self)
        }
        if service.uuid.isEqual(self.serviceUUIDs["at"]) {
            self.fidoCharacteristics = characteristics!
        }
        else if service.uuid.isEqual(self.serviceUUIDs["devInfo"]) {
            self.devInfoCharacteristics = characteristics!
        }
        else if service.uuid.isEqual(self.serviceUUIDs["battery"]) {
            self.batteryCharacteristics = characteristics!
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            ATLog.error(error.debugDescription)
            return
        }
        if characteristic.uuid.isEqual(self.fidoCharacUUIDs["status"]) && characteristic.isNotifying {
            guard let charac = self.fidoCharacteristics[self.fidoCharacUUIDs["controlPointLength"]!]! else {
                ATLog.error("Control Point Length Characteristic Not Found")
                return
            }
            peripheral.readValue(for: charac)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            ATLog.error(error.debugDescription)
            if characteristic.uuid.isEqual(self.fidoCharacUUIDs["status"]) {
                if let package = self.dataQueue.first {
                    self.dataQueue.remove(at: 0)
                    DispatchQueue.main.async {
                        self.sendDataPacket()
                        package.callback(nil, .failToSend)
                    }
                }
            }
            return
        }
        
        if characteristic.uuid.isEqual(self.fidoCharacUUIDs["status"]) {
            ATLog.debug("Received BLE Packet:\n\(characteristic.value! as NSData)")
            let data = characteristic.value!
            if data[0] == CommandType.bleKeepalive.rawValue { return }
            guard let package = self.dataQueue.first, !package.hasPendingOutputData, data.count > 0 else { return }
            if !package.enqueueInputPacket(data) && data[0] == CommandType.bleError.rawValue {
                ATLog.error("Got error from BLE device: \(data as NSData)")
                self.dataQueue.remove(at: 0)
                DispatchQueue.main.async {
                    self.sendDataPacket()
                    package.callback(nil, .commandError)
                }
                return
            }
            if package.isInputDataAvailable {
                DispatchQueue.main.async {
                    self.handleResponse()
                }
            }
        }
        else if characteristic.uuid.isEqual(self.fidoCharacUUIDs["controlPointLength"]) {
            let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
            self.maxPacketSize = characteristic.value?.withUnsafeBytes({ (pointer: UnsafeRawBufferPointer) -> Int in
                let maxSize = Int(CFSwapInt16BigToHost(pointer.bindMemory(to: UInt16.self).baseAddress!.pointee))
                return (maxSize > (mtu - 3)) ? (mtu - 3) : maxSize
            })
            /*
            self.maxPacketSize = characteristic.value?.withUnsafeBytes({ (pointer: UnsafePointer<UInt16>) -> Int in
                return Int(CFSwapInt16BigToHost(pointer.pointee))
            })
            */
            guard self.maxPacketSize != nil else {
                ATLog.debug("This should not happen!")
                self.deviceManager.disconnect(self)
                return
            }
            ATLog.debug("Max BLE Packet Size: \(self.maxPacketSize!)")
            // NOTE: some guys said that the MTU of iPhone 6/6S is 185, and it's 158 before iOS 10.
            //self.maxPacketSize = 185 - 3 // this can avoid wriet error
            if !self.connected {
                self.connected = true
                DispatchQueue.main.async {
                    self.delegate?.deviceDidConnect(self)
                }
            }
        }
        else if characteristic.uuid.isEqual(self.devInfoCharacUUIDs["fwVersion"]) {
            // TODO
        }
        else if characteristic.uuid.isEqual(self.batteryCharacUUIDs["batteryLevel"]) {
            // TODO
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            ATLog.error(error.debugDescription)
            // Note: Error(Error Domain=CBATTErrorDomain Code=241 "Unknown ATT error.") occoured when sending bigger transaction data, but actually it works fine.
            // TODO: how to fix this? it seems the packet is too large, but AT.Wallet can receive the packet.
            /*
            if let package = self.dataQueue.first {
                self.dataQueue.remove(at: 0)
                DispatchQueue.main.async {
                    package.callback(nil, .failToSend)
                }
            }
            */
        }
        
        DispatchQueue.main.async {
            self.sendDataPacket()
        }
    }

    // MARK: - ATBLEConnection

    func bleConnectionDidConnect() {
        self.peripheral.discoverServices(Array(self.serviceUUIDs.values))
    }

    func bleConnectionDidDisconnect() {
        if self.connected {
            for package in self.dataQueue {
                DispatchQueue.main.async {
                    package.callback(nil, package.hasPendingOutputData ? .failToSend : .failToReceive)
                }
                self.dataQueue.remove(at: 0)
            }
            reset()
            DispatchQueue.main.async {
                self.delegate?.deviceDidDisconnect(self)
            }
        }
        else {
            reset()
            DispatchQueue.main.async {
                self.delegate?.deviceDidFailToConnect(self)
            }
        }
    }

    func bleConnectionDidFailToConnect() {
        reset()
        DispatchQueue.main.async {
            self.delegate?.deviceDidFailToConnect(self)
        }
    }
}
