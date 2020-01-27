//
//  ATDeviceManager.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/10/25.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public enum ATDeviceManagerState {
    case unknown, btOn, btOff
}

public protocol ATDeviceManagerDelegate {
    func deviceManager(_ deviceManager: ATDeviceManager, didUpdateState state: ATDeviceManagerState)
    func deviceManager(_ deviceManager: ATDeviceManager, didDiscover device: ATDevice)
    func deviceManager(_ deviceManager: ATDeviceManager, didLose device: ATDevice)
}

public class ATDeviceManager : NSObject {
    
    public var delegate: ATDeviceManagerDelegate?
    
    public var state: ATDeviceManagerState { get { return .unknown } }
        
    public func scan() {}
    public func stopScan() {}
    
    public func connect(_ device: ATDevice) {}
    public func disconnect(_ device: ATDevice) {}
    
}
