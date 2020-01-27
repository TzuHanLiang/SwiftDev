//
//  ATDevice.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public enum ATDeviceType {
    case ble, usb
}

public protocol ATDeviceDelegate {
    func deviceDidConnect(_ device: ATDevice)
    func deviceDidDisconnect(_ device: ATDevice)
    func deviceDidFailToConnect(_ device: ATDevice)
}

public class ATDevice : NSObject {
    public static let ATTR_RSSI = "rssi"
    public static let ATTR_PAIRING_MODE = "pairing_mode"
    
    public let deviceType: ATDeviceType
    public var delegate: ATDeviceDelegate?
    
    internal(set) public var connected: Bool = false
    internal(set) public var attributes: [String: Any]
    
    var deviceManager: ATDeviceManager
    
    public var name: String { get { return NSLocalizedString("unknown", comment: "") } }
    
    public typealias ResponseCallback = (_ response: Data?, _ error: ATError?) -> ()
    
    init(Type deviceType: ATDeviceType, Manager deviceManager: ATDeviceManager) {
        self.deviceType = deviceType
        self.deviceManager = deviceManager
        self.attributes = [:]
    }
    
    public func connect() {
        self.deviceManager.connect(self)
    }
    
    public func disconnect() {
        self.deviceManager.disconnect(self)
    }
    
    public func send(_ data: Data, Callback callback: @escaping ResponseCallback) {}
    
}
