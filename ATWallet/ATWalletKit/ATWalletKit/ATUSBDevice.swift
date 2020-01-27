//
//  ATUSBDevice.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

#if os(OSX)
import Foundation
import IOKit.hid

class ATUSBDevice : ATDevice {
    
    enum CommandType : UInt8 {
        case hidPing = 0x81
        case hidMsg = 0x83
        case hidInit = 0x86
        case hidContinuationFirst = 0x00
        case hidContinuationLast = 0x7F
        case hidError = 0xBF
    }
    
    class DataPackage {
        var cid: UInt32
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
        
        init(_ cid: UInt32, _ cmd: UInt8, _ data: Data, _ packetSize: Int, _ callback: @escaping ResponseCallback) {
            self.cid = cid
            self.inputData = Data()
            self.callback = callback
            self.outputPackets = packetize(cid, cmd, data, packetSize)
        }
        
        func packetize(_ cid: UInt32, _ cmd: UInt8, _ data: Data, _ packetSize: Int) -> [Data] {
            let cidArray: [UInt8] = [UInt8((cid >> 24) & 0xFF), UInt8((cid >> 16) & 0xFF), UInt8((cid >> 8) & 0xFF), UInt8(cid & 0xFF)]
            var packets: [Data] = []
            var packet = Data()
            packet.append(contentsOf: cidArray)
            packet.append(cmd)
            packet.append(UInt8((data.count >> 8) & 0xFF))
            packet.append(UInt8(data.count & 0xFF))
            if data.count <= (packetSize - 4 - 3) {
                packet.append(data)
                packets.append(packet)
                return packets
            }
            
            let subData = data.subdata(in: 0..<(packetSize - 4 - 3))
            packet.append(subData)
            packets.append(packet)
            
            let leftDataLength = data.count - (packetSize - 4 - 3)
            let numberOfLeftPackets = (leftDataLength + (packetSize - 4 - 1 - 1)) / (packetSize - 4 - 1)
            for index in 0..<numberOfLeftPackets {
                var packet = Data()
                packet.append(contentsOf: cidArray)
                packet.append(UInt8(index))
                let start = (packetSize - 4 - 3) + index * (packetSize - 4 - 1)
                var end = start + (packetSize - 4 - 1)
                if end > data.count {
                    end = data.count
                }
                let subData = data.subdata(in: start..<end)
                packet.append(subData)
                if packet.count < packetSize {
                    let padding = [UInt8](repeating: 0, count: packetSize - packet.count)
                    packet.append(contentsOf: padding)
                }
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
            let cid: UInt32 = ((UInt32(packet[0]) << 24) & 0xFF000000) | ((UInt32(packet[1]) << 16) & 0x00FF0000) | ((UInt32(packet[2]) << 8) & 0x0000FF00) | (UInt32(packet[3]) & 0x000000FF)
            guard cid == self.cid else { return false }
            
            let data = packet.bytes
            if self.inputData.isEmpty {
                guard self.outputPackets[0].bytes[4] == data[4] else { return false }
                self.inputDataLength = ((Int(data[5]) << 8 ) & 0xFF00) | (Int(data[6]) & 0x00FF)
                let payloadLength = (self.inputDataLength <= (data.count - 7)) ? self.inputDataLength : (data.count - 7)
                self.inputData.append(contentsOf: data[7..<(7 + payloadLength)])
                return true
            }
            
            guard data[4] == self.nextInputPacketIndex else { return false }
            self.nextInputPacketIndex += 1
            let leftDataLength = self.inputDataLength - self.inputData.count
            let payloadLength = (leftDataLength <= (data.count - 5)) ? leftDataLength : (data.count - 5)
            self.inputData.append(contentsOf: data[5..<(5 + payloadLength)])
            return true
        }
    }
    
    // MARK: -
    
    private let hidDevice: IOHIDDevice
    private let product: String
    private let serialNumber: String
    private let inputReportSize: Int
    private let inputReport: UnsafeMutablePointer<UInt8>
    private let outputReportSize: Int
    private var cid: UInt32
    private var dataQueue: [DataPackage] = []
    
    public override var name: String { get { return self.product } }
    
    private let inputReportCallback: IOHIDReportCallback = { context, result, sender, type, reportId, report, reportLength in
        let usbDevice: ATUSBDevice = unsafeBitCast(context, to: ATUSBDevice.self)
        if let package = usbDevice.dataQueue.first, !package.hasPendingOutputData, reportLength > 0 {
            let data = Data(bytes: UnsafePointer<UInt8>(report), count: reportLength)
            ATLog.debug("Received USB packet:\n\(data as NSData)")
            let cid: UInt32 = ((UInt32(data[0]) << 24) & 0xFF000000) | ((UInt32(data[1]) << 16) & 0x00FF0000) | ((UInt32(data[2]) << 8) & 0x0000FF00) | (UInt32(data[3]) & 0x000000FF)
            if cid == usbDevice.cid && !package.enqueueInputPacket(data) && data[4] == CommandType.hidError.rawValue {
                ATLog.error("Got error from USB device: \(data as NSData)")
                usbDevice.dataQueue.remove(at: 0)
                DispatchQueue.main.async {
                    usbDevice.sendDataPackage()
                    package.callback(nil, .commandError)
                }
                return
            }
            if package.isInputDataAvailable {
                DispatchQueue.main.async {
                    usbDevice.handleResponse()
                }
            }
        }
    }
    
    init(HIDDevice device: IOHIDDevice, DeviceManager deviceManager: ATUSBDeviceManager) {
        self.hidDevice = device
        self.cid = 0xFFFFFFFF
        self.product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        self.serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String ?? ""
        self.inputReportSize = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int ?? 64
        self.inputReport = UnsafeMutablePointer<UInt8>.allocate(capacity: self.inputReportSize)
        self.outputReportSize = IOHIDDeviceGetProperty(device, kIOHIDMaxOutputReportSizeKey as CFString) as? Int ?? 64
        super.init(Type: ATDeviceType.usb, Manager: deviceManager)
    }
    
    deinit {
        self.inputReport.deallocate()
    }
    
    private func sendDataPackage() {
        if self.dataQueue.isEmpty { return }
        
        while let packet = self.dataQueue.first!.getNextOutputPacket() {
            let packetPointer = (packet as NSData).bytes.bindMemory(to: UInt8.self, capacity: packet.count)
            if IOHIDDeviceSetReport(self.hidDevice, kIOHIDReportTypeOutput, CFIndex(0), packetPointer, packet.count) != kIOReturnSuccess {
                ATLog.error("Failed to set HID Report")
                for package in self.dataQueue {
                    DispatchQueue.main.async {
                        package.callback(nil, .failToSend)
                    }
                    self.dataQueue.remove(at: 0)
                }
                break
            }
        }
    }
    
    private func handleResponse() {
        if self.dataQueue.isEmpty { return }
        if let package = self.dataQueue.first, package.isInputDataAvailable {
            self.dataQueue.remove(at: 0)
            DispatchQueue.main.async {
                self.sendDataPackage()
                package.callback(package.inputData, nil)
            }
        }
    }
    
    // MARK: -
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let device = object as? ATUSBDevice else { return false }
        return device.hidDevice == self.hidDevice
    }
    
    public override func connect() {
        IOHIDDeviceRegisterInputReportCallback(self.hidDevice, self.inputReport, self.inputReportSize, self.inputReportCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        let cid: UInt32 = 0xFFFFFFFF // Broadcast CID
        var nonce = [UInt8](repeating: 0, count: 8)
        if SecRandomCopyBytes(kSecRandomDefault, nonce.count * MemoryLayout<UInt8>.size, &nonce) !=  errSecSuccess {
            for index in 0..<nonce.count where (index % 4) == 0 {
                let randomValue = arc4random()
                nonce[index] = UInt8((randomValue >> 24) & 0xFF)
                nonce[index + 1] = UInt8((randomValue >> 16) & 0xFF)
                nonce[index + 2] = UInt8((randomValue >> 8) & 0xFF)
                nonce[index + 3] = UInt8(randomValue & 0xFF)
            }
        }
        self.dataQueue.append(DataPackage(cid, CommandType.hidInit.rawValue, Data(nonce), self.outputReportSize) { response, error in
            guard error == nil else {
                ATLog.error(error!.description)
                DispatchQueue.main.async {
                    self.delegate?.deviceDidFailToConnect(self)
                }
                return
            }
            guard let response = response, response.count == 17 else {
                ATLog.error("Incorrect response length")
                DispatchQueue.main.async {
                    self.delegate?.deviceDidFailToConnect(self)
                }
                return
            }
            
            let cidArray = [UInt8](response.bytes[8..<(8+4)])
            self.cid = ((UInt32(cidArray[0]) << 24) & 0xFF000000) | ((UInt32(cidArray[1]) << 16) & 0x00FF0000) | ((UInt32(cidArray[2]) << 8) & 0x0000FF00) | (UInt32(cidArray[3]) & 0x000000FF)
            ATLog.debug("CID: \(Data(cidArray) as NSData)")
            self.connected = true
            DispatchQueue.main.async {
                self.delegate?.deviceDidConnect(self)
            }
        })
        if self.dataQueue.count == 1 {
            DispatchQueue.main.async {
                self.sendDataPackage()
            }
        }
    }
    
    public override func disconnect() {
        IOHIDDeviceRegisterInputReportCallback(self.hidDevice, self.inputReport, self.inputReportSize, nil, nil)
        for package in self.dataQueue {
            DispatchQueue.main.async {
                package.callback(nil, package.hasPendingOutputData ? .failToSend : .failToReceive)
            }
            self.dataQueue.remove(at: 0)
        }
        self.cid = 0xFFFFFFFF
        self.connected = false
        DispatchQueue.main.async {
            self.delegate?.deviceDidDisconnect(self)
        }
    }
    
    public override func send(_ data: Data, Callback callback: @escaping ResponseCallback) {
        guard self.connected else {
            DispatchQueue.main.async {
                callback(nil, .failToSend)
            }
            return
        }
        
        let maxDataLength = (self.outputReportSize - 4 - 3) + (0x80 * self.outputReportSize - 0x80)
        if data.count > maxDataLength {
            DispatchQueue.main.async {
                callback(nil, .overlength)
            }
            return
        }
        
        ATLog.debug("Send USB Data:\n\(data as NSData)")
        
        self.dataQueue.append(DataPackage(self.cid, CommandType.hidMsg.rawValue, data, self.outputReportSize, callback))
        if self.dataQueue.count == 1 {
            DispatchQueue.main.async {
                self.sendDataPackage()
            }
        }
    }
    
}
#endif
