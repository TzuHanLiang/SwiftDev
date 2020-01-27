//
//  ATUSBDeviceManager.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

#if os(OSX)
import Foundation
import Cocoa
import IOKit.hid

public class ATUSBDeviceManager : ATDeviceManager {
    
    public static var shared: ATUSBDeviceManager {
        get { return self.instance }
    }
    
    private static let instance: ATUSBDeviceManager = ATUSBDeviceManager()
    private let vendorId = 0x31BB
    private let productId = 0x0621
    private let usagePageId = 0x4154
    private let hidManager: IOHIDManager
    private var hidRunLoop: CFRunLoop?
    private var isScanning: Bool
    private var usbDevices: [ATUSBDevice]
    
    private override init() {
        self.hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidRunLoop = nil
        self.isScanning = false
        self.usbDevices = []
        super.init()
        
        let deviceAttributes: [String: Any] = [kIOHIDVendorIDKey: self.vendorId, kIOHIDProductIDKey: self.productId, kIOHIDDeviceUsagePageKey: self.usagePageId]
        IOHIDManagerSetDeviceMatching(self.hidManager, deviceAttributes as CFDictionary)
        
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            ATLog.debug("Found USB device: \(IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "unknown")")
            let usbDeviceManager: ATUSBDeviceManager = unsafeBitCast(context, to: ATUSBDeviceManager.self)
            let usbDevice = ATUSBDevice(HIDDevice: device, DeviceManager: usbDeviceManager)
            if !usbDeviceManager.usbDevices.contains(usbDevice) {
                usbDeviceManager.usbDevices.append(usbDevice)
                if usbDeviceManager.isScanning {
                    DispatchQueue.main.async {
                        usbDeviceManager.delegate?.deviceManager(usbDeviceManager, didDiscover: usbDevice)
                    }
                }
            }
        }
        
        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            ATLog.debug("Removed USB device: \(IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "unknown")")
            let usbDeviceManager: ATUSBDeviceManager = unsafeBitCast(context, to: ATUSBDeviceManager.self)
            let usbDevice = ATUSBDevice(HIDDevice: device, DeviceManager: usbDeviceManager)
            if let index = usbDeviceManager.usbDevices.firstIndex(of: usbDevice) {
                let usbDevice = usbDeviceManager.usbDevices[index]
                usbDevice.disconnect()
                usbDeviceManager.usbDevices.remove(at: index)
                if usbDeviceManager.isScanning {
                    DispatchQueue.main.async {
                        usbDeviceManager.delegate?.deviceManager(usbDeviceManager, didLose: usbDevice)
                    }
                }
            }
        }
        
        IOHIDManagerRegisterDeviceMatchingCallback(self.hidManager, matchingCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        IOHIDManagerRegisterDeviceRemovalCallback(self.hidManager, removalCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        Thread.detachNewThread {
            IOHIDManagerScheduleWithRunLoop(self.hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerOpen(self.hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.hidRunLoop = CFRunLoopGetCurrent()
            CFRunLoopRun()
        }
    }
    
    deinit {
        IOHIDManagerUnscheduleFromRunLoop(self.hidManager, self.hidRunLoop!, CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerRegisterDeviceMatchingCallback(self.hidManager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(self.hidManager, nil, nil)
        IOHIDManagerClose(self.hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        CFRunLoopStop(self.hidRunLoop)
    }
    
    public override func scan() {
        self.isScanning = true
        for device in self.usbDevices {
            DispatchQueue.main.async {
                self.delegate?.deviceManager(self, didDiscover: device)
            }
        }
    }
    
    public override func stopScan() {
        self.isScanning = false
    }
    
    public override func connect(_ device: ATDevice) {
        device.connect()
    }
    
    public override func disconnect(_ device: ATDevice) {
        device.disconnect()
    }
    
}
#endif
